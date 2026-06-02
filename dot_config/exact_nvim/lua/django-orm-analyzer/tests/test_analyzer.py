"""Tests for the QueryAnalyzer class."""

import os
import sys
import tempfile
import unittest
from typing import Any
from unittest.mock import MagicMock

# Adjust path to import from parent directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from django_orm_analyzer.analyzer import QueryAnalyzer


class TestQueryAnalyzer(unittest.TestCase):
    """Tests for the QueryAnalyzer class."""

    def test_get_query_type(self) -> None:
        """Test that query types are correctly identified."""
        analyzer = QueryAnalyzer([])
        self.assertEqual(analyzer._get_query_type("SELECT * FROM x"), "SELECT")
        self.assertEqual(
            analyzer._get_query_type("  INSERT INTO x VALUES (1)"),
            "INSERT",
        )
        self.assertEqual(analyzer._get_query_type("update x set y=1"), "UPDATE")
        self.assertEqual(analyzer._get_query_type("DELETE FROM x"), "DELETE")
        self.assertEqual(analyzer._get_query_type("CREATE TABLE x"), "OTHER")

    def test_analyze_plan_sqlite_table_scan(self) -> None:
        """Test SQLite table scan detection."""
        analyzer = QueryAnalyzer([])
        plan = [[0, 0, 0, "SCAN TABLE auth_user"]]
        engine = "sqlite3"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan, engine, "SELECT * FROM auth_user"
        )
        self.assertTrue(is_table_scan)
        self.assertIn("Full table scan detected", warnings[0])
        self.assertEqual(complexity, "O(N) [Linear Time - Full Table Scan!]")

    def test_analyze_plan_sqlite_index_scan(self) -> None:
        """Test SQLite index scan detection."""
        analyzer = QueryAnalyzer([])
        plan = [
            [
                0,
                0,
                0,
                "SEARCH TABLE auth_user USING INDEX auth_user_idx (email=?)",
            ]
        ]
        engine = "sqlite3"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan, engine, "SELECT * FROM auth_user WHERE email=?"
        )
        self.assertFalse(is_table_scan)
        self.assertEqual(complexity, "O(log N) [Logarithmic Time - Index Scan]")

    def test_analyze_plan_postgres_seq_scan(self) -> None:
        """Test PostgreSQL sequential scan detection."""
        analyzer = QueryAnalyzer([])
        plan = [
            ["Seq Scan on auth_user  (cost=0.00..35.50 rows=2040 width=106)"]
        ]
        engine = "postgresql"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan, engine, "SELECT * FROM auth_user"
        )
        self.assertTrue(is_table_scan)
        self.assertIn("Sequential (full table) scan", warnings[0])

    def test_analyze_plan_mysql_all_scan(self) -> None:
        """Test MySQL ALL-type scan detection."""
        analyzer = QueryAnalyzer([])
        # MySQL structure: id, select_type, table, partitions, type,
        # possible_keys, key, key_len, ref, rows, filtered, Extra
        plan = [
            [
                1,
                "SIMPLE",
                "auth_user",
                None,
                "ALL",
                None,
                None,
                None,
                None,
                10,
                100.0,
                "",
            ]
        ]
        engine = "mysql"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan, engine, "SELECT * FROM auth_user"
        )
        self.assertTrue(is_table_scan)
        self.assertIn("Full table scan (ALL)", warnings[0])

    def test_analyze_plan_mysql_full_index_scan(self) -> None:
        """Test MySQL full index scan detection."""
        analyzer = QueryAnalyzer([])
        plan = [
            [
                1,
                "SIMPLE",
                "auth_user",
                None,
                "INDEX",
                None,
                "idx_email",
                "255",
                None,
                10,
                100.0,
                "Using index",
            ]
        ]
        engine = "mysql"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan, engine, "SELECT email FROM auth_user"
        )
        self.assertFalse(is_table_scan)
        self.assertIn("Full index scan (INDEX)", warnings[0])

    def test_analyze_plan_nested_loops(self) -> None:
        """Test nested loop / cross join detection."""
        analyzer = QueryAnalyzer([])
        plan = [
            [0, 0, 0, "SCAN TABLE auth_user"],
            [0, 0, 0, "SCAN TABLE mabyduck_project"],
        ]
        engine = "sqlite3"
        complexity, warnings, is_table_scan = analyzer._analyze_plan(
            plan,
            engine,
            "SELECT * FROM auth_user JOIN mabyduck_project",
        )
        self.assertTrue(is_table_scan)
        self.assertEqual(complexity, "O(N * M) [Nested Loop / Cross Join!]")
        self.assertTrue(
            any("Multiple full table scans in joins" in w for w in warnings)
        )

    def test_generate_suggestions_missing_limit(self) -> None:
        """Test suggestion generated for missing LIMIT clause."""
        analyzer = QueryAnalyzer([])
        warnings, suggestions = analyzer._generate_suggestions(
            sql="SELECT * FROM auth_user",
            params=(),
            rows_fetched=5,
            caller=None,
            complexity="O(1)",
            plan_warnings=[],
            is_table_scan=False,
            connection=None,
        )
        self.assertTrue(
            any("No LIMIT clause detected" in s for s in suggestions)
        )

    def test_generate_suggestions_large_result(self) -> None:
        """Test suggestion generated for large result sets."""
        analyzer = QueryAnalyzer([])
        warnings, suggestions = analyzer._generate_suggestions(
            sql="SELECT * FROM auth_user LIMIT 500",
            params=(),
            rows_fetched=200,
            caller=None,
            complexity="O(1)",
            plan_warnings=[],
            is_table_scan=False,
            connection=None,
        )
        self.assertTrue(any("Large result set" in w for w in warnings))
        self.assertTrue(any("Query fetched 200 rows" in s for s in suggestions))

    def test_generate_suggestions_len_vs_count(self) -> None:
        """Test suggestion for using .count() instead of len()."""
        analyzer = QueryAnalyzer([])
        caller = {
            "filename": "views.py",
            "lineno": 10,
            "line_content": "count = len(User.objects.all())",
            "function": "my_view",
        }
        warnings, suggestions = analyzer._generate_suggestions(
            sql="SELECT * FROM auth_user",
            params=(),
            rows_fetched=50,
            caller=caller,
            complexity="O(1)",
            plan_warnings=[],
            is_table_scan=False,
            connection=None,
        )
        self.assertTrue(any("len(queryset)" in w for w in warnings))
        self.assertTrue(any("SELECT COUNT(*)" in s for s in suggestions))

    def test_get_code_snippet(self) -> None:
        """Test that code snippets are correctly retrieved."""
        analyzer = QueryAnalyzer([])
        with tempfile.NamedTemporaryFile("w", delete=False) as temp_file:
            temp_file.write("line 1\nline 2\nline 3\nline 4\n")
            temp_path = temp_file.name

        try:
            snippet = analyzer._get_code_snippet(temp_path, 3, context_lines=1)
            assert snippet is not None
            self.assertEqual(len(snippet), 3)
            self.assertEqual(snippet[0]["line_no"], 2)
            self.assertEqual(snippet[1]["line_no"], 3)
            self.assertTrue(snippet[1]["is_target"])
        finally:
            os.remove(temp_path)

    def test_get_code_snippet_nonexistent(self) -> None:
        """Test that None is returned for nonexistent files."""
        analyzer = QueryAnalyzer([])
        self.assertIsNone(analyzer._get_code_snippet("/nonexistent", 3))

    def test_detect_n1_queries(self) -> None:
        """Test N+1 query detection."""
        caller = {
            "filename": "views.py",
            "lineno": 20,
            "line_content": "name = book.author.name",
            "function": "my_view",
        }
        raw_queries = [
            {
                "sql": "SELECT * FROM author WHERE id = 1",
                "params": (1,),
                "caller": caller,
            },
            {
                "sql": "SELECT * FROM author WHERE id = 2",
                "params": (2,),
                "caller": caller,
            },
            {
                "sql": "SELECT * FROM author WHERE id = 3",
                "params": (3,),
                "caller": caller,
            },
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertEqual(summary["n1_warnings_count"], 1)
        self.assertEqual(summary["total_queries"], 3)
        self.assertTrue(any("N+1" in w for w in analyzed[0]["warnings"]))

    def test_analyze_write_query(self) -> None:
        """Test analysis of a write (INSERT) query."""
        raw_queries = [
            {
                "sql": "INSERT INTO auth_user (username) VALUES ('test')",
                "params": (),
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertEqual(analyzed[0]["query_type"], "INSERT")
        self.assertEqual(analyzed[0]["complexity"], "O(1) [Constant Time]")

    def test_analyze_plan_sqlite_real_or_mock(self) -> None:
        """Test SQLite query plan analysis with a mock connection."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [[0, 0, 0, "SCAN TABLE test_table"]]
        mock_conn = MagicMock()
        mock_conn.settings_dict = {"ENGINE": "sqlite3"}
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

        raw_queries = [
            {
                "sql": "SELECT * FROM test_table",
                "params": (),
                "connection": mock_conn,
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertTrue(analyzed[0]["complexity"].startswith("O(N)"))
        self.assertTrue(summary["table_scan_warnings_count"] > 0)

    def test_analyze_plan_postgres_real_or_mock(self) -> None:
        """Test PostgreSQL query plan analysis with a mock connection."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [["Seq Scan on test_table"]]
        mock_conn = MagicMock()
        mock_conn.settings_dict = {"ENGINE": "postgresql"}
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

        raw_queries = [
            {
                "sql": "SELECT * FROM test_table",
                "params": (),
                "connection": mock_conn,
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertTrue(analyzed[0]["complexity"].startswith("O(N)"))

    def test_analyze_plan_mysql_real_or_mock(self) -> None:
        """Test MySQL query plan analysis with a mock connection."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [
            [
                1,
                "SIMPLE",
                "test_table",
                None,
                "ALL",
                None,
                None,
                None,
                None,
                10,
                100.0,
                "",
            ]
        ]
        mock_conn = MagicMock()
        mock_conn.settings_dict = {"ENGINE": "mysql"}
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

        raw_queries = [
            {
                "sql": "SELECT * FROM test_table",
                "params": (),
                "connection": mock_conn,
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertTrue(analyzed[0]["complexity"].startswith("O(N)"))

    def test_analyze_plan_fallback_real_or_mock(self) -> None:
        """Test fallback query plan analysis for unknown engines."""
        mock_cursor = MagicMock()
        mock_cursor.fetchall.return_value = [["seq scan in plan"]]
        mock_conn = MagicMock()
        mock_conn.settings_dict = {"ENGINE": "oracle"}
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

        raw_queries = [
            {
                "sql": "SELECT * FROM test_table",
                "params": (),
                "connection": mock_conn,
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertTrue(analyzed[0]["complexity"].startswith("O(N)"))

    def test_analyze_plan_explain_error(self) -> None:
        """Test graceful handling when EXPLAIN raises an error."""
        mock_conn = MagicMock()
        mock_conn.settings_dict = {"ENGINE": "sqlite3"}
        mock_conn.cursor.side_effect = Exception("Explain failed")

        raw_queries = [
            {
                "sql": "SELECT * FROM test_table WHERE id = 1",
                "params": (),
                "connection": mock_conn,
                "caller": None,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertIn("Unknown", analyzed[0]["complexity"])

    def test_generate_suggestions_column_and_exists(self) -> None:
        """Test suggestions for column count and .exists() usage."""
        caller = {
            "filename": "views.py",
            "lineno": 15,
            "line_content": (
                "if User.objects.filter(email='test@example.com'): pass"
            ),
            "function": "my_view",
        }
        # Heavy select clause
        heavy_select = (
            "SELECT "
            + ",".join([f"c{i}" for i in range(25)])
            + " FROM test_table"
        )
        raw_queries = [
            {
                "sql": heavy_select,
                "params": (),
                "rows_fetched": 5,
                "caller": caller,
            }
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertTrue(
            any("Query selects" in s for s in analyzed[0]["suggestions"])
        )
        self.assertTrue(
            any("use `.exists()`" in s for s in analyzed[0]["suggestions"])
        )

    def test_detect_n1_queries_mismatched_sql(self) -> None:
        """Test that mismatched SQL does not trigger N+1 warnings."""
        caller = {
            "filename": "views.py",
            "lineno": 20,
            "line_content": "name = book.author.name",
            "function": "my_view",
        }
        raw_queries: list[dict[str, Any]] = [
            {
                "sql": "SELECT * FROM author WHERE id = 1",
                "params": (1,),
                "caller": caller,
            },
            {
                "sql": "SELECT * FROM publisher WHERE name = 'x'",
                "params": (),
                "caller": caller,
            },
            {
                "sql": "SELECT * FROM book WHERE title = 'y'",
                "params": (),
                "caller": caller,
            },
        ]
        analyzer = QueryAnalyzer(raw_queries)
        analyzed, summary = analyzer.analyze()
        self.assertEqual(summary["n1_warnings_count"], 0)

    def test_connection_key_error(self) -> None:
        """Test graceful handling of KeyError on connection access."""

        class BadDict(dict[str, Any]):
            """A dict subclass that raises KeyError on contains check."""

            def __contains__(self, item: object) -> bool:
                """Raise KeyError for 'connection' key."""
                if item == "connection":
                    raise KeyError("contains error")
                return super().__contains__(item)

        q = BadDict({"sql": "SELECT 1", "params": ()})
        analyzer = QueryAnalyzer([q])
        analyzed, summary = analyzer.analyze()
        self.assertEqual(summary["total_queries"], 1)

    def test_get_query_plan_non_select(self) -> None:
        """Test that non-SELECT queries return an empty plan."""
        analyzer = QueryAnalyzer([])
        plan, eng = analyzer._get_query_plan(
            MagicMock(), "INSERT INTO x VALUES (1)", ()
        )
        self.assertEqual(plan, [])

    def test_postgres_heavy_sort(self) -> None:
        """Test PostgreSQL sort spilling to disk warning."""
        analyzer = QueryAnalyzer([])
        plan = [["Sort spilling to disk"]]
        comp, warnings, is_scan = analyzer._analyze_plan(
            plan, "postgresql", "SELECT * FROM x"
        )
        self.assertTrue(any("spilling to disk" in w for w in warnings))

    def test_fallback_multiple_scans(self) -> None:
        """Test fallback engine nested loop detection."""
        analyzer = QueryAnalyzer([])
        plan = [["seq scan on x"], ["seq scan on y"]]
        comp, warnings, is_scan = analyzer._analyze_plan(
            plan, "oracle", "SELECT * FROM x"
        )
        self.assertEqual(comp, "O(N * M) [Nested Loop / Cross Join!]")

    def test_suggestions_complex_where(self) -> None:
        """Test index suggestion for complex WHERE clauses."""
        analyzer = QueryAnalyzer([])
        sql = (
            'SELECT * FROM x WHERE "x"."email" = %s'
            " AND name = %s AND status = %s"
        )
        warnings, suggs = analyzer._generate_suggestions(
            sql=sql,
            params=(),
            rows_fetched=5,
            caller=None,
            complexity="O(N)",
            plan_warnings=["Table scan"],
            is_table_scan=True,
            connection=None,
        )
        self.assertTrue(any("Create a database index" in s for s in suggs))
        self.assertTrue(
            any("email" in s and "name" in s and "status" in s for s in suggs)
        )

    def test_fallback_index_scan(self) -> None:
        """Test fallback engine index scan detection."""
        analyzer = QueryAnalyzer([])
        plan = [["index scan on x"]]
        comp, warnings, is_scan = analyzer._analyze_plan(
            plan, "oracle", "SELECT * FROM x"
        )
        self.assertEqual(comp, "O(log N) [Logarithmic Time - Index Scan]")


if __name__ == "__main__":
    unittest.main()
