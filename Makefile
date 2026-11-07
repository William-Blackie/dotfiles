SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PRETTIER_GLOBS := "**/*.{md,json,yml,yaml}"
MARKDOWN_FILES := $(shell git ls-files '*.md')
SHELL_FILES := $(shell git ls-files '*.sh' 'dot_zshenv' 'dot_config/exact_borders/executable_bordersrc' | while IFS= read -r f; do [ -f "$$f" ] && printf '%s\n' "$$f"; done)
SHELLCHECK_TEMPLATE_FILES := .chezmoiscripts/run_after_85-build-nvim-env.sh.tmpl .chezmoiscripts/run_onchange_after_20-import-vorssaint-settings.sh.tmpl .chezmoiscripts/run_onchange_after_90-rebuild-bat-cache.sh.tmpl
ZSH_FILES := $(shell git ls-files '*.zsh' 'dot_config/zsh/dot_zprofile' 'dot_config/zsh/dot_zshenv' 'dot_config/zsh/dot_zshrc' | while IFS= read -r f; do [ -f "$$f" ] && printf '%s\n' "$$f"; done)
TOML_FILES := $(shell git ls-files '*.toml' | while IFS= read -r f; do [ -f "$$f" ] && printf '%s\n' "$$f"; done)
LUA_FILES := $(shell git ls-files '*.lua' | while IFS= read -r f; do [ -f "$$f" ] && printf '%s\n' "$$f"; done)

PYTHON_PROJECT_DIR := dot_config/exact_nvim/lua/django-orm-analyzer
PYTHON_UV_ENV := $(or $(XDG_CACHE_HOME),$(HOME)/.cache)/uv/envs/django-orm-analyzer
PYTHON_UV_RUN := UV_PROJECT_ENVIRONMENT="$(PYTHON_UV_ENV)" PYTHONDONTWRITEBYTECODE=1 uv run --no-active --project $(PYTHON_PROJECT_DIR)

.DEFAULT_GOAL := help

.PHONY: \
	help \
	install \
	apply \
	check \
	test-neovim \
	test-python \
	lint \
	format \
	format-check \
	lint-staged \
	format-prettier \
	format-prettier-check \
	lint-markdown \
	format-toml \
	format-toml-check \
	lint-toml \
	format-shell \
	format-shell-check \
	lint-shell \
	format-zsh \
	format-zsh-check \
	lint-zsh \
	format-lua \
	format-lua-check \
	format-python \
	format-python-check \
	lint-python


## Show this help message
help:
	@awk '\
	  BEGIN {FS = ":"} \
	  /^### / {section=substr($$0,5); next} \
	  /^##/ {sub(/^## ?/, "", $$0); helpMsg = $$0; next} \
	  /^[a-zA-Z0-9_.-]+:/ { \
	    sub(/:.*/, "", $$1); \
	    if (helpMsg) { \
	      if (section) { \
	        printf "\n\033[1m%s\033[0m\n", section; \
	        section = ""; \
	      } \
	      printf "  \033[36m%-20s\033[0m %s\n", $$1, helpMsg; \
	      helpMsg = ""; \
	    } \
	  }' $(MAKEFILE_LIST)

## install node dependencies
install:
	pnpm install

### Chezmoi
## apply the chezmoi configuration to the home directory
apply:
	chezmoi apply -R --force

### Utils
## format, lint, and test all files
check: format-check lint test-neovim test-python

## test neovim configuration
test-neovim:
	nvim --headless -u NONE -i NONE -l tests/neovim.lua
	nvim --headless -u NONE -i NONE -l tests/neovim-keymaps.lua

## test python plugins
test-python:
	$(PYTHON_UV_RUN) pytest -o cache_dir="$(PYTHON_UV_ENV)/pytest_cache" $(PYTHON_PROJECT_DIR)/tests

## lint all files
lint: lint-markdown lint-toml lint-shell lint-zsh lint-python

## format all files
format: format-prettier format-toml format-shell format-zsh format-lua format-python

## check formatting of all files
format-check: format-prettier-check format-toml-check format-shell-check format-zsh-check format-lua-check format-python-check

## lint files staged for commit
lint-staged:
	pnpm exec lint-staged

## format markdown, json, and yaml files
format-prettier:
	pnpm exec prettier --write --ignore-unknown --config dot_prettierrc.toml $(PRETTIER_GLOBS)

## check formatting of markdown, json, and yaml files
format-prettier-check:
	pnpm exec prettier --check --ignore-unknown --config dot_prettierrc.toml $(PRETTIER_GLOBS)

## lint markdown files
lint-markdown:
	pnpm exec markdownlint-cli2 --config dot_markdownlint.toml $(MARKDOWN_FILES)

## format toml files
format-toml:
	pnpm exec tombi format $(TOML_FILES)

## check formatting of toml files
format-toml-check:
	pnpm exec tombi format --check $(TOML_FILES)

## lint toml files
lint-toml:
	pnpm exec tombi lint --error-on-warnings $(TOML_FILES)

## format shell files
format-shell:
	shfmt -w -i 4 -ci -bn $(SHELL_FILES)

## check formatting of shell files
format-shell-check:
	shfmt -d -i 4 -ci -bn $(SHELL_FILES)

## lint shell files
lint-shell:
	shellcheck $(SHELL_FILES) $(SHELLCHECK_TEMPLATE_FILES)

## format zsh files
format-zsh:
	shfmt -w -ln zsh -i 2 $(ZSH_FILES)

## check formatting of zsh files
format-zsh-check:
	shfmt -d -ln zsh -i 2 $(ZSH_FILES)

## lint zsh files
lint-zsh:
	zsh -n $(ZSH_FILES)

## format lua files
format-lua:
	pnpm exec stylua --config-path dot_config/exact_nvim/stylua.toml $(LUA_FILES)

## check lua files
format-lua-check:
	pnpm exec stylua --check --config-path dot_config/exact_nvim/stylua.toml $(LUA_FILES)

## format python files
format-python:
	$(PYTHON_UV_RUN) ruff format $(PYTHON_PROJECT_DIR)

## check formatting of python files
format-python-check:
	$(PYTHON_UV_RUN) ruff format --check $(PYTHON_PROJECT_DIR)

## lint python files
lint-python:
	$(PYTHON_UV_RUN) ruff check --no-cache $(PYTHON_PROJECT_DIR)
	$(PYTHON_UV_RUN) mypy --cache-dir="$(PYTHON_UV_ENV)/mypy_cache" --config-file $(PYTHON_PROJECT_DIR)/pyproject.toml $(PYTHON_PROJECT_DIR)
