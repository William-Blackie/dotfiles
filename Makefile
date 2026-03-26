.PHONY: help setup install-packages normalize-stow-links install uninstall reinstall edit test check-format check-shell check-zsh-syntax check-secrets tune-docker ci status

PACKAGES := zsh tmux kitty starship nvim git fzf shell bat
STOW := stow --target="$(HOME)" --dir="$(CURDIR)"

# Default target
help:
	@echo "Dotfiles Management"
	@echo "==================="
	@echo ""
	@echo "Available commands:"
	@echo "  make setup             - Install packages, stow dotfiles, run post-install bootstrap"
	@echo "  make install-packages  - Install Homebrew packages from Brewfile"
	@echo "  make install           - Stow packages and back up any conflicts"
	@echo "  make reinstall         - Normalize repo links and restow everything"
	@echo "  make uninstall         - Remove stow-managed links"
	@echo "  make edit              - Open ~/.dotfiles in Neovim"
	@echo "  make status            - Show stow health and tool availability"
	@echo "  make test              - Run smoke tests"
	@echo "  make ci                - Run checks and smoke tests"
	@echo ""
	@echo "Checks:"
	@echo "  make check-format      - Verify shell formatting with shfmt"
	@echo "  make check-shell       - Lint shell scripts with shellcheck"
	@echo "  make check-zsh-syntax  - Parse zsh dotfiles for syntax errors"
	@echo "  make check-secrets     - Scan tracked files for key/token leaks"
	@echo "  make tune-docker       - Apply local Docker CLI/Desktop tuning"

setup: install-packages install
	@echo "🔧 Running additional setup..."
	@./setup.sh
	@echo "🎉 Complete setup finished!"
	@echo "Please restart your terminal or run: source ~/.zshrc"

install-packages:
	@./scripts/install-packages.sh

normalize-stow-links:
	@./scripts/normalize-stow-links.py "$(CURDIR)" "$(PACKAGES)"

install:
	@$(MAKE) normalize-stow-links
	@echo "📦 Stowing dotfiles (backing up conflicts)..."
	@BACKUP_DIR="$${HOME}/.dotfiles_backup_$$(date +%Y%m%d_%H%M%S)"; \
	mkdir -p "$$BACKUP_DIR"; \
	echo "$$BACKUP_DIR" > "$${HOME}/.dotfiles-last-backup"; \
	for pkg in $(PACKAGES); do \
		echo "→ Processing $$pkg"; \
		$(STOW) -n $$pkg 2>&1 | grep "existing target" | sed 's/.*existing target \(.*\) since.*/\1/' | while read -r target; do \
			[ -z "$$target" ] && continue; \
			target_path="$${HOME}/$$target"; \
			if [ -e "$$target_path" ] || [ -L "$$target_path" ]; then \
				backup_path="$$BACKUP_DIR/$$target"; \
				mkdir -p "$$(dirname "$$backup_path")"; \
				echo "  ⚠️  Backing up $$target"; \
				mv "$$target_path" "$$backup_path"; \
			fi; \
		done; \
		$(STOW) $$pkg; \
	done
	@command -v bat >/dev/null 2>&1 && bat cache --build || true
	@echo "✅ Stow complete. Latest backup path is in ~/.dotfiles-last-backup"

uninstall:
	$(STOW) -D $(PACKAGES)

reinstall:
	@$(MAKE) normalize-stow-links
	$(STOW) -R $(PACKAGES)
	@command -v bat >/dev/null 2>&1 && bat cache --build || true

edit:
	@cd "$(CURDIR)" && nvim .

test:
	@python3 -m unittest discover -s tests/e2e -p 'test_*.py' -v

check-format:
	@command -v shfmt >/dev/null 2>&1 || { echo "shfmt not found"; exit 1; }
	@files="$$(git ls-files '*.sh' | while read -r file; do [ -f "$$file" ] && printf '%s\n' "$$file"; done)"; \
	if [ -n "$$files" ]; then \
	  shfmt -d -i 2 -ci -sr -ln bash $$files; \
	fi

check-shell:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found"; exit 1; }
	@files="$$(git ls-files '*.sh' | while read -r file; do [ -f "$$file" ] && printf '%s\n' "$$file"; done)"; \
	if [ -n "$$files" ]; then \
	  shellcheck -x $$files; \
	fi

check-zsh-syntax:
	@zsh -n zsh/.zshrc shell/.zprofile shell/.zshenv

check-secrets:
	@./scripts/check-sensitive.sh

tune-docker:
	@./scripts/tune-docker-cli.sh
	@./scripts/tune-docker-desktop-macos.sh

ci: check-format check-shell check-zsh-syntax check-secrets test

status:
	@echo "Repository: $(CURDIR)"
	@echo "Packages: $(PACKAGES)"
	@echo ""
	@echo "Stow dry run:"
	@tmp="$$(mktemp)"; \
	if $(STOW) -n -R $(PACKAGES) >"$$tmp" 2>&1; then \
		echo "✅ no stow conflicts"; \
	else \
		echo "❌ stow conflicts detected"; \
		cat "$$tmp"; \
	fi; \
	rm -f "$$tmp"
	@echo ""
	@echo "Tooling:"
	@command -v git >/dev/null && echo "✅ git installed" || echo "❌ git not installed"
	@command -v nvim >/dev/null && echo "✅ neovim installed" || echo "❌ neovim not installed"
	@command -v tmux >/dev/null && echo "✅ tmux installed" || echo "❌ tmux not installed"
	@command -v starship >/dev/null && echo "✅ starship installed" || echo "❌ starship not installed"
	@command -v fzf >/dev/null && echo "✅ fzf installed" || echo "❌ fzf not installed"
