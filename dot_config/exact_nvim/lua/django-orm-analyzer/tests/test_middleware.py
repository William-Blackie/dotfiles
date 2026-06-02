"""Tests for the ORMAnalyzerMiddleware and related components."""

import os
import sys
import unittest
from typing import Any
from unittest.mock import MagicMock, patch

# Adjust path to import from parent directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Configure Django settings before importing any Django components
from django.conf import settings

if not settings.configured:
    settings.configure(
        DEBUG=True,
        SECRET_KEY="test_secret_key",
        DJANGO_ORM_ANALYZER_ENABLED=True,
        STATIC_URL="/static/",
        MEDIA_URL="/media/",
        DATABASES={
            "default": {
                "ENGINE": "django.db.backends.sqlite3",
                "NAME": ":memory:",
            }
        },
    )
import django

django.setup()

from django_orm_analyzer.apps import DjangoORMAnalyzerConfig  # noqa: E402
from django_orm_analyzer.middleware import (  # noqa: E402
    ORMAnalyzerMiddleware,
    ORMQueryInterceptor,
    RowCountingCursor,
    get_orm_caller,
)


class TestApps(unittest.TestCase):
    """Tests for the DjangoORMAnalyzerConfig app config."""

    def test_apps_config(self) -> None:
        """Test that app config name and verbose_name are correct."""
        self.assertEqual(DjangoORMAnalyzerConfig.name, "django_orm_analyzer")
        self.assertEqual(
            DjangoORMAnalyzerConfig.verbose_name,
            "Django ORM Query Complexity Analyzer",
        )


