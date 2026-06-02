"""CLI parser tools for booting Django and parsing query inputs."""

import ast
import contextlib
import io
import json
import logging
import os
import re
import sys
import textwrap
import traceback
from typing import Any


def find_project_and_venv(
    start_dir: str,
) -> tuple[str | None, str | None]:
    """Search for manage.py and active virtualenv.

    Prefer walking upwards from the current file. If that fails, search
    downward from the supplied directory so monorepos that keep Django in a
    nested folder still resolve to the actual Django project root.
    """

    def find_venv(project_root: str) -> str | None:
        venv_paths = [
            os.path.join(project_root, ".venv"),
            os.path.join(project_root, "venv"),
            os.path.join(project_root, "env"),
        ]
        for vp in venv_paths:
            if os.path.exists(vp) and os.path.isdir(vp):
                return vp
        return None

    curr = os.path.abspath(start_dir)
    while curr != os.path.dirname(curr):
        manage_py = os.path.join(curr, "manage.py")
        if os.path.exists(manage_py):
            return curr, find_venv(curr)
        curr = os.path.dirname(curr)

    for root, dirs, files in os.walk(os.path.abspath(start_dir)):
        dirs[:] = [
            d
            for d in dirs
            if d
            not in {
                ".git",
                ".mypy_cache",
                ".pytest_cache",
                ".ruff_cache",
                ".venv",
                "__pycache__",
                "build",
                "dist",
                "node_modules",
                "venv",
            }
        ]
        if "manage.py" in files:
            return root, find_venv(root)
    return None, None


def get_settings_module(project_dir: str) -> str | None:
    """Parse manage.py to extract DJANGO_SETTINGS_MODULE."""
    manage_py = os.path.join(project_dir, "manage.py")
    if not os.path.exists(manage_py):
        return None
    try:
        with open(manage_py, "r", encoding="utf-8") as f:
            content = f.read()
        match = re.search(
            r"['\"]DJANGO_SETTINGS_MODULE['\"]"
            r"\s*,\s*['\"]([^'\"]+)['\"]",
            content,
        )
        if match:
            return match.group(1)
        match_alt = re.search(
            r"os\.environ\[['\"]DJANGO_SETTINGS_MODULE['\"]\]"
            r"\s*=\s*['\"]([^'\"]+)['\"]",
            content,
        )
        if match_alt:
            return match_alt.group(1)
    except Exception:
        pass
    return None


def load_dotenv(project_dir: str) -> None:
    """Search and load environment variables from local .env files."""
    env_paths = [
        os.path.join(project_dir, ".env"),
        os.path.join(project_dir, "build", ".env"),
        os.path.join(os.path.dirname(project_dir), ".env"),
    ]
    for path in env_paths:
        if os.path.exists(path) and os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        if "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip("'\"")
                            os.environ.setdefault(k, v)
            except Exception:
                pass


def robust_dedent(query_str: str | None) -> str:
    """Strip leading/trailing blank lines and wrap multiline expressions.

    Wraps the expression in parentheses to avoid syntax/indentation
    errors on evaluation.
    """
    if not query_str:
        return ""
    query_str = query_str.strip()
    lines = query_str.splitlines()
    if not lines:
        return ""

    first_line = lines[0].strip()
    if len(lines) == 1:
        return first_line

    remaining_text = "\n".join(lines[1:])
    dedented_remaining = textwrap.dedent(remaining_text)

    combined = first_line + "\n" + dedented_remaining
    if "\n" in combined and not (
        combined.startswith("(") and combined.endswith(")")
    ):
        combined = f"({combined})"

    return combined


# ---------------------------------------------------------------------------
# QuerySet method/class detection helpers
# ---------------------------------------------------------------------------


def _is_method_definition(query_str: str) -> bool:
    """Return True if the string looks like a function/method definition."""
    stripped = query_str.strip()
    return stripped.startswith("def ")


def _is_class_definition(query_str: str) -> bool:
    """Return True if the string looks like a class definition."""
    stripped = query_str.strip()
    return stripped.startswith("class ")


# ---------------------------------------------------------------------------
# AST-based method body extraction
# ---------------------------------------------------------------------------


