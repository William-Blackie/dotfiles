SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

PRETTIER_GLOBS := "**/*.{md,json,yml,yaml}"
MARKDOWN_FILES := $(shell git ls-files '*.md')
SHELL_FILES := $(shell git ls-files '*.sh' 'dot_zshenv')
SHELLCHECK_TEMPLATE_FILES := .chezmoiscripts/run_after_85-build-nvim-env.sh.tmpl .chezmoiscripts/run_onchange_after_90-rebuild-bat-cache.sh.tmpl
ZSH_FILES := $(shell git ls-files '*.zsh' 'dot_config/zsh/dot_zprofile' 'dot_config/zsh/dot_zshenv' 'dot_config/zsh/dot_zshrc')
TOML_FILES := $(shell git ls-files '*.toml')
LUA_FILES := $(shell git ls-files '*.lua')

.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf 'Targets:\n'
	@printf '  install        Install Node dependencies\n'
	@printf '  check          Run format checks and linters\n'
	@printf '  lint           Run linters\n'
	@printf '  format         Format files\n'
	@printf '  format-check   Check formatting\n'
	@printf '  lint-staged    Run lint-staged\n'

.PHONY: install
install:
	pnpm install

.PHONY: check
check: format-check lint

.PHONY: lint
lint: lint-markdown lint-toml lint-shell lint-zsh

.PHONY: format
format: format-prettier format-toml format-shell format-zsh format-lua

.PHONY: format-check
format-check: format-prettier-check format-toml-check format-shell-check format-zsh-check format-lua-check

.PHONY: lint-staged
lint-staged:
	pnpm exec lint-staged

.PHONY: format-prettier
format-prettier:
	pnpm exec prettier --write --ignore-unknown --config dot_prettierrc.toml $(PRETTIER_GLOBS)

.PHONY: format-prettier-check
format-prettier-check:
	pnpm exec prettier --check --ignore-unknown --config dot_prettierrc.toml $(PRETTIER_GLOBS)

.PHONY: lint-markdown
lint-markdown:
	pnpm exec markdownlint-cli2 --config dot_markdownlint.toml $(MARKDOWN_FILES)

.PHONY: format-toml
format-toml:
	pnpm exec taplo format --config taplo.toml $(TOML_FILES)

.PHONY: format-toml-check
format-toml-check:
	pnpm exec taplo format --check --config taplo.toml $(TOML_FILES)

.PHONY: lint-toml
lint-toml:
	pnpm exec taplo lint --config taplo.toml --no-schema $(TOML_FILES)

.PHONY: format-shell
format-shell:
	shfmt -w -i 4 -ci -bn $(SHELL_FILES)

.PHONY: format-shell-check
format-shell-check:
	shfmt -d -i 4 -ci -bn $(SHELL_FILES)

.PHONY: lint-shell
lint-shell:
	shellcheck $(SHELL_FILES) $(SHELLCHECK_TEMPLATE_FILES)

.PHONY: format-zsh
format-zsh:
	shfmt -w -ln zsh -i 2 $(ZSH_FILES)

.PHONY: format-zsh-check
format-zsh-check:
	shfmt -d -ln zsh -i 2 $(ZSH_FILES)

.PHONY: lint-zsh
lint-zsh:
	zsh -n $(ZSH_FILES)

.PHONY: format-lua
format-lua:
	pnpm exec stylua --config-path dot_config/exact_nvim/stylua.toml $(LUA_FILES)

.PHONY: format-lua-check
format-lua-check:
	pnpm exec stylua --check --config-path dot_config/exact_nvim/stylua.toml $(LUA_FILES)