class TestMiddleware(unittest.TestCase):
    """Tests for the ORM middleware and related utilities."""

    def test_get_orm_caller_empty(self) -> None:
        """Test that None is returned when the stack is empty."""
        with patch("inspect.stack", return_value=[]):
            self.assertIsNone(get_orm_caller())

    def test_get_orm_caller_filtered(self) -> None:
        """Test that Django internals are filtered from caller info."""
        # Create a mock stack frame where files should be ignored
        frame1 = MagicMock()
        frame1.filename = "django/db/models/query.py"
        frame2 = MagicMock()
        frame2.filename = "views.py"
        frame2.lineno = 42
        frame2.code_context = ["users = User.objects.all()"]
        frame2.function = "my_view"

        with patch("inspect.stack", return_value=[frame1, frame2]):
            caller = get_orm_caller()
            self.assertIsNotNone(caller)
            assert caller is not None
            self.assertEqual(caller["filename"], os.path.abspath("views.py"))
            self.assertEqual(caller["lineno"], 42)
            self.assertEqual(
                caller["line_content"], "users = User.objects.all()"
            )
            self.assertEqual(caller["function"], "my_view")

    def test_row_counting_cursor(self) -> None:
        """Test that RowCountingCursor tracks fetched row counts."""
        mock_cursor = MagicMock()
        mock_cursor.fetchone.return_value = ("row",)
        mock_cursor.fetchmany.return_value = [("row1",), ("row2",)]
        mock_cursor.fetchall.return_value = [("row3",)]
        mock_cursor.__iter__.return_value = iter([("row4",)])

        query_info = {"rows_fetched": 0}
        cursor = RowCountingCursor(mock_cursor, query_info)

        # fetchone
        self.assertEqual(cursor.fetchone(), ("row",))
        self.assertEqual(query_info["rows_fetched"], 1)

        # fetchmany without size
        self.assertEqual(cursor.fetchmany(), [("row1",), ("row2",)])
        self.assertEqual(query_info["rows_fetched"], 3)

        # fetchmany with size
        mock_cursor.fetchmany.return_value = [("row1_alt",)]
        self.assertEqual(cursor.fetchmany(1), [("row1_alt",)])
        self.assertEqual(query_info["rows_fetched"], 4)

        # fetchall
        self.assertEqual(cursor.fetchall(), [("row3",)])
        self.assertEqual(query_info["rows_fetched"], 5)

        # iter
        self.assertEqual(list(cursor), [("row4",)])
        self.assertEqual(query_info["rows_fetched"], 6)

        # enter/exit/getattr
        with cursor as c:
            self.assertEqual(c, cursor)
        mock_cursor.__exit__.assert_called_once()
        cursor.execute("SELECT 1")
        mock_cursor.execute.assert_called_with("SELECT 1")

    def test_orm_query_interceptor(self) -> None:
        """Test ORMQueryInterceptor wraps execution correctly."""
        mock_conn = MagicMock()
        interceptor = ORMQueryInterceptor(mock_conn)
        execute_mock = MagicMock(return_value="cursor")

        # Test call
        res_cursor = interceptor(
            execute_mock, "SELECT * FROM x", (1,), False, {}
        )
        self.assertIsInstance(res_cursor, RowCountingCursor)
        self.assertEqual(len(interceptor.queries), 1)
        q = interceptor.queries[0]
        self.assertEqual(q["sql"], "SELECT * FROM x")
        self.assertEqual(q["params"], (1,))
        self.assertEqual(q["connection"], mock_conn)

    def test_middleware_disabled(self) -> None:
        """Test middleware is bypassed when disabled in settings."""
        # Temporarily disable via settings
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", False):
            get_response = MagicMock(return_value="response")
            middleware = ORMAnalyzerMiddleware(get_response)

            request = MagicMock()
            request.path = "/test-path/"

            res = middleware(request)
            self.assertEqual(res, "response")
            get_response.assert_called_once_with(request)

    def test_middleware_ignore_paths(self) -> None:
        """Test middleware ignores static file paths."""
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", True):
            get_response = MagicMock(return_value="response")
            middleware = ORMAnalyzerMiddleware(get_response)

            request = MagicMock()
            request.path = "/static/css/main.css"

            res = middleware(request)
            self.assertEqual(res, "response")

    @patch("django_orm_analyzer.middleware.connections")
    @patch("django_orm_analyzer.middleware.render_to_string")
    @patch("sys.stdout.write")
    def test_middleware_enabled_with_queries(
        self, mock_stdout_write: Any, mock_render: Any, mock_connections: Any
    ) -> None:
        """Test middleware injects panel HTML for tracked queries."""
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", True):
            # Create a temporary file to act as the views.py source
            # file so code context is fetched and covered
            import tempfile

            with tempfile.NamedTemporaryFile(
                "w", delete=False, suffix=".py"
            ) as temp_file:
                temp_file.write(
                    "\n" * 9 + "users = User.objects.all()\n" + "\n" * 5
                )
                temp_path = temp_file.name

            try:
                # Mock connection and execute wrapper
                mock_conn_default = MagicMock()
                mock_conn_default.settings_dict = {
                    "ENGINE": "django.db.backends.sqlite3"
                }

                mock_connections.__iter__.return_value = ["default"]
                mock_connections.__getitem__.return_value = mock_conn_default

                def get_response_side_effect(req: Any) -> Any:
                    """Simulate two identical queries to trigger N+1."""
                    interceptor = mock_conn_default.execute_wrapper.call_args[
                        0
                    ][0]
                    interceptor.queries.append(
                        {
                            "sql": ("SELECT * FROM auth_user WHERE id = 1"),
                            "params": (1,),
                            "duration": 0.005,
                            "rows_fetched": 1,
                            "caller": {
                                "filename": temp_path,
                                "lineno": 10,
                                "line_content": ("users = User.objects.all()"),
                                "function": "get",
                            },
                            "connection": mock_conn_default,
                        }
                    )
                    interceptor.queries.append(
                        {
                            "sql": ("SELECT * FROM auth_user WHERE id = 2"),
                            "params": (2,),
                            "duration": 0.005,
                            "rows_fetched": 1,
                            "caller": {
                                "filename": temp_path,
                                "lineno": 10,
                                "line_content": ("users = User.objects.all()"),
                                "function": "get",
                            },
                            "connection": mock_conn_default,
                        }
                    )

                    response = MagicMock()
                    response.get.return_value = "text/html; charset=utf-8"
                    response.content = b"<html><body>Hello</body></html>"
                    # Make "Content-Length" check return True
                    response.__contains__.side_effect = lambda x: (
                        x == "Content-Length"
                    )
                    return response

                get_response = MagicMock(side_effect=get_response_side_effect)
                middleware = ORMAnalyzerMiddleware(get_response)

                # Setup render mock
                mock_render.return_value = "<div>Mock Panel</div>"

                request = MagicMock()
                request.path = "/users/"

                res = middleware(request)

                # Verify wrapper is entered and exited
                mock_conn_default.execute_wrapper.assert_called_once()

                # Verify content was modified
                self.assertIn(b"<div>Mock Panel</div>", res.content)
                self.assertIn(b"</body>", res.content)
                mock_stdout_write.assert_called()
            finally:
                if os.path.exists(temp_path):
                    os.remove(temp_path)

    @patch("django_orm_analyzer.middleware.connections")
    def test_middleware_no_queries(self, mock_connections: Any) -> None:
        """Test middleware returns response unchanged with no queries."""
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", True):
            mock_conn_default = MagicMock()
            mock_conn_default.settings_dict = {
                "ENGINE": "django.db.backends.sqlite3"
            }
            mock_connections.__iter__.return_value = ["default"]
            mock_connections.__getitem__.return_value = mock_conn_default

            get_response = MagicMock(return_value="response")
            middleware = ORMAnalyzerMiddleware(get_response)

            request = MagicMock()
            request.path = "/users/"

            res = middleware(request)
            self.assertEqual(res, "response")

    @patch("django_orm_analyzer.middleware.connections")
    @patch(
        "django_orm_analyzer.middleware.render_to_string",
        side_effect=ValueError("Render failed"),
    )
    @patch("sys.stdout.write")
    @patch("sys.stderr.write")
    def test_middleware_render_template_error(
        self,
        mock_stderr_write: Any,
        mock_stdout_write: Any,
        mock_render: Any,
        mock_connections: Any,
    ) -> None:
        """Test middleware handles render errors gracefully."""
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", True):
            mock_conn_default = MagicMock()
            mock_conn_default.settings_dict = {
                "ENGINE": "django.db.backends.sqlite3"
            }
            mock_connections.__iter__.return_value = ["default"]
            mock_connections.__getitem__.return_value = mock_conn_default

            def get_response_side_effect(req: Any) -> Any:
                """Append one query to the interceptor."""
                interceptor = mock_conn_default.execute_wrapper.call_args[0][0]
                interceptor.queries.append(
                    {
                        "sql": "SELECT * FROM auth_user",
                        "params": (),
                        "duration": 0.005,
                        "rows_fetched": 1,
                        "caller": None,
                        "connection": mock_conn_default,
                    }
                )
                response = MagicMock()
                response.get.return_value = "text/html"
                response.content = b"<html><body>Hello</body></html>"
                return response

            get_response = MagicMock(side_effect=get_response_side_effect)
            middleware = ORMAnalyzerMiddleware(get_response)

            request = MagicMock()
            request.path = "/users/"

            res = middleware(request)
            # Should gracefully handle the error and print to stderr
            mock_stderr_write.assert_called()
            self.assertEqual(res.content, b"<html><body>Hello</body></html>")

    @patch("django_orm_analyzer.middleware.connections")
    @patch("django_orm_analyzer.middleware.render_to_string")
    @patch("sys.stdout.write")
    def test_middleware_with_warnings_only_and_no_pygments(
        self, mock_stdout_write: Any, mock_render: Any, mock_connections: Any
    ) -> None:
        """Test middleware stdout output without pygments installed."""
        with patch.object(settings, "DJANGO_ORM_ANALYZER_ENABLED", True):
            mock_conn_default = MagicMock()
            mock_conn_default.settings_dict = {
                "ENGINE": "django.db.backends.sqlite3"
            }
            mock_connections.__iter__.return_value = ["default"]
            mock_connections.__getitem__.return_value = mock_conn_default

            def get_response_side_effect(req: Any) -> Any:
                """Append a large result query with no N+1/table scan."""
                interceptor = mock_conn_default.execute_wrapper.call_args[0][0]
                # Large row count to trigger a general warning,
                # but no N+1 or Table Scans
                interceptor.queries.append(
                    {
                        "sql": "SELECT * FROM auth_user LIMIT 500",
                        "params": (),
                        "duration": 0.005,
                        "rows_fetched": 200,
                        "caller": None,
                        "connection": mock_conn_default,
                    }
                )
                response = MagicMock()
                response.get.return_value = "text/plain"
                return response

            get_response = MagicMock(side_effect=get_response_side_effect)
            middleware = ORMAnalyzerMiddleware(get_response)

            request = MagicMock()
            request.path = "/users/"

            # Patch __import__ to raise ImportError for pygments
            import builtins

            original_import = builtins.__import__

            def mock_import(name: str, *args: Any, **kwargs: Any) -> Any:
                """Raise ImportError when importing pygments."""
                if name == "pygments":
                    raise ImportError("mocked import error")
                return original_import(name, *args, **kwargs)

            with patch("builtins.__import__", side_effect=mock_import):
                middleware(request)
                mock_stdout_write.assert_called()


if __name__ == "__main__":
    unittest.main()
