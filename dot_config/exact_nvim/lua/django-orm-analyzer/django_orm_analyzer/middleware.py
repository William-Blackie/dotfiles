"""Middleware components to intercept and profile Django database cursors."""

import inspect
import os
import sys
import time
from typing import Any, Generator, Optional, cast

from django.conf import settings
from django.db import connections
from django.template.loader import render_to_string

from django_orm_analyzer.analyzer import QueryAnalyzer

# ANSI color codes for premium terminal styling
CLR_BLUE = "\033[94m"
CLR_GREEN = "\033[92m"
CLR_WARNING = "\033[93m"
CLR_FAIL = "\033[91m"
CLR_END = "\033[0m"
CLR_BOLD = "\033[1m"
CLR_CYAN = "\033[96m"


def get_orm_caller() -> Optional[dict[str, Any]]:
    """Captures absolute file path, line number, and caller of the ORM call.

    Returns:
        A dictionary containing caller info, or None.
    """
    # Capture stack trace
    for frame_info in inspect.stack():
        filename = frame_info.filename
        abs_path = os.path.abspath(filename)

        # Ignore libraries and Django internals
        if any(
            p in abs_path
            for p in [
                "site-packages",
                "/lib/python",
                "django/",
                "django_orm_analyzer",
                "<string>",
                "importlib",
            ]
        ):
            continue

        # Ignore terminal/system wrappers
        if abs_path.endswith("middleware.py") or "db/models" in abs_path:
            continue

        line_no = frame_info.lineno
        code_context = frame_info.code_context
        line_content = code_context[0].strip() if code_context else "Unknown"

        return {
            "filename": abs_path,
            "lineno": line_no,
            "line_content": line_content,
            "function": frame_info.function,
        }
    return None


class RowCountingCursor:
    """Wrapper cursor that intercepts fetch operations to count returned rows.

    Attributes:
        cursor: The underlying database cursor.
        query_info: A dictionary to record the count of fetched rows.
    """

    cursor: Any
    query_info: dict[str, Any]

    def __init__(self, cursor: Any, query_info: dict[str, Any]) -> None:
        """Initializes the wrapper cursor with tracking context.

        Args:
            cursor: The underlying database cursor.
            query_info: A dictionary to record fetched row counts.
        """
        self.cursor = cursor
        self.query_info = query_info

    def fetchone(self) -> Any:
        """Fetches a single row and increments the row counter if successful."""
        row = self.cursor.fetchone()
        if row is not None:
            self.query_info["rows_fetched"] += 1
        return row

    def fetchmany(self, size: Optional[int] = None) -> list[Any]:
        """Fetches multiple rows and increments the rows fetched count."""
        if size is None:
            rows = self.cursor.fetchmany()
        else:
            rows = self.cursor.fetchmany(size)
        self.query_info["rows_fetched"] += len(rows)
        return cast(list[Any], rows)

    def fetchall(self) -> list[Any]:
        """Fetches all rows and increments the rows fetched count."""
        rows = self.cursor.fetchall()
        self.query_info["rows_fetched"] += len(rows)
        return cast(list[Any], rows)

    def __iter__(self) -> Generator[Any, None, None]:
        """Iterates over cursor result rows and increments row counts."""
        for row in self.cursor:
            self.query_info["rows_fetched"] += 1
            yield row

    def __enter__(self) -> "RowCountingCursor":
        """Enters the context manager block and returns self."""
        return self

    def __exit__(
        self,
        exc_type: Optional[type[BaseException]],
        exc_val: Optional[BaseException],
        exc_tb: Optional[Any],
    ) -> Optional[bool]:
        """Exits the context manager block and delegates clean up."""
        if hasattr(self.cursor, "__exit__"):
            return cast(
                Optional[bool], self.cursor.__exit__(exc_type, exc_val, exc_tb)
            )
        return None

    def __getattr__(self, name: str) -> Any:
        """Proxies attribute accesses to the underlying database cursor."""
        return getattr(self.cursor, name)


