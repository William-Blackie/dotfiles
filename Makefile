.DEFAULT_GOAL := help

SHELL := /bin/bash
export PATH := /opt/homebrew/bin:/usr/local/bin:$(HOME)/.local/bin:$(HOME)/bin:$(PATH)

CHEZMOI := chezmoi --source "$(CURDIR)"

PHONY := \
	help \
	setup post-install install-packages \
	build-nvim \
	apply link install reinstall \
	diff status edit \
	format ci \
	check-format check-shell check-zsh-syntax check-secrets \
	tune-docker

.PHONY: $(PHONY)

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

### Setup
## Install packages, build Neovim from source, apply dotfiles, and run post-install bootstrap
setup: install-packages build-nvim apply post-install
	@echo "Complete setup finished."
	@echo "Please restart your terminal or run: source ~/.zshrc"

## Run post-install bootstrap tasks
post-install:
	@./setup.sh

## Install Homebrew packages from Brewfile
install-packages:
	@./scripts/install-packages.sh

## Build and install Neovim from the git checkout
build-nvim:
	@./scripts/build-neovim.sh

### Dotfiles
## Apply chezmoi source state from this repo to $HOME
apply:
	@command -v chezmoi >/dev/null 2>&1 || { echo "chezmoi not installed"; exit 1; }
	@$(CHEZMOI) apply
	@command -v bat >/dev/null 2>&1 && bat cache --build || true
	@echo "chezmoi apply complete."

## Show the pending chezmoi diff
diff:
	@command -v chezmoi >/dev/null 2>&1 || { echo "chezmoi not installed"; exit 1; }
	@$(CHEZMOI) diff

## Open this chezmoi source repo in Neovim
edit:
	@cd "$(CURDIR)" && nvim .

## Show chezmoi status and tooling health
status:
	@echo "Repository: $(CURDIR)"
	@echo ""
	@echo "chezmoi status:"
	@command -v chezmoi >/dev/null 2>&1 || { echo "❌ chezmoi not installed"; exit 0; }
	@$(CHEZMOI) status || true
	@echo ""
	@echo "chezmoi doctor:"
	@$(CHEZMOI) doctor || true
	@echo ""
	@echo "Tooling:"
	@command -v git >/dev/null && echo "✅ git installed" || echo "❌ git not installed"
	@command -v chezmoi >/dev/null && echo "✅ chezmoi installed" || echo "❌ chezmoi not installed"
	@command -v nvim >/dev/null && echo "✅ neovim installed" || echo "❌ neovim not installed"
	@command -v tmux >/dev/null && echo "✅ tmux installed" || echo "❌ tmux not installed"
	@command -v starship >/dev/null && echo "✅ starship installed" || echo "❌ starship not installed"
	@command -v fzf >/dev/null && echo "✅ fzf installed" || echo "❌ fzf not installed"

### Checks
## Format shell scripts with shfmt
format:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@set --; \
	for file in $$(git ls-files '*.sh'); do \
	  [ -f "$$file" ] && set -- "$$@" "$$file"; \
	done; \
	if [ "$$#" -gt 0 ]; then \
	  shfmt -w -i 2 -ci -sr -ln bash "$$@"; \
	fi

## Run all checks
ci: check-format check-shell check-zsh-syntax check-secrets

## Verify shell formatting with shfmt
check-format:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@set --; \
	for file in $$(git ls-files '*.sh'); do \
	  [ -f "$$file" ] && set -- "$$@" "$$file"; \
	done; \
	if [ "$$#" -gt 0 ]; then \
	  shfmt -d -i 2 -ci -sr -ln bash "$$@"; \
	fi

## Lint shell scripts with shellcheck
check-shell:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found"; exit 1; }
	@set --; \
	for file in $$(git ls-files '*.sh'); do \
	  [ -f "$$file" ] && set -- "$$@" "$$file"; \
	done; \
	if [ "$$#" -gt 0 ]; then \
	  shellcheck -x "$$@"; \
	fi

## Parse zsh dotfiles for syntax errors
check-zsh-syntax:
	@zsh -n dot_zshrc dot_zprofile dot_zshenv dot_config/zsh/lib/*.zsh

## Scan tracked files for key/token leaks
check-secrets:
	@./scripts/check-sensitive.sh

### Local
## Apply local Docker CLI/Desktop tuning
tune-docker:
	@./scripts/tune-docker-cli.sh
	@./scripts/tune-docker-desktop-macos.sh