def _find_first_method(source: str) -> ast.FunctionDef | None:
    """Return the first FunctionDef node found in the parsed source.

    Searches top-level definitions first, then inside ClassDef bodies,
    so that a selected class with one method resolves correctly.
    """
    try:
        tree = ast.parse(textwrap.dedent(source))
    except SyntaxError:
        return None

    # First pass: top-level functions
    for node in tree.body:
        if isinstance(node, ast.FunctionDef):
            return node

    # Second pass: methods inside a class — prefer the last one that
    # looks like a QuerySet method (returns self.something)
    qs_indicators = {
        "self.filter",
        "self.exclude",
        "self.annotate",
        "self.values",
        "self.all",
        "self.none",
        "self.select_related",
        "self.prefetch_related",
        "self.order_by",
    }
    best: ast.FunctionDef | None = None
    for node in tree.body:
        if isinstance(node, ast.ClassDef):
            for child in node.body:
                if not isinstance(child, ast.FunctionDef):
                    continue
                # Prefer methods with a QuerySet-ish return
                src_fragment = ast.unparse(child)
                if any(ind in src_fragment for ind in qs_indicators):
                    best = child
                elif best is None:
                    best = child
    return best


def _extract_method_body_text(source: str) -> str | None:
    """Extract and dedent the body of the first method in *source*.

    Skips leading docstrings.  Returns the body as a plain string
    ready for ``exec()``, or ``None`` if no method is found.
    """
    func_def = _find_first_method(source)
    if func_def is None:
        return None

    body = func_def.body
    if not body:
        return None

    # Skip leading docstring node
    start_idx = 0
    if (
        isinstance(body[0], ast.Expr)
        and isinstance(body[0].value, ast.Constant)
        and isinstance(body[0].value.value, str)
    ):
        start_idx = 1

    if start_idx >= len(body):
        return None  # Body was only a docstring

    # Reconstruct the body lines from the original source so that
    # comments and formatting are preserved.
    source_lines = textwrap.dedent(source).splitlines()
    # ast lineno is 1-indexed relative to the dedented source
    first_body_line = body[start_idx].lineno - 1  # 0-indexed
    body_lines = source_lines[first_body_line:]
    body_text = textwrap.dedent("\n".join(body_lines)).strip()

    return body_text or None


def _rewrite_return_as_assignment(body_text: str) -> str:
    """Rewrite the last top-level ``return`` as ``__orm_result__ = ...``.

    Uses AST to locate the return statement precisely so that
    ``return`` keywords inside nested functions/comprehensions are
    left alone.
    """
    try:
        tree = ast.parse(body_text)
    except SyntaxError:
        # Fall back to simple regex replacement of the last return
        return re.sub(
            r"(?m)^(\s*)return\s+",
            r"\1__orm_result__ = ",
            body_text,
        )

    # Find the last top-level Return node
    last_return: ast.Return | None = None
    for node in tree.body:
        if isinstance(node, ast.Return):
            last_return = node

    if last_return is None:
        return body_text  # No top-level return — leave as-is

    lines = body_text.splitlines()
    # lineno is 1-indexed
    ret_line_idx = last_return.lineno - 1
    # Replace "return" keyword on that line only
    lines[ret_line_idx] = re.sub(
        r"\breturn\b", "__orm_result__ =", lines[ret_line_idx], count=1
    )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Model / self binding
# ---------------------------------------------------------------------------


def _infer_self_queryset(source: str, context: dict[str, Any]) -> Any:
    """Return a real QuerySet to bind to ``self`` for method execution.

    Heuristic order:
    1. If the class name is ``FooQuerySet``, look for a model ``Foo``.
    2. If the class name is ``FooManager``, look for model ``Foo``.
    3. Fall back to the first available model's default queryset.
    """
    from django.apps import apps

    all_models = list(apps.get_models())
    if not all_models:
        raise ValueError(
            "No Django models are loaded — "
            "cannot bind `self` for method execution."
        )

    # Try to infer from class name
    class_match = re.search(r"class\s+(\w+)", source)
    if class_match:
        class_name = class_match.group(1)
        for suffix in ("QuerySet", "Manager"):
            if class_name.endswith(suffix):
                model_name = class_name[: -len(suffix)]
                for model in all_models:
                    if model.__name__ == model_name:
                        return model._default_manager.all()

    # Try method name convention e.g. def get_sessions_queryset
    func_def = _find_first_method(source)
    if func_def:
        method_name = func_def.name
        for model in all_models:
            if model.__name__.lower() in method_name.lower():
                return model._default_manager.all()

    # Final fallback
    return all_models[0]._default_manager.all()


# ---------------------------------------------------------------------------
# exec()-based method body execution
# ---------------------------------------------------------------------------


