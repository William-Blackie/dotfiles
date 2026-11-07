# Django ORM analyzer

A local Neovim plugin that compiles Django QuerySets and displays SQL, `EXPLAIN`
output, and diagnostics. It runs against the project database; selected QuerySet
methods execute against a real Django QuerySet.

## Requirements

- Neovim 0.10 or newer.
- Python with the project's Django dependencies and access to its database.
- Docker for container mode.

The dotfiles load the plugin through `lua/plugins/django-orm-analyzer.lua`.

## Use

Press `<leader>oa` in normal mode to analyze the enclosing Python function, or
in visual mode to analyze a selection. The command is `:DjangoORMAnalyze`.
Simple expressions such as `User.objects.filter(is_active=True)` also work.

The parser finds `manage.py` by searching upward, then downward for nested
projects. QuerySet class names help infer the model when analyzing a method.

## Configuration

```lua
require("django-orm-analyzer").setup({
  python_cmd = "python3",
  keymaps = { analyze = "<leader>oa" }, -- false disables the mapping
  virtual_text = { enabled = true, prefix = " ➔ " },
  diagnostics = { enabled = true },
  window = { border = "rounded", width = 0.75, height = 0.7 },
})
```

Set `python_cmd` to the project's interpreter when it is not on PATH. The full
option types and defaults are in [init.lua](init.lua).

For a standalone lazy.nvim installation:

```lua
{
  dir = vim.fn.stdpath("config") .. "/lua/django-orm-analyzer",
  name = "django-orm-analyzer",
  lazy = false,
  opts = {},
}
```

## Docker

The dotfiles read these project environment variables:

```sh
export DJANGO_ORM_ANALYZER_DOCKER_CONTAINER=django-app
export DJANGO_ORM_ANALYZER_DOCKER_PROJECT_ROOT=/app
```

For standalone use, pass `docker_container` and `docker_project_root` to
`setup()`. The container must already have the dependencies and database access.

Each analysis copies `django_parser.py` and `django_orm_analyzer/` into
`/tmp/.django_orm_analyzer_plugin` in the container, then runs the parser there.
It sets `DJANGO_ORM_ANALYZER_SKIP_VENV=1` to avoid importing mounted host
packages.

## Troubleshooting

- Missing command or mapping: check that `setup()` ran.
- Django initialization failure: check the interpreter, project root, and
  settings module. For nested container projects, set `docker_project_root`.
- Missing `EXPLAIN`: check database connectivity and migrations. SQL can still
  be compiled when its referenced tables do not exist.
- Host packages imported in Docker: set `DJANGO_ORM_ANALYZER_SKIP_VENV=1` when
  invoking the parser manually.
