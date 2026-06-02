"""SQL Query complexity analyzer for profiling database performance."""

import os
import re
from typing import Any, Optional

# Complexity constants
O_1 = "O(1) [Constant Time]"
O_LOG_N = "O(log N) [Logarithmic Time - Index Scan]"
O_N = "O(N) [Linear Time - Full Table Scan!]"
O_N_LOG_N = "O(N log N) [Linearithmic Time - Sort / Group By]"
O_N_M = "O(N * M) [Nested Loop / Cross Join!]"
O_K = "O(K) [N+1 Query Loop!]"


class QueryAnalyzer:
    """Analyzer for Django ORM SQL queries to detect performance issues.

    Attributes:
        raw_queries: A list of raw queries captured by the middleware or parser.
        analyzed_queries: A list of dictionary summaries of analyzed queries.
        n1_groups: A dictionary mapping ORM callers to N+1 query loop stats.
        summary: A dictionary with aggregated metrics from all checked queries.
    """

    raw_queries: list[dict[str, Any]]
    analyzed_queries: list[dict[str, Any]]
    n1_groups: dict[tuple[str, int], dict[str, Any]]
    summary: dict[str, Any]

    def __init__(self, queries: list[dict[str, Any]]) -> None:
        """Initializes QueryAnalyzer with raw captured SQL queries.

        Args:
            queries: A list of captured raw query dictionary definitions.
        """
        self.raw_queries = queries
        self.analyzed_queries = []
        self.n1_groups = {}
        self.summary = {
            "total_queries": 0,
            "total_time_ms": 0.0,
            "total_rows_fetched": 0,
            "warnings_count": 0,
            "n1_warnings_count": 0,
            "table_scan_warnings_count": 0,
        }

    def analyze(self) -> tuple[list[dict[str, Any]], dict[str, Any]]:
        """Analyzes execution plans and retrieves suggestions.

        Returns:
            A tuple of (analyzed_queries, summary).
        """
        self.summary["total_queries"] = len(self.raw_queries)

        # Step 1: Detect N+1 queries by grouping by ORM caller
        self._detect_n1_queries()

        # Step 2: Analyze each query
        for idx, q in enumerate(self.raw_queries):
            sql = q["sql"]
            params = q["params"]
            duration = q.get("duration", 0.0) * 1000.0  # to ms
            rows_fetched = q.get("rows_fetched", 0)
            caller = q.get("caller")

            self.summary["total_time_ms"] += duration
            self.summary["total_rows_fetched"] += rows_fetched

            # Basic query information
            query_type = self._get_query_type(sql)

            # Database connection & plan
            connection = q.get("connection")
            if connection is None:
                try:
                    from django.db import connections

                    connection = connections["default"]
                except Exception:
                    pass

            plan, engine = self._get_query_plan(connection, sql, params)

            # Analyze plan & complexity
            complexity, plan_warnings, is_table_scan = self._analyze_plan(
                plan, engine, sql
            )

            if is_table_scan:
                self.summary["table_scan_warnings_count"] += 1

            # Synthesize warnings & suggestions
            warnings, suggestions = self._generate_suggestions(
                sql,
                params,
                rows_fetched,
                caller,
                complexity,
                plan_warnings,
                is_table_scan,
                connection,
            )

            # Check if this query is part of an N+1 group
            n1_suggestion = None
            if caller:
                caller_key = (caller["filename"], caller["lineno"])
                if (
                    caller_key in self.n1_groups
                    and self.n1_groups[caller_key]["count"] > 1
                ):
                    n1_suggestion = self.n1_groups[caller_key]["suggestion"]
                    if n1_suggestion and n1_suggestion not in suggestions:
                        suggestions.insert(0, n1_suggestion)
                        warnings.insert(
                            0,
                            "N+1 Query Loop detected! This line executed "
                            f"{self.n1_groups[caller_key]['count']} queries.",
                        )
                        complexity = (
                            f"{O_K} where K="
                            f"{self.n1_groups[caller_key]['count']} "
                            "database roundtrips"
                        )

            self.summary["warnings_count"] += len(warnings)

            # Format code snippet
            code_snippet = None
            if caller:
                code_snippet = self._get_code_snippet(
                    caller["filename"], caller["lineno"]
                )

            self.analyzed_queries.append(
                {
                    "id": idx + 1,
                    "sql": sql,
                    "params": str(params),
                    "duration_ms": round(duration, 2),
                    "rows_fetched": rows_fetched,
                    "caller": caller,
                    "code_snippet": code_snippet,
                    "query_type": query_type,
                    "complexity": complexity,
                    "warnings": warnings,
                    "suggestions": suggestions,
                    "plan": plan,
                    "engine": engine,
                }
            )

        self.summary["n1_warnings_count"] = sum(
            1 for g in self.n1_groups.values() if g["suggestion"] is not None
        )
        return self.analyzed_queries, self.summary

    def _get_query_type(self, sql: str) -> str:
        """Return the DML keyword that opens the SQL statement."""
        first = sql.strip().split(None, 1)[0].upper()
        return (
            first
            if first in {"SELECT", "INSERT", "UPDATE", "DELETE"}
            else "OTHER"
        )

    def _get_query_plan(
        self, connection: Any, sql: str, params: Any
    ) -> tuple[list[list[Any]], str]:
        if not connection or not hasattr(connection, "settings_dict"):
            return [], "unknown"
        db_engine: str = connection.settings_dict["ENGINE"]

        # Only EXPLAIN read queries (SELECT)
        if not sql.strip().upper().startswith("SELECT"):
            return [], db_engine

        if "sqlite" in db_engine:
            explain_sql = f"EXPLAIN QUERY PLAN {sql}"
        else:
            explain_sql = f"EXPLAIN {sql}"

        try:
            with connection.cursor() as cursor:
                cursor.execute(explain_sql, params)
                rows = cursor.fetchall()
                # SQLite returns (selectid, order, from, detail) or
                # (id, parent, notused, detail)
                # PostgreSQL returns a list of tuples containing the text plan
                # MySQL returns structured columns
                return [list(r) for r in rows], db_engine
        except Exception:
            # Safe fallback if EXPLAIN fails
            return [], db_engine

    def _analyze_sqlite_plan(
        self, plan: list[list[Any]], plan_str: str
    ) -> tuple[str, list[str], bool]:
        """Analyse a SQLite EXPLAIN QUERY PLAN result."""
        warnings: list[str] = []
        is_table_scan = False
        has_sort = False
        # SQLite EXPLAIN QUERY PLAN detail strings:
        #   SCAN TABLE <name>           — full table scan  O(N)
        #   SEARCH TABLE <name> USING  — index lookup      O(log N)
        #   USE TEMP B-TREE FOR ORDER BY / DISTINCT        O(N log N)
        for row in plan:
            detail = str(row[-1])
            if "SCAN TABLE" in detail:
                is_table_scan = True
                table_name = re.findall(r"SCAN TABLE (\w+)", detail)
                table_str = f" `{table_name[0]}`" if table_name else ""
                warnings.append(
                    f"Full table scan detected on table{table_str}!"
                )
            elif "USE TEMP B-TREE" in detail:
                has_sort = True
                operation = "ORDER BY" if "ORDER BY" in detail else "DISTINCT"
                warnings.append(
                    f"In-memory sort required for {operation}. "
                    "Consider adding an index on the sorted column(s)."
                )

        if is_table_scan:
            complexity = O_N
        elif has_sort:
            complexity = O_N_LOG_N
        else:
            complexity = O_LOG_N if "search table" in plan_str else O_1
        return complexity, warnings, is_table_scan

    def _analyze_postgresql_plan(
        self, plan: list[list[Any]], plan_str: str
    ) -> tuple[str, list[str], bool]:
        """Analyse a PostgreSQL EXPLAIN result."""
        warnings: list[str] = []
        is_table_scan = False
        has_sort = False
        # PostgreSQL EXPLAIN node types:
        #   Seq Scan          — full table scan    O(N)
        #   Index Scan        — index lookup       O(log N)
        #   Bitmap Heap Scan  — bitmap index       O(log N)
        #   Sort              — in-memory sort     O(N log N)
        #   Sort + disk       — disk sort          O(N log N) + I/O warning
        for row in plan:
            line = str(row[0])
            if "Seq Scan" in line:
                is_table_scan = True
                table_name = re.findall(r"Seq Scan on (\w+)", line)
                table_str = f" `{table_name[0]}`" if table_name else ""
                warnings.append(
                    "Sequential (full table) scan detected on "
                    f"table{table_str}!"
                )
            elif "Sort" in line:
                has_sort = True
                if "disk" in line:
                    warnings.append(
                        "Sort operation spilling to disk! "
                        "Increase work_mem or add an index on the "
                        "sorted column(s)."
                    )
                else:
                    warnings.append(
                        "In-memory sort detected. Consider adding an "
                        "index on the ORDER BY / GROUP BY column(s) "
                        "to avoid the sort step."
                    )

        if is_table_scan:
            complexity = O_N
        elif has_sort:
            complexity = O_N_LOG_N
        else:
            complexity = (
                O_LOG_N
                if "index scan" in plan_str or "bitmap" in plan_str
                else O_1
            )
        return complexity, warnings, is_table_scan

    def _analyze_mysql_plan(
        self, plan: list[list[Any]], plan_str: str
    ) -> tuple[str, list[str], bool]:
        """Analyse a MySQL EXPLAIN result."""
        warnings: list[str] = []
        is_table_scan = False
        has_sort = False
        # MySQL EXPLAIN columns (positional):
        #   0: id  1: select_type  2: table  3: partitions  4: type
        #   5: possible_keys  6: key  7: key_len  8: ref
        #   9: rows  10: filtered  11: Extra
        # type values: ALL (scan), index, range, ref, eq_ref, const
        # Extra values: Using filesort, Using temporary, ...
        for row in plan:
            if len(row) > 4:
                join_type = str(row[4]).upper()
                table_name = str(row[2])
                extra = str(row[11]).lower() if len(row) > 11 else ""
                if join_type == "ALL":
                    is_table_scan = True
                    warnings.append(
                        "Full table scan (ALL) detected on table "
                        f"`{table_name}`!"
                    )
                elif join_type == "INDEX":
                    warnings.append(
                        "Full index scan (INDEX) detected on table "
                        f"`{table_name}`. Reads all index keys!"
                    )
                if "using filesort" in extra:
                    has_sort = True
                    warnings.append(
                        f"Filesort required on table `{table_name}`. "
                        "Add an index on the ORDER BY / GROUP BY "
                        "column(s) to eliminate the sort step."
                    )

        if is_table_scan:
            complexity = O_N
        elif has_sort:
            complexity = O_N_LOG_N
        else:
            has_index_match = any(
                str(r[4]).upper() in {"RANGE", "REF", "EQ_REF"}
                for r in plan
                if len(r) > 4
            )
            complexity = O_LOG_N if has_index_match else O_1
        return complexity, warnings, is_table_scan

    def _analyze_fallback_plan(
        self, plan_str: str
    ) -> tuple[str, list[str], bool]:
        """Analyse a plan from an unknown engine using heuristic keywords."""
        warnings: list[str] = []
        is_table_scan = False
        complexity = O_1
        if (
            "seq scan" in plan_str
            or "full scan" in plan_str
            or "scan table" in plan_str
        ):
            is_table_scan = True
            complexity = O_N
            warnings.append("Full table scan suspected!")
        elif "sort" in plan_str or "filesort" in plan_str:
            complexity = O_N_LOG_N
            warnings.append(
                "Sort operation detected. Consider adding an index on "
                "the ORDER BY / GROUP BY column(s)."
            )
        elif "index" in plan_str:
            complexity = O_LOG_N
        return complexity, warnings, is_table_scan

    def _analyze_plan(
        self, plan: list[list[Any]], engine: str, sql: str
    ) -> tuple[str, list[str], bool]:
        # Default complexity
        complexity = O_1
        warnings: list[str] = []
        is_table_scan = False

        # If not SELECT, it's write complexity (usually O(1) or
        # O(log N) depending on indexes)
        if not sql.strip().upper().startswith("SELECT"):
            return O_1, [], False

        if not plan:
            # If we don't have a plan, estimate based on SQL
            if "WHERE" in sql.upper():
                # If filtered but no plan, warn that it might be table scan
                return (
                    "Unknown (No EXPLAIN plan available)",
                    [
                        "Could not analyze query execution plan. "
                        "Ensure database is accessible."
                    ],
                    False,
                )
            return O_1, [], False

        plan_str = " ".join([str(cell) for row in plan for cell in row]).lower()

        if "sqlite" in engine:
            complexity, warnings, is_table_scan = self._analyze_sqlite_plan(
                plan, plan_str
            )
        elif "postgresql" in engine:
            complexity, warnings, is_table_scan = self._analyze_postgresql_plan(
                plan, plan_str
            )
        elif "mysql" in engine:
            complexity, warnings, is_table_scan = self._analyze_mysql_plan(
                plan, plan_str
            )
        else:
            complexity, warnings, is_table_scan = self._analyze_fallback_plan(
                plan_str
            )

        # If there are joins and table scans, it could be O(N * M)
        if plan_str.count("scan table") > 1 or plan_str.count("seq scan") > 1:
            complexity = O_N_M
            warnings.append(
                "Multiple full table scans in joins! "
                "Very high risk of performance degradation."
            )

        return complexity, warnings, is_table_scan

    def _detect_n1_queries(self) -> None:
        # Group raw queries by caller file and line
        caller_groups: dict[tuple[str, int], list[dict[str, Any]]] = {}
        for q in self.raw_queries:
            caller = q.get("caller")
            if not caller:
                continue
            key = (caller["filename"], caller["lineno"])
            if key not in caller_groups:
                caller_groups[key] = []
            caller_groups[key].append(q)

        for key, group in caller_groups.items():
            count = len(group)
            if count <= 1:
                self.n1_groups[key] = {"count": count, "suggestion": None}
                continue

            # Identify if it looks like N+1 queries.
            # Generalize the SQL by replacing numeric IDs or
            # string parameters.
            sql_templates = set()
            for q in group:
                generalized = re.sub(r"=\s*\d+", "= ?", q["sql"])
                generalized = re.sub(r"IN\s*\([^)]+\)", "IN (?)", generalized)
                sql_templates.add(generalized)

            # If they are mostly executing the same SQL structures, it's N+1!
            if len(sql_templates) <= 2:
                filename = os.path.basename(key[0])
                line = key[1]
                code = group[0]["caller"]["line_content"]

                # Guess the model name and relation from code
                # e.g. "book.author" or "user.profile"
                relation_match = re.search(r"(\w+)\.(\w+)", code)
                relation_str = ""
                if relation_match:
                    parent_var, relation = relation_match.groups()
                    relation_str = (
                        f" `select_related('{relation}')` "
                        f"or `prefetch_related('{relation}')`"
                    )

                rel_tip = (
                    relation_str or "select_related() / prefetch_related()"
                )
                suggestion = (
                    f"N+1 query suspected at {filename}:{line}. "
                    "To solve this, pre-fetch related relations "
                    "on the initial query using "
                    f"{rel_tip}. "
                    f"This merges {count} roundtrips into a single query!"
                )
                self.n1_groups[key] = {"count": count, "suggestion": suggestion}
            else:
                self.n1_groups[key] = {"count": count, "suggestion": None}

    def _generate_suggestions(
        self,
        sql: str,
        params: Any,
        rows_fetched: int,
        caller: Optional[dict[str, Any]],
        complexity: str,
        plan_warnings: list[str],
        is_table_scan: bool,
        connection: Any,
    ) -> tuple[list[str], list[str]]:
        warnings: list[str] = list(plan_warnings)
        suggestions: list[str] = []

        sql_upper = sql.upper()

        # 1. Sequential scan/Table scan suggestion
        if is_table_scan:
            # Try to identify filtered columns in the WHERE clause
            where_match = re.search(
                r"WHERE\s+(.+?)(?:GROUP BY|ORDER BY|LIMIT|$)",
                sql_upper,
                re.DOTALL,
            )
            filter_cols = []
            if where_match:
                where_clause = where_match.group(1)
                # Find column names like `table`.`column` = %s or `column` = %s
                cols = re.findall(
                    r'(?:"\w+"."(\w+)"|`\w+`.`(\w+)`|\b(\w+)\b)\s*(=|IN|LIKE|>|<|>=|<=)',
                    where_clause,
                )
                for col_group in cols:
                    col = next((c for c in col_group[:-1] if c), None)
                    if col and col.upper() not in [
                        "AND",
                        "OR",
                        "NULL",
                        "TRUE",
                        "FALSE",
                    ]:
                        filter_cols.append(col.lower())

            col_str = (
                f" on field(s) `{', '.join(set(filter_cols))}`"
                if filter_cols
                else ""
            )
            suggestions.append(
                f"Create a database index{col_str} to avoid a full table scan. "
                "In Django, add `db_index=True` to the model field or list "
                "it in `indexes` under the model's `Meta` class."
            )

        # 2. Large volume retrieval space complexity suggestion
        if rows_fetched > 100:
            warnings.append(
                f"Large result set! Retrieved {rows_fetched} rows in memory."
            )
            suggestions.append(
                f"Query fetched {rows_fetched} rows. Consider slicing the "
                "queryset (e.g. `[:50]`) to paginate, or use `.iterator()` "
                "if processing many items sequentially to reduce memory "
                "footprint (space complexity)."
            )

        # 3. Missing limits on SELECT
        if sql_upper.startswith("SELECT") and "LIMIT" not in sql_upper:
            # If not a count query and not checking single row
            if "COUNT(" not in sql_upper and "LIMIT 1" not in sql_upper:
                # If space complexity could be huge
                suggestions.append(
                    "No LIMIT clause detected on this SELECT query. "
                    "If the table grows, this will fetch all rows into "
                    "memory. Consider limiting results using slicing, e.g. "
                    "`queryset[:100]`."
                )

        # 4. Too many columns fetched (unneeded space complexity)
        # Count commas in SELECT clause before FROM to estimate columns
        select_clause_match = re.search(
            r"SELECT\s+(.+?)\s+FROM", sql_upper, re.DOTALL
        )
        if select_clause_match:
            select_clause = select_clause_match.group(1)
            # Count columns roughly
            col_count = select_clause.count(",") + 1
            if (
                col_count > 15 and "*" not in select_clause
            ):  # Django typically selects all fields explicitly
                suggestions.append(
                    f"Query selects {col_count} columns. If you only need "
                    "a few fields, use `.only('field1', 'field2')` or "
                    "`.defer('heavy_field')` to optimize memory usage "
                    "(space complexity)."
                )

        # 5. len() vs count() detection
        if caller:
            code_line = caller["line_content"]
            if "len(" in code_line and rows_fetched > 5:
                warnings.append(
                    "Potential inefficient row counting using "
                    "`len(queryset)` instead of `.count()`."
                )
                suggestions.append(
                    "You are using Python's `len()` on a queryset, "
                    "which loads all rows into memory and counts them. "
                    "Use `.count()` to perform a `SELECT COUNT(*)` in "
                    "the database, which is O(1) in memory and "
                    "extremely fast."
                )

            # 6. .exists() hint when filtering inside an if-check
            if (
                "if " in code_line
                and ".filter(" in code_line
                and ".exists()" not in code_line
                and rows_fetched > 1
            ):
                suggestions.append(
                    "If you are only checking for the existence of "
                    "records, use `.exists()` instead of evaluating "
                    "the whole queryset. `.exists()` adds a `LIMIT 1` "
                    "and avoids loading rows into memory."
                )

        return warnings, suggestions

    def _get_code_snippet(
        self, filename: str, lineno: int, context_lines: int = 3
    ) -> Optional[list[dict[str, Any]]]:
        if not os.path.exists(filename):
            return None

        try:
            with open(filename, "r", encoding="utf-8") as f:
                lines = f.readlines()

            start = max(0, lineno - context_lines - 1)
            end = min(len(lines), lineno + context_lines)

            snippet = []
            for i in range(start, end):
                curr_line_no = i + 1
                snippet.append(
                    {
                        "line_no": curr_line_no,
                        "content": lines[i].rstrip("\n"),
                        "is_target": curr_line_no == lineno,
                    }
                )
            return snippet
        except Exception:
            return None