class ORMQueryInterceptor:
    """Interceptor to hook database execution and capture queries.

    Attributes:
        queries: A list of intercepted query dictionaries.
        connection: The Django database connection instance.
    """

    queries: list[dict[str, Any]]
    connection: Any

    def __init__(self, connection_obj: Any) -> None:
        """Initializes the query interceptor.

        Args:
            connection_obj: The active Django database connection.
        """
        self.queries = []
        self.connection = connection_obj

    def __call__(
        self, execute: Any, sql: str, params: Any, many: bool, context: Any
    ) -> RowCountingCursor:
        """Intercepts query execution, captures parameters, and tracks time."""
        start = time.perf_counter()
        query_info: dict[str, Any] = {
            "sql": sql,
            "params": params,
            "duration": 0.0,
            "rows_fetched": 0,
            "caller": get_orm_caller(),
            "connection": self.connection,
        }
        self.queries.append(query_info)

        try:
            cursor = execute(sql, params, many, context)
            return RowCountingCursor(cursor, query_info)
        finally:
            query_info["duration"] = time.perf_counter() - start


class ORMAnalyzerMiddleware:
    """Django middleware to profile ORM database queries.

    Aggregates execution plan metadata, reports table scans and N+1
    patterns, and displays visual analysis metrics.

    Attributes:
        get_response: The standard Django response handler callback.
        enabled: Boolean indicating if the middleware is active.
    """

    get_response: Any
    enabled: bool

    def __init__(self, get_response: Any) -> None:
        """Initializes the query analyzer middleware.

        Args:
            get_response: The standard Django response handler callback.
        """
        self.get_response = get_response
        self.enabled = getattr(
            settings, "DJANGO_ORM_ANALYZER_ENABLED", settings.DEBUG
        )

    def __call__(self, request: Any) -> Any:
        """Intercepts queries for request lifecycle and prints reports."""
        if not self.enabled:
            return self.get_response(request)

        # Ignore standard static file paths to avoid noise
        path = request.path
        if any(
            path.startswith(p)
            for p in [settings.STATIC_URL, settings.MEDIA_URL, "/__debug__/"]
        ):
            return self.get_response(request)

        # Intercept queries on all active database connections
        interceptors: dict[str, ORMQueryInterceptor] = {}
        wrappers: list[Any] = []

        for alias in connections:
            conn = connections[alias]
            interceptor = ORMQueryInterceptor(conn)
            interceptors[alias] = interceptor
            wrapper = conn.execute_wrapper(interceptor)
            wrappers.append(wrapper)
            wrapper.__enter__()

        try:
            response = self.get_response(request)
        finally:
            for wrapper in reversed(wrappers):
                wrapper.__exit__(None, None, None)

        # Aggregate queries from all databases
        all_queries: list[dict[str, Any]] = []
        for interceptor in interceptors.values():
            all_queries.extend(interceptor.queries)

        if not all_queries:
            return response

        # Run analysis
        analyzer = QueryAnalyzer(all_queries)
        analyzed_queries, summary = analyzer.analyze()

        # 1. Print report to terminal
        self._print_terminal_report(request.path, analyzed_queries, summary)

        # 2. Inject Web UI Dashboard into HTML responses
        content_type = response.get("Content-Type", "").split(";")[0]
        if content_type == "text/html":
            try:
                html_to_inject = render_to_string(
                    "django_orm_analyzer/panel.html",
                    {
                        "queries": analyzed_queries,
                        "summary": summary,
                        "path": request.path,
                    },
                )

                content = response.content.decode("utf-8")
                body_close_idx = content.lower().rfind("</body>")
                if body_close_idx != -1:
                    new_content = (
                        content[:body_close_idx]
                        + html_to_inject
                        + content[body_close_idx:]
                    )
                    response.content = new_content.encode("utf-8")
                    if "Content-Length" in response:
                        response["Content-Length"] = str(len(response.content))
            except Exception as e:
                # Log template rendering errors gracefully to avoid breaking
                # page load
                sys.stderr.write(
                    f"{CLR_FAIL}django-orm-analyzer injection failed: "
                    f"{e}{CLR_END}\n"
                )

        return response

    def _print_terminal_report(
        self, path: str, queries: list[dict[str, Any]], summary: dict[str, Any]
    ) -> None:
        # Determine highlighting colors for general status
        color = CLR_GREEN
        if (
            summary["n1_warnings_count"] > 0
            or summary["table_scan_warnings_count"] > 0
        ):
            color = CLR_FAIL
        elif summary["warnings_count"] > 0:
            color = CLR_WARNING

        sys.stdout.write(f"\n{CLR_BOLD}{color}{'=' * 80}{CLR_END}\n")
        sys.stdout.write(
            f"{CLR_BOLD}{color}  DJANGO ORM QUERY ANALYSIS - {path}{CLR_END}\n"
        )
        sys.stdout.write(f"{CLR_BOLD}{'=' * 80}{CLR_END}\n")

        sys.stdout.write(
            f"  {CLR_BOLD}Total Queries:{CLR_END} "
            f"{summary['total_queries']} | "
            f"{CLR_BOLD}Total Time:{CLR_END} "
            f"{summary['total_time_ms']:.2f}ms | "
            f"{CLR_BOLD}Total Rows Fetched:{CLR_END} "
            f"{summary['total_rows_fetched']} | "
            f"{CLR_BOLD}Warnings:{CLR_END} "
            f"{color}{summary['warnings_count']}{CLR_END}\n"
        )
        sys.stdout.write(f"{CLR_BOLD}{'-' * 80}{CLR_END}\n\n")

        # Try using Pygments for syntax highlighting if available
        pygments_avail = False
        try:
            from pygments import highlight
            from pygments.formatters import TerminalFormatter
            from pygments.lexers import PythonLexer, SqlLexer

            sql_lexer = SqlLexer()
            py_lexer = PythonLexer()
            formatter = TerminalFormatter()
            pygments_avail = True
        except ImportError:
            pass

        for q in queries:
            q_color = CLR_GREEN
            if q["warnings"]:
                q_color = (
                    CLR_FAIL
                    if any(
                        "N+1" in w or "scan" in w.lower() for w in q["warnings"]
                    )
                    else CLR_WARNING
                )

            # Query Header
            sys.stdout.write(
                f"{CLR_BOLD}{q_color}[QUERY {q['id']}] {q['query_type']} | "
                f"{q['duration_ms']}ms | Fetched {q['rows_fetched']} rows | "
                f"{q['complexity']}{CLR_END}\n"
            )

            # SQL
            sql_str = q["sql"]
            if pygments_avail:
                highlighted_sql = highlight(
                    sql_str, sql_lexer, formatter
                ).strip()
                sys.stdout.write(
                    f"  {CLR_BOLD}SQL:{CLR_END} {highlighted_sql}\n"
                )
            else:
                sys.stdout.write(
                    f"  {CLR_BOLD}SQL:{CLR_END} {CLR_CYAN}{sql_str}{CLR_END}\n"
                )

            # Warnings
            for warning in q["warnings"]:
                sys.stdout.write(
                    f"  {CLR_BOLD}{CLR_FAIL}⚠️ WARNING:{CLR_END} "
                    f"{CLR_FAIL}{warning}{CLR_END}\n"
                )

            # Suggestions
            for suggestion in q["suggestions"]:
                sys.stdout.write(
                    f"  {CLR_BOLD}{CLR_GREEN}💡 SUGGESTION:{CLR_END} "
                    f"{CLR_GREEN}{suggestion}{CLR_END}\n"
                )

            # Caller ORM Line
            caller = q["caller"]
            if caller:
                fn = caller["filename"]
                rel_path = os.path.relpath(fn) if os.path.exists(fn) else fn
                sys.stdout.write(
                    f"  {CLR_BOLD}Caller:{CLR_END} {rel_path}:"
                    f"{caller['lineno']} in `{caller['function']}()`\n"
                )

                # Print code snippet surrounding the ORM call
                if q["code_snippet"]:
                    sys.stdout.write(f"    {CLR_BLUE}Code Context:{CLR_END}\n")
                    for line in q["code_snippet"]:
                        marker = (
                            f"{CLR_FAIL}➔ {CLR_END}"
                            if line["is_target"]
                            else "  "
                        )
                        line_num_str = f"{line['line_no']:4d} |"
                        line_content = line["content"]

                        if line["is_target"]:
                            if pygments_avail:
                                highlighted_line = highlight(
                                    line_content, py_lexer, formatter
                                ).rstrip("\n")
                                sys.stdout.write(
                                    f"      {marker}{CLR_BOLD}"
                                    f"{line_num_str} {highlighted_line}"
                                    f"{CLR_END}\n"
                                )
                            else:
                                sys.stdout.write(
                                    f"      {marker}{CLR_BOLD}"
                                    f"{line_num_str} {line_content}"
                                    f"{CLR_END}\n"
                                )
                        else:
                            sys.stdout.write(
                                f"        {line_num_str} {line_content}\n"
                            )

            sys.stdout.write(f"  {CLR_BOLD}{'-' * 80}{CLR_END}\n")

        sys.stdout.write(f"{CLR_BOLD}{color}{'=' * 80}{CLR_END}\n\n")