def _execute_method_body(
    source: str,
    base_context: dict[str, Any],
) -> Any:
    """Execute a method/class body and return the QuerySet it produces.

    Steps:
    1. Extract the method body (skipping ``def`` header and docstring).
    2. Infer an appropriate model queryset to bind as ``self``.
    3. Rewrite the ``return`` statement as ``__orm_result__ = ...``.
    4. ``exec()`` the rewritten body in an enriched context.
    5. Return ``context['__orm_result__']``.

    Raises:
        ValueError: If no method body or return value is found.
    """
    body_text = _extract_method_body_text(source)
    if not body_text:
        raise ValueError(
            "Could not extract a method body from the selection. "
            "Ensure you have selected a complete method or class "
            "definition containing a return statement."
        )

    self_qs = _infer_self_queryset(source, base_context)

    rewritten = _rewrite_return_as_assignment(body_text)

    exec_context: dict[str, Any] = dict(base_context)
    exec_context["self"] = self_qs
    exec_context["__orm_result__"] = None

    try:
        exec(rewritten, exec_context)  # noqa: S102
    except Exception as exc:
        raise ValueError(
            f"Failed to execute method body:\n{rewritten}\nError: {exc}"
        ) from exc

    result = exec_context.get("__orm_result__")
    if result is None:
        raise ValueError(
            "Method body executed but did not produce a QuerySet. "
            "Ensure the method contains a ``return`` statement "
            "that yields a QuerySet (e.g. ``return self.annotate(...)``)."
        )
    return result


# ---------------------------------------------------------------------------
# Environment / Django boot
# ---------------------------------------------------------------------------


def _setup_environment(
    project_dir: str, proj_root: str, venv_path: str | None
) -> None:
    """Load .env file and set up system path adjustments."""
    load_dotenv(project_dir)

    if proj_root not in sys.path:
        sys.path.insert(0, proj_root)

    if os.environ.get("DJANGO_ORM_ANALYZER_SKIP_VENV"):
        return

    if venv_path:
        site_packages = None
        for folder in ["lib", "lib64"]:
            lib_dir = os.path.join(venv_path, folder)
            if os.path.exists(lib_dir):
                for pyver in os.listdir(lib_dir):
                    sp = os.path.join(lib_dir, pyver, "site-packages")
                    if os.path.exists(sp):
                        site_packages = sp
                        break
        if site_packages and site_packages not in sys.path:
            sys.path.insert(0, site_packages)


def _run_django_setup(proj_root: str) -> None:
    """Find settings, configure environment, and run django.setup()."""
    settings_module = get_settings_module(proj_root)
    if not settings_module:
        for root, _dirs, files in os.walk(proj_root):
            if "settings.py" in files:
                rel = os.path.relpath(root, proj_root)
                if rel != ".":
                    settings_module = f"{rel.replace(os.sep, '.')}.settings"
                    break

    if not settings_module:
        settings_module = "config.settings"

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", settings_module)

    logging.disable(logging.CRITICAL)

    try:
        import django

        f_stdout = io.StringIO()
        f_stderr = io.StringIO()
        with (
            contextlib.redirect_stdout(f_stdout),
            contextlib.redirect_stderr(f_stderr),
        ):
            django.setup()
    except Exception as e:
        raise RuntimeError(
            f"Failed to initialize Django. Is settings configured? Error: {e}"
        ) from e


def _build_evaluation_context() -> dict[str, Any]:
    """Load Django models and common functions/constants into a context."""
    import importlib

    from django.apps import apps
    from django.db import models
    from django.db.models import (
        Avg,
        Case,
        Count,
        ExpressionWrapper,
        F,
        Max,
        Min,
        OuterRef,
        Prefetch,
        Q,
        Subquery,
        Sum,
        Value,
        When,
    )
    from django.db.models.functions import Coalesce

    context: dict[str, Any] = {
        "models": models,
        "apps": apps,
        "Q": Q,
        "F": F,
        "Count": Count,
        "Sum": Sum,
        "Avg": Avg,
        "Max": Max,
        "Min": Min,
        "Prefetch": Prefetch,
        "Case": Case,
        "When": When,
        "Value": Value,
        "Subquery": Subquery,
        "OuterRef": OuterRef,
        "ExpressionWrapper": ExpressionWrapper,
        "Coalesce": Coalesce,
    }

    # Register all loaded models by name
    for model in apps.get_models():
        context[model.__name__] = model

    # Eagerly import enums/constants from every installed app's
    # ``enums`` and ``constants`` modules so method bodies that
    # reference e.g. ``SessionStatus`` resolve without extra imports.
    for app_config in apps.get_app_configs():
        for module_suffix in ("enums", "constants", "choices"):
            module_name = f"{app_config.name}.{module_suffix}"
            try:
                mod = importlib.import_module(module_name)
                for attr in dir(mod):
                    if not attr.startswith("_") and attr not in context:
                        context[attr] = getattr(mod, attr)
            except ImportError:
                pass

    return context


