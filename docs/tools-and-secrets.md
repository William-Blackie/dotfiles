# Tools and secrets

## 1Password And SSH

Following the
[chezmoi bootstrap guide](https://www.chezmoi.io/user-guide/advanced/install-your-password-manager-on-init/),
the small `.install-password-manager.sh` hook reuses the managed `op`, or asks
Nix to install the pinned `onepassword` package. It uses the documented
`read-source-state.pre` hook, including for `diff`, `status`, and dry runs.
There is no custom download, architecture, or checksum handling: Nixpkgs
maintains that. The full tools profile includes the same CLI and replaces the
bootstrap profile on apply. Only 1Password CLI is allowed as an unfree Nix
package.

The desktop app remains a Homebrew cask on macOS; install it separately on Linux
if you want desktop integration. CLI installation does not sign you in.

After the desktop app is installed, sign in and enable **Settings → Developer →
Integrate with 1Password CLI**. Check authentication with `op whoami` before
applying any templates that read secrets.

SSH is wired to the 1Password SSH agent through `dot_ssh/config.tmpl`. The repo
only stores the generic socket path.

Local 1Password state is intentionally not managed:

```sh
~/.config/1Password/ssh/agent.toml
```

Set up keys in the 1Password app on each machine, enable the SSH agent, and keep
key/vault/account selection local to that machine. Do not add `agent.toml`,
private keys, GitHub tokens, or `gh` auth state to this repo.

Optional per-machine SSH overrides go here:

```sh
~/.ssh/config.local
```

For two accounts, put the account IDs (from `op account list`) in the local
`~/.config/zsh/.zshenv.local` file:

```sh
export OP_WORK_ACCOUNT="your-work-account-id"
export OP_PERSONAL_ACCOUNT="your-personal-account-id"
export CHEZMOI_1PASSWORD_ACCOUNT="$OP_PERSONAL_ACCOUNT"
```

The shell provides `opwork` and `oppersonal` for explicit account selection,
`opswitch work` / `opswitch personal` for the current shell, and `opsignin work`
/ `opsignin personal` for desktop-app authentication. The chezmoi wrapper scopes
its account override to that command, preserving the selected shell account. Use
an explicit account for work secrets in templates, for example
`onepasswordRead "op://vault/item/field" (env "OP_WORK_ACCOUNT")`.

In the local SSH agent config, specify both `account` and `vault` IDs for each
`[[ssh-keys]]` entry. Use a public-key `IdentityFile` with `IdentitiesOnly yes`
in `~/.ssh/config.local` to select a particular agent key for GitHub without
storing its private key on disk. The same personal GitHub identity can be used
for personal and work repositories; the work 1Password account is independent.

Application sessions managed by GitHub CLI and Docker stay in the OS credential
store. Kubernetes and AWS configuration are rendered directly from 1Password
items into `~/.kube/config`, `~/.config/aws/credentials`, and
`~/.config/aws/config`, with file permissions `0600`.

The machine-local chezmoi config holds references, never secret values:

```toml
[data.workSecrets]
account = "WORK_ACCOUNT_ID"
awsCredentials = "op://VAULT_ID/AWS_CREDENTIALS_ITEM_ID/notesPlain"
awsConfig = "op://VAULT_ID/AWS_CONFIG_ITEM_ID/notesPlain"

[data.kubernetes]
currentContext = "prod"

[[data.kubernetes.sources]]
name = "prod"
account = "WORK_ACCOUNT_ID"
reference = "op://PRODUCTION_VAULT_ID/KUBECONFIG_ITEM_ID/notesPlain"

[[data.kubernetes.sources]]
name = "staging"
account = "WORK_ACCOUNT_ID"
reference = "op://STAGING_VAULT_ID/KUBECONFIG_ITEM_ID/notesPlain"

[[data.kubernetes.sources]]
name = "homelab"
account = "PERSONAL_ACCOUNT_ID"
vault = "HOMELAB_VAULT_ID"
document = "KUBECONFIG_DOCUMENT_ID"
```

These mappings survive `chezmoi init`. AWS mappings can also be supplied through
`OP_WORK_ACCOUNT`, `OP_AWS_CREDENTIALS_REF`, and `OP_AWS_CONFIG_REF`. A missing
mapping leaves its existing file unmanaged; a failed or empty secret read stops
the apply before replacing that file.

Each Kubernetes source contributes its current context, renamed to its
configured name along with its cluster and user. Switch using
`kubectl config use-context staging` (or `prod` / `homelab`). Applying restores
`currentContext` from the chezmoi config. Production and staging come from the
work account; homelab comes from the personal account.

Change the authoritative item in 1Password, then refresh just these files:

```sh
chezmoi apply --exclude=scripts ~/.kube/config ~/.config/aws
```

Local edits do not sync back to 1Password and are replaced when reapplied. Keep
these files as templates; do not use `chezmoi add` to commit their rendered
contents. To preview other dotfiles without rendering secrets, use
`chezmoi diff --skip-secrets`.

## Nix Tools

`.nix/flake.nix` defines the shared CLI tools, and `.nix/flake.lock` pins
Nixpkgs. Chezmoi rebuilds the package set when its definition, lock, installer,
or shell integration changes. It switches the dedicated profile only after a
successful build, preserving the previous generation on failure:

```sh
~/.local/state/nix/profiles/dotfiles
```

AWS CLI and the Kubernetes tools are included in the shared profile. Node 24 is
the default. NVM remains available on demand for project-specific versions:
`nvm use` selects a version and `nvm deactivate` returns to Nix's Node. Corepack
provides `pnpm` and `yarn`, honoring project `packageManager` versions. Ruby,
Perl, Lua 5.1, and LuaRocks also come from Nix; Neovim's provider setup
discovers them on PATH. Rustup and uv continue managing their existing project
toolchains/environments. Neovim itself keeps its existing source build.
Libraries such as zlib come through Nix package dependencies instead of a global
Homebrew formula.

Perl includes Neovim's bindings and native dependencies in Nix, so changing Perl
versions no longer leaves stale local CPAN builds.

For global tools using Nix's Node, use the writable directory already on PATH:
`npm install --global --prefix ~/.local/share/npm PACKAGE`. There is no
permanent npm `prefix` setting, so NVM can manage its per-version global
packages normally. Chezmoi installs NVM from a pinned, checksum-verified
upstream archive into `~/.local/share/nvm`; only its scripts and license are
managed, preserving installed Node versions, aliases, and cache. NVM loads only
when requested, independently of Homebrew. Update the release URL and checksum
in `.chezmoiexternal.toml`, then apply, to upgrade NVM.

Update the lock and apply the new tool versions:

```sh
nix --extra-experimental-features 'nix-command flakes' flake update --flake ~/dotfiles/.nix
chezmoi apply
```

Retry a failed install or restore a missing profile without changing the lock:

```sh
bash ~/dotfiles/.install-nix-packages.sh
```

Roll back just the shared tools:

```sh
nix-env --profile ~/.local/state/nix/profiles/dotfiles --rollback
```

The profile is separate from `~/.nix-profile`, so manual Nix packages are
preserved. Do not use `nix profile install` on this profile: it is switched as
one complete package set with `nix-env --set`. The pinned 1Password CLI package
supports Apple Silicon macOS and both Linux architectures; Intel macOS is not
included here.
