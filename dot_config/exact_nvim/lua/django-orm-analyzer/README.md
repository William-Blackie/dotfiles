# django-orm-analyzer.nvim

Analyze Django ORM queries from Neovim and show the compiled SQL, database
execution plan, complexity estimate, warnings, and suggestions in a floating
report.

The plugin supports plain QuerySet expressions, selected QuerySet methods, and
cursor-based analysis inside a Python method. For QuerySet methods, it executes
the method body against a real Django QuerySet and compiles the resulting query.

## Features

- Analyze the current QuerySet expression or selected Python block.
- Analyze the enclosing Python method from normal mode.
- Include QuerySet class context for model inference, such as
  `SessionTemplateQuerySet -> SessionTemplate`.
- Show compiled SQL and `EXPLAIN` output.
- Add virtual text and diagnostics for warnings.
- Run locally or inside a Docker container.
- Copy the Python parser package into Docker containers automatically.

## Requirements

- Neovim 0.10+
- Python with Django available for local mode
- Docker, when using `docker_container`
- A Django project with a discoverable `manage.py`

For Docker mode, the container should already have project dependencies and
access to the project database.

## Installation

### lazy.nvim

For a local plugin directory:

```lua
{
  dir = vim.fn.stdpath("config") .. "/lua/django-orm-analyzer",
  name = "django-orm-analyzer",
  lazy = false,
  config = function()
    require("django-orm-analyzer").setup()
  end,
}
```

With Docker defaults from environment variables:

```lua
{
  dir = vim.fn.stdpath("config") .. "/lua/django-orm-analyzer",
  name = "django-orm-analyzer",
  lazy = false,
  config = function()
    require("django-orm-analyzer").setup({
      docker_container = vim.env.DJANGO_ORM_ANALYZER_DOCKER_CONTAINER,
      docker_project_root = vim.env.DJANGO_ORM_ANALYZER_DOCKER_PROJECT_ROOT,
    })
  end,
}
```

Example shell configuration:

```sh
export DJANGO_ORM_ANALYZER_DOCKER_CONTAINER=django-app
export DJANGO_ORM_ANALYZER_DOCKER_PROJECT_ROOT=/www/mabyduck
```

## Usage

Use the default keymap:

```text
<leader>oa
```

Or run the command:

```vim
:DjangoORMAnalyze
```

Supported inputs:

```python
User.objects.filter(is_active=True)
```

```python
def with_counts(self):
    return self.annotate(num_sessions=Count("sessions"))
```

```python
class SessionTemplateQuerySet(models.QuerySet):
    def with_session_counts(self):
        ...
        return self.annotate(...)
```

In normal mode, the plugin analyzes the enclosing Python function if the cursor
is inside one. In visual mode, it analyzes the selected text.

## Configuration

Defaults:

```lua
require("django-orm-analyzer").setup({
  python_cmd = "python3",
  docker_container = nil,
  docker_project_root = nil,
  keymaps = {
    analyze = "<leader>oa",
  },
  virtual_text = {
    enabled = true,
    prefix = " ➔ ",
  },
  diagnostics = {
    enabled = true,
  },
  window = {
    border = "rounded",
    width = 0.75,
    height = 0.7,
  },
})
```

### Options

| Option                 | Type            | Default        | Description                                                                                        |
| ---------------------- | --------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| `python_cmd`           | `string`        | `"python3"`    | Python executable used in local mode. Ignored when `docker_container` is set.                      |
| `docker_container`     | `string?`       | `nil`          | Container name or ID used for analysis. Enables Docker mode.                                       |
| `docker_project_root`  | `string?`       | `nil`          | Project root path inside the container. Defaults to the locally detected project root.             |
| `keymaps.analyze`      | `string\|false` | `"<leader>oa"` | Normal/visual keymap for analysis. Set to `false` to disable automatic keymap registration.        |
| `virtual_text.enabled` | `boolean`       | `true`         | Show complexity as virtual text beside the analyzed line.                                          |
| `virtual_text.prefix`  | `string`        | `" ➔ "`        | Prefix used before virtual text.                                                                   |
| `diagnostics.enabled`  | `boolean`       | `true`         | Publish warnings as Neovim diagnostics.                                                            |
| `window.border`        | `string`        | `"rounded"`    | Floating report border. Common values: `"single"`, `"double"`, `"rounded"`, `"solid"`, `"shadow"`. |
| `window.width`         | `number`        | `0.75`         | Floating report width as a fraction of editor columns.                                             |
| `window.height`        | `number`        | `0.7`          | Floating report height as a fraction of editor lines.                                              |

## Local Mode

Local mode runs the parser on your machine:

```lua
require("django-orm-analyzer").setup({
  python_cmd = "/path/to/project/.venv/bin/python",
})
```

The parser searches for `manage.py` upward from the current file. If none is
found, it searches downward from the current root to support monorepos with a
nested Django app.

## Docker Mode

Docker mode runs the parser inside a container:

```lua
require("django-orm-analyzer").setup({
  docker_container = "django-app",
  docker_project_root = "/www/project/django",
})
```

When Docker mode is enabled, the plugin:

1. Copies `django_parser.py` and `django_orm_analyzer/` to
   `/tmp/.django_orm_analyzer_plugin` in the container.
2. Runs `python3 /tmp/.django_orm_analyzer_plugin/django_parser.py`.
3. Sets `DJANGO_ORM_ANALYZER_SKIP_VENV=1` so mounted host virtualenv packages
   are not imported inside the container.

Use Docker mode when project service names such as `postgres` or `redis` only
resolve inside Docker.

## Troubleshooting

### No keymap appears

Make sure `setup()` runs during startup:

```lua
require("django-orm-analyzer").setup()
```

Check the command exists:

```vim
:DjangoORMAnalyze
```

### Django cannot initialize

Confirm the parser can find the right project root and settings module. In
monorepos, set `docker_project_root` or open a file under the Django project.

### `EXPLAIN` is missing

The database must be reachable and migrated. If the compiled SQL references a
table that does not exist, the report can still show SQL but cannot show a plan.

### Docker imports host packages

Docker mode sets `DJANGO_ORM_ANALYZER_SKIP_VENV=1`. If running the parser
manually in a container, set that environment variable yourself.

## Commands

| Command             | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `:DjangoORMAnalyze` | Analyze the current line, enclosing function, or visual selection. |

## Highlights

| Highlight                  | Used for                    |
| -------------------------- | --------------------------- |
| `DjangoORMVirtualTextOpt`  | Low-risk virtual text.      |
| `DjangoORMVirtualTextWarn` | Warning virtual text.       |
| `DjangoORMVirtualTextCrit` | Critical virtual text.      |
| `DjangoORMBg`              | Floating report background. |
| `DjangoORMBorder`          | Floating report border.     |