def bootstrap_django(project_dir: str) -> dict[str, Any]:
    """Safely boot Django and build a context namespace.

    Includes all loaded models, QuerySet functions, and project enums.
    """
    proj_root, venv_path = find_project_and_venv(project_dir)
    if not proj_root:
        proj_root = project_dir
    _setup_environment(project_dir, proj_root, venv_path)
    _run_django_setup(proj_root)
    return _build_evaluation_context()


# ---------------------------------------------------------------------------
# Evaluation / analysis
# ---------------------------------------------------------------------------


def _to_queryset(evaluated: Any) -> Any:
    """Coerce an evaluated value to a QuerySet, or raise ValueError."""
    import django.db.models.query
    from django.db import models as dj_models

    if isinstance(evaluated, django.db.models.query.QuerySet):
        return evaluated
    if hasattr(evaluated, "query"):
        return evaluated
    if isinstance(evaluated, dj_models.Model):
        return evaluated.__class__.objects.filter(pk=evaluated.pk)
    raise ValueError(
        f"Evaluated expression is a {type(evaluated).__name__}, "
        "not a QuerySet. Please highlight a QuerySet expression "
        "(e.g. .filter() or .all() rather than immediate execution "
        "like .count() or .get())."
    )


def evaluate_and_analyze(
    query_str: str, context: dict[str, Any]
) -> dict[str, Any]:
    """Evaluate *query_str* and return a complexity analysis report.

    Handles three input forms:
    - Plain QuerySet expression: ``User.objects.filter(is_active=True)``
    - Method definition: ``def with_counts(self): ...``
    - Class definition: ``class FooQuerySet(models.QuerySet): ...``

    For method/class definitions, the **entire method body** is
    ``exec()``'d (not just the return expression), so intermediate
    variables like ``subquery`` and runtime imports like
    ``apps.get_model(...)`` are resolved correctly.
    """
    from django.db import connections, transaction

    from django_orm_analyzer.analyzer import QueryAnalyzer

    connection = connections["default"]

    with transaction.atomic(using="default"):
        if _is_class_definition(query_str) or _is_method_definition(query_str):
            # exec() path — execute the full method body
            queryset = _execute_method_body(query_str, context)
        else:
            # eval() path — plain expression
            expr = robust_dedent(query_str)
            try:
                evaluated = eval(expr, {}, context)  # noqa: S307
            except Exception as exc:
                raise ValueError(
                    f"Failed to evaluate expression:\n  {expr}\nError: {exc}"
                ) from exc
            queryset = _to_queryset(evaluated)

        compiler = queryset.query.get_compiler(using=queryset.db)
        sql, params = compiler.as_sql()

        raw_query = {
            "sql": sql,
            "params": params,
            "duration": 0.0,
            "rows_fetched": 0,
            "caller": None,
            "connection": connection,
        }

        analyzer = QueryAnalyzer([raw_query])
        analyzed_queries, _summary = analyzer.analyze()
        analyzed = analyzed_queries[0]

        transaction.set_rollback(True)

    return {
        "success": True,
        "sql": sql,
        "params": str(params),
        "complexity": analyzed["complexity"],
        "warnings": analyzed["warnings"],
        "suggestions": analyzed["suggestions"],
        "plan": analyzed["plan"],
        "engine": analyzed["engine"],
    }


def run_cli() -> None:
    """CLI command entry point."""
    if len(sys.argv) < 3:
        print(
            json.dumps(
                {
                    "success": False,
                    "error": (
                        "Usage: python django_parser.py "
                        "<project_dir> <query_str>"
                    ),
                }
            ),
            flush=True,
        )
        sys.exit(1)

    project_dir = os.path.abspath(sys.argv[1])
    query_str = sys.argv[2]

    try:
        context = bootstrap_django(project_dir)
        report = evaluate_and_analyze(query_str, context)
        print(json.dumps(report), flush=True)
    except Exception as e:
        print(
            json.dumps(
                {
                    "success": False,
                    "error": f"Evaluation error: {e}",
                    "traceback": traceback.format_exc(),
                }
            ),
            flush=True,
        )
