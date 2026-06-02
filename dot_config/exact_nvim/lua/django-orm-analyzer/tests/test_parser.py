"""Tests for the django_orm_analyzer parser and CLI entrypoint."""

import os
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

import django

# Adjust path to import from parent directory
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import django_parser as cli_entrypoint
from django_orm_analyzer import parser as django_parser


class TestParser(unittest.TestCase):
    """Tests for parser utility functions and CLI entrypoint."""

    def test_robust_dedent_empty(self) -> None:
        """Test that empty and None inputs return empty string."""
        self.assertEqual(django_parser.robust_dedent(""), "")
        self.assertEqual(django_parser.robust_dedent(None), "")

    def test_robust_dedent_single_line(self) -> None:
        """Test that single-line strings are stripped."""
        self.assertEqual(
            django_parser.robust_dedent("  User.objects.all()  "),
            "User.objects.all()",
        )

    def test_robust_dedent_multi_line_matched(self) -> None:
        """Test dedent of multi-line string with consistent indentation."""
        query = """
            User.objects
            .filter(is_active=True)
            .all()
        """
        expected = "(User.objects\n.filter(is_active=True)\n.all())"
        self.assertEqual(django_parser.robust_dedent(query), expected)

    def test_robust_dedent_multi_line_mismatched(self) -> None:
        """Test dedent of multi-line string with mismatched indentation."""
        query = (
            "             User.objects\n"
            "            .filter(id=1)\n"
            "            .all()"
        )
        expected = "(User.objects\n.filter(id=1)\n.all())"
        self.assertEqual(django_parser.robust_dedent(query), expected)

    def test_robust_dedent_already_parenthesized(self) -> None:
        """Test that already-parenthesized strings are not double-wrapped."""
        query = "(User.objects\n.filter(id=1))"
        self.assertEqual(
            django_parser.robust_dedent(query),
            "(User.objects\n.filter(id=1))",
        )

    def test_robust_dedent_newlines(self) -> None:
        """Test that strings with only newlines return empty string."""
        self.assertEqual(django_parser.robust_dedent("\n\n"), "")

    def test_find_project_and_venv_none(self) -> None:
        """Test that None is returned when no project is found."""
        with tempfile.TemporaryDirectory() as temp_dir:
            proj, venv = django_parser.find_project_and_venv(temp_dir)
            self.assertIsNone(proj)
            self.assertIsNone(venv)

    def test_find_project_and_venv_exists(self) -> None:
        """Test project and venv paths are returned when found."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create dummy manage.py
            with open(os.path.join(temp_dir, "manage.py"), "w") as f:
                f.write("# dummy")
            # Create dummy venv folder
            os.mkdir(os.path.join(temp_dir, ".venv"))

            proj, venv = django_parser.find_project_and_venv(temp_dir)
            self.assertEqual(proj, temp_dir)
            self.assertEqual(venv, os.path.join(temp_dir, ".venv"))

    def test_find_project_and_venv_nested_project(self) -> None:
        """Test nested Django roots are found in monorepos."""
        with tempfile.TemporaryDirectory() as temp_dir:
            project_dir = os.path.join(temp_dir, "django")
            os.mkdir(project_dir)
            with open(os.path.join(project_dir, "manage.py"), "w") as f:
                f.write("# dummy")
            os.mkdir(os.path.join(project_dir, ".venv"))

            proj, venv = django_parser.find_project_and_venv(temp_dir)
            self.assertEqual(proj, project_dir)
            self.assertEqual(venv, os.path.join(project_dir, ".venv"))

    def test_get_settings_module_parse(self) -> None:
        """Test settings module is parsed from manage.py setdefault."""
        with tempfile.TemporaryDirectory() as temp_dir:
            manage_py = os.path.join(temp_dir, "manage.py")
            with open(manage_py, "w") as f:
                f.write(
                    "os.environ.setdefault("
                    "'DJANGO_SETTINGS_MODULE', 'myconfig.settings')"
                )
            settings = django_parser.get_settings_module(temp_dir)
            self.assertEqual(settings, "myconfig.settings")

    def test_get_settings_module_parse_alt(self) -> None:
        """Test settings module is parsed from manage.py assignment."""
        with tempfile.TemporaryDirectory() as temp_dir:
            manage_py = os.path.join(temp_dir, "manage.py")
            with open(manage_py, "w") as f:
                f.write(
                    "os.environ['DJANGO_SETTINGS_MODULE']"
                    " = 'myconfig.settings_alt'"
                )
            settings = django_parser.get_settings_module(temp_dir)
            self.assertEqual(settings, "myconfig.settings_alt")

    def test_get_settings_module_none(self) -> None:
        """Test None is returned when path does not exist."""
        self.assertIsNone(django_parser.get_settings_module("/nonexistent"))

    def test_get_settings_module_exception(self) -> None:
        """Test None is returned on IOError reading manage.py."""
        with patch("builtins.open", side_effect=IOError("read error")):
            self.assertIsNone(django_parser.get_settings_module("/some/path"))

    def test_load_dotenv(self) -> None:
        """Test that .env file variables are loaded into environment."""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create build folder and .env
            os.mkdir(os.path.join(temp_dir, "build"))
            env_file = os.path.join(temp_dir, "build", ".env")
            with open(env_file, "w") as f:
                f.write(
                    "# comment\nTEST_ENV_VAR=my_value\n\nEMPTY_VAR = 'spaced'\n"
                )

            django_parser.load_dotenv(temp_dir)
            self.assertEqual(os.environ.get("TEST_ENV_VAR"), "my_value")
            self.assertEqual(os.environ.get("EMPTY_VAR"), "spaced")

    def test_load_dotenv_exception(self) -> None:
        """Test that load_dotenv handles IOErrors gracefully."""
        with tempfile.TemporaryDirectory() as temp_dir:
            os.mkdir(os.path.join(temp_dir, ".env"))
            django_parser.load_dotenv(temp_dir)

    def test_cli_entrypoint_wrapper(self) -> None:
        """Test that the CLI entrypoint module exposes run_cli."""
        self.assertTrue(hasattr(cli_entrypoint, "run_cli"))

    def test_main_usage_error(self) -> None:
        """Test that missing CLI arguments exit with code 1."""
        with (
            patch("sys.argv", ["django_parser.py"]),
            patch("sys.exit", side_effect=SystemExit) as mock_exit,
            patch("builtins.print"),
        ):
            with self.assertRaises(SystemExit):
                django_parser.run_cli()
            mock_exit.assert_called_once_with(1)

    def test_main_django_boot_failure(self) -> None:
        """Test that Django boot failure returns error JSON."""
        with tempfile.TemporaryDirectory() as temp_dir:
            with (
                patch(
                    "sys.argv",
                    [
                        "django_parser.py",
                        temp_dir,
                        "TestModel.objects.all()",
                    ],
                ),
                patch(
                    "django_orm_analyzer.parser.find_project_and_venv",
                    return_value=(temp_dir, None),
                ),
                patch(
                    "django_orm_analyzer.parser.get_settings_module",
                    return_value="myconfig.settings",
                ),
                patch(
                    "django.setup",
                    side_effect=ValueError("Boot failure"),
                ),
                patch("builtins.print") as mock_print,
            ):
                django_parser.run_cli()
                called_args = mock_print.call_args[0][0]
                import json

                result = json.loads(called_args)
                self.assertFalse(result["success"])
                self.assertIn("Failed to initialize Django", result["error"])

    def test_main_non_queryset_error(self) -> None:
        """Test that non-QuerySet eval result returns error JSON."""
        with tempfile.TemporaryDirectory() as temp_dir:
            with (
                patch(
                    "sys.argv",
                    ["django_parser.py", temp_dir, "123"],
                ),
                patch(
                    "django_orm_analyzer.parser.find_project_and_venv",
                    return_value=(temp_dir, None),
                ),
                patch(
                    "django_orm_analyzer.parser.get_settings_module",
                    return_value="myconfig.settings",
                ),
                patch("django.setup"),
                patch("django.apps.apps.get_models", return_value=[]),
                patch("builtins.eval", return_value=123),
                patch("builtins.print") as mock_print,
            ):
                django_parser.run_cli()
                called_args = mock_print.call_args[0][0]
                import json

                result = json.loads(called_args)
                self.assertFalse(result["success"])
                self.assertIn("not a QuerySet", result["error"])

    def test_main_success(self) -> None:
        """Test that a successful QuerySet evaluation returns JSON."""
        with tempfile.TemporaryDirectory() as temp_dir:
            mock_model = MagicMock()
            mock_model.__name__ = "TestModel"

            mock_queryset = MagicMock()
            mock_queryset.db = "default"
            mock_compiler = MagicMock()
            mock_compiler.as_sql.return_value = (
                "SELECT * FROM test_model",
                (1,),
            )
            mock_queryset.query.get_compiler.return_value = mock_compiler

            mock_cursor = MagicMock()
            mock_cursor.fetchall.return_value = [("row",)]
            mock_conn = MagicMock()
            mock_conn.settings_dict = {"ENGINE": "sqlite3"}
            mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

            mock_analyzed = {
                "complexity": "O(1)",
                "warnings": [],
                "suggestions": ["tip"],
                "plan": [["plan"]],
                "engine": "sqlite3",
            }

            with (
                patch(
                    "sys.argv",
                    [
                        "django_parser.py",
                        temp_dir,
                        "TestModel.objects.all()",
                    ],
                ),
                patch(
                    "django_orm_analyzer.parser.find_project_and_venv",
                    return_value=(temp_dir, None),
                ),
                patch(
                    "django_orm_analyzer.parser.get_settings_module",
                    return_value="myconfig.settings",
                ),
                patch("django.setup"),
                patch(
                    "django.apps.apps.get_models",
                    return_value=[mock_model],
                ),
                patch("django.db.connections", {"default": mock_conn}),
                patch("django.db.transaction.atomic"),
                patch(
                    "django.db.transaction.set_rollback"
                ) as mock_set_rollback,
                patch("builtins.eval", return_value=mock_queryset) as mock_eval,
                patch(
                    "django_orm_analyzer.analyzer.QueryAnalyzer.analyze",
                    return_value=([mock_analyzed], {}),
                ),
                patch("builtins.print") as mock_print,
            ):
                django_parser.run_cli()

                mock_eval.assert_called_once()
                mock_set_rollback.assert_called_with(True)

                called_args = mock_print.call_args[0][0]
                import json

                result = json.loads(called_args)
                self.assertTrue(result["success"])
                self.assertEqual(result["sql"], "SELECT * FROM test_model")
                self.assertEqual(result["complexity"], "O(1)")

    @patch("builtins.print")
    def test_main_venv_packages_and_guess_settings(
        self, mock_print: MagicMock
    ) -> None:
        """Test venv site-packages addition and settings guessing."""
        with tempfile.TemporaryDirectory() as temp_dir:
            venv_dir = os.path.join(temp_dir, ".venv")
            sp_dir = os.path.join(
                venv_dir, "lib", "python3.12", "site-packages"
            )
            os.makedirs(sp_dir)

            with open(os.path.join(temp_dir, "manage.py"), "w") as f:
                f.write("# dummy")

            sub_dir = os.path.join(temp_dir, "myconfig")
            os.makedirs(sub_dir)
            with open(os.path.join(sub_dir, "settings.py"), "w") as f:
                f.write("# dummy settings")

            os.environ["REDIS_HOST"] = "redis"
            os.environ["DB_HOST"] = "postgres"

            with (
                patch(
                    "sys.argv",
                    ["django_parser.py", temp_dir, "123"],
                ),
                patch("django.setup"),
                patch("builtins.eval", return_value=123),
            ):
                django_parser.run_cli()

            # Host-override translation was removed — env vars are left as-is
            self.assertEqual(os.environ.get("REDIS_HOST"), "redis")
            self.assertEqual(os.environ.get("DB_HOST"), "postgres")

    def test_setup_environment_can_skip_venv(self) -> None:
        """Test Docker mode can avoid mounted host virtualenv packages."""
        with tempfile.TemporaryDirectory() as temp_dir:
            venv_dir = os.path.join(temp_dir, ".venv")
            site_packages = os.path.join(
                venv_dir, "lib", "python3.12", "site-packages"
            )
            os.makedirs(site_packages)

            original_path = list(sys.path)
            with patch.dict(os.environ, {"DJANGO_ORM_ANALYZER_SKIP_VENV": "1"}):
                try:
                    django_parser._setup_environment(
                        temp_dir, temp_dir, venv_dir
                    )
                    self.assertNotIn(site_packages, sys.path)
                finally:
                    sys.path[:] = original_path

    def test_main_model_evaluation(self) -> None:
        """Test CLI when eval returns a Model instance."""
        with tempfile.TemporaryDirectory() as temp_dir:

            class MockModel(django.db.models.Model):
                """A minimal mock Django model for testing."""

                class Meta:
                    """Meta options for MockModel."""

                    app_label = "test_app"

            mock_queryset = MagicMock()
            mock_compiler = MagicMock()
            mock_compiler.as_sql.return_value = (
                "SELECT * FROM mock_model WHERE id = 1",
                (1,),
            )
            mock_queryset.query.get_compiler.return_value = mock_compiler
            mock_queryset.db = "default"
            MockModel.objects = MagicMock()
            MockModel.objects.filter.return_value = mock_queryset
            mock_model_instance = MockModel()
            mock_model_instance.pk = 1

            mock_cursor = MagicMock()
            mock_cursor.fetchall.return_value = [("row",)]
            mock_conn = MagicMock()
            mock_conn.settings_dict = {"ENGINE": "sqlite3"}
            mock_conn.cursor.return_value.__enter__.return_value = mock_cursor

            mock_analyzed = {
                "complexity": "O(1)",
                "warnings": [],
                "suggestions": [],
                "plan": [["plan"]],
                "engine": "sqlite3",
            }

            with (
                patch(
                    "sys.argv",
                    ["django_parser.py", temp_dir, "instance"],
                ),
                patch(
                    "django_orm_analyzer.parser.find_project_and_venv",
                    return_value=(temp_dir, None),
                ),
                patch(
                    "django_orm_analyzer.parser.get_settings_module",
                    return_value="myconfig.settings",
                ),
                patch("django.setup"),
                patch("django.apps.apps.get_models", return_value=[]),
                patch("django.db.connections", {"default": mock_conn}),
                patch("django.db.transaction.atomic"),
                patch("django.db.transaction.set_rollback"),
                patch(
                    "builtins.eval",
                    return_value=mock_model_instance,
                ),
                patch(
                    "django_orm_analyzer.analyzer.QueryAnalyzer.analyze",
                    return_value=([mock_analyzed], {}),
                ),
                patch("builtins.print") as mock_print,
            ):
                django_parser.run_cli()
                called_args = mock_print.call_args[0][0]
                import json

                result = json.loads(called_args)
                self.assertTrue(
                    result["success"],
                    f"Error: {result.get('error')}\n"
                    f"Traceback: {result.get('traceback')}",
                )


class TestQuerySetMethodExtraction(unittest.TestCase):
    """Tests for method/class definition detection and exec() pipeline."""

    # ------------------------------------------------------------------
    # Detection helpers
    # ------------------------------------------------------------------

    def test_is_method_definition_true(self) -> None:
        """Test that a def block is recognised as a method definition."""
        self.assertTrue(
            django_parser._is_method_definition(
                "def with_session_counts(self):\n    return self.all()"
            )
        )

    def test_is_method_definition_false(self) -> None:
        """Test that a plain expression is not a method definition."""
        self.assertFalse(
            django_parser._is_method_definition(
                "User.objects.filter(is_active=True)"
            )
        )

    def test_is_class_definition_true(self) -> None:
        """Test that a class block is recognised as a class definition."""
        self.assertTrue(
            django_parser._is_class_definition(
                "class MyQuerySet(models.QuerySet):\n    pass"
            )
        )

    def test_is_class_definition_false(self) -> None:
        """Test that a plain expression is not a class definition."""
        self.assertFalse(
            django_parser._is_class_definition("User.objects.all()")
        )

    # ------------------------------------------------------------------
    # AST body extraction
    # ------------------------------------------------------------------

    def test_extract_body_simple_method(self) -> None:
        """Test body extraction from a simple one-liner method."""
        method = "def active(self):\n    return self.filter(is_active=True)\n"
        body = django_parser._extract_method_body_text(method)
        self.assertIsNotNone(body)
        assert body is not None
        self.assertIn("return self.filter", body)

    def test_extract_body_skips_docstring(self) -> None:
        """Test that docstrings are stripped from the extracted body."""
        method = (
            "def active(self):\n"
            '    """Return active users."""\n'
            "    return self.filter(is_active=True)\n"
        )
        body = django_parser._extract_method_body_text(method)
        self.assertIsNotNone(body)
        assert body is not None
        self.assertNotIn('"""', body)
        self.assertIn("return self.filter", body)

    def test_extract_body_with_intermediates(self) -> None:
        """Test body extraction when the method has intermediate variables."""
        method = (
            "def with_counts(self):\n"
            "    subquery = MyModel.objects.values('id')\n"
            "    return self.annotate(count=Count('pk'))\n"
        )
        body = django_parser._extract_method_body_text(method)
        self.assertIsNotNone(body)
        assert body is not None
        self.assertIn("subquery", body)
        self.assertIn("return self.annotate", body)

    def test_extract_body_from_class(self) -> None:
        """Test body extraction from a method inside a class definition."""
        cls_def = (
            "class FooQuerySet(models.QuerySet):\n"
            "    def active(self):\n"
            "        return self.filter(is_active=True)\n"
        )
        body = django_parser._extract_method_body_text(cls_def)
        self.assertIsNotNone(body)
        assert body is not None
        self.assertIn("self.filter", body)

    def test_extract_body_no_body_returns_none(self) -> None:
        """Test that a method with only a docstring returns None."""
        method = 'def foo(self):\n    """Nothing here."""\n'
        body = django_parser._extract_method_body_text(method)
        self.assertIsNone(body)

    def test_extract_body_no_method_returns_none(self) -> None:
        """Test that a non-definition string returns None."""
        body = django_parser._extract_method_body_text("User.objects.all()")
        self.assertIsNone(body)

    # ------------------------------------------------------------------
    # Return-to-assignment rewriting
    # ------------------------------------------------------------------

    def test_rewrite_return_simple(self) -> None:
        """Test that a top-level return is rewritten correctly."""
        body = "x = 1\nreturn self.filter(x=x)\n"
        rewritten = django_parser._rewrite_return_as_assignment(body)
        self.assertIn("__orm_result__ = self.filter", rewritten)
        self.assertNotIn("return", rewritten)

    def test_rewrite_return_multiline(self) -> None:
        """Test rewriting a return that spans multiple lines."""
        body = (
            "subquery = MyModel.objects.values('pk')\n"
            "return self.annotate(\n"
            "    count=Count('pk'),\n"
            ")\n"
        )
        rewritten = django_parser._rewrite_return_as_assignment(body)
        self.assertIn("__orm_result__ = self.annotate", rewritten)

    def test_rewrite_return_preserves_nested(self) -> None:
        """Test that return inside a nested function is not rewritten."""
        body = "def helper():\n    return 1\nreturn self.filter(x=helper())\n"
        rewritten = django_parser._rewrite_return_as_assignment(body)
        # Top-level return replaced, nested return preserved
        self.assertIn("__orm_result__ = self.filter", rewritten)
        self.assertIn("return 1", rewritten)

    # ------------------------------------------------------------------
    # Model inference
    # ------------------------------------------------------------------

    def test_infer_self_queryset_by_class_name(self) -> None:
        """Test model inference from FooQuerySet -> Foo convention."""
        from django.apps import apps

        mock_qs = MagicMock()
        mock_model = MagicMock()
        mock_model.__name__ = "SessionTemplate"
        mock_model._default_manager.all.return_value = mock_qs

        with patch.object(apps, "get_models", return_value=[mock_model]):
            source = "class SessionTemplateQuerySet(models.QuerySet):\n    pass"
            result = django_parser._infer_self_queryset(source, {})
            self.assertEqual(result, mock_qs)

    def test_infer_self_queryset_fallback(self) -> None:
        """Test model inference falls back to first model when no match."""
        from django.apps import apps

        mock_qs = MagicMock()
        mock_model = MagicMock()
        mock_model.__name__ = "UnrelatedModel"
        mock_model._default_manager.all.return_value = mock_qs

        with patch.object(apps, "get_models", return_value=[mock_model]):
            result = django_parser._infer_self_queryset(
                "class XQuerySet(models.QuerySet):\n    pass", {}
            )
            # Falls back to first model's queryset
            self.assertEqual(result, mock_qs)

    # ------------------------------------------------------------------
    # Full exec() pipeline
    # ------------------------------------------------------------------

    def test_execute_simple_method_body(self) -> None:
        """Test that a simple method body is exec()d and returns a QS."""
        from django.apps import apps

        mock_qs = MagicMock()
        mock_filtered = MagicMock()
        mock_qs.filter.return_value = mock_filtered

        mock_model = MagicMock()
        mock_model.__name__ = "Widget"
        mock_model._default_manager.all.return_value = mock_qs

        with patch.object(apps, "get_models", return_value=[mock_model]):
            method = (
                "def active(self):\n    return self.filter(is_active=True)\n"
            )
            result = django_parser._execute_method_body(method, {})
            self.assertEqual(result, mock_filtered)

    def test_execute_method_with_intermediates(self) -> None:
        """Test exec() pipeline when the body uses intermediate variables."""
        from django.apps import apps

        mock_qs = MagicMock()
        mock_annotated = MagicMock()
        mock_qs.annotate.return_value = mock_annotated

        mock_model = MagicMock()
        mock_model.__name__ = "Widget"
        mock_model._default_manager.all.return_value = mock_qs

        with patch.object(apps, "get_models", return_value=[mock_model]):
            method = (
                "def with_counts(self):\n"
                "    n = 42\n"
                "    return self.annotate(count=n)\n"
            )
            result = django_parser._execute_method_body(method, {})
            mock_qs.annotate.assert_called_once_with(count=42)
            self.assertEqual(result, mock_annotated)

    def test_execute_method_no_body_raises(self) -> None:
        """Test that a method with no body raises ValueError."""
        from django.apps import apps

        mock_model = MagicMock()
        mock_model.__name__ = "Widget"
        mock_model._default_manager.all.return_value = MagicMock()

        with patch.object(apps, "get_models", return_value=[mock_model]):
            with self.assertRaises(ValueError):
                django_parser._execute_method_body(
                    'def foo(self):\n    """Only docstring."""\n', {}
                )

    def test_execute_method_from_class_definition(self) -> None:
        """Test exec() pipeline from a full class definition."""
        from django.apps import apps

        mock_qs = MagicMock()
        mock_filtered = MagicMock()
        mock_qs.filter.return_value = mock_filtered

        mock_model = MagicMock()
        mock_model.__name__ = "Foo"
        mock_model._default_manager.all.return_value = mock_qs

        with patch.object(apps, "get_models", return_value=[mock_model]):
            cls_def = (
                "class FooQuerySet(models.QuerySet):\n"
                "    def active(self):\n"
                "        return self.filter(active=True)\n"
            )
            result = django_parser._execute_method_body(cls_def, {})
            self.assertEqual(result, mock_filtered)


if __name__ == "__main__":
    unittest.main()
