{
  description = "Shared macOS and Linux command-line tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
    in
    {
      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" "terraform" ];
          };
          homelabTofu = import ./opentofu.nix { inherit pkgs; };
        in
        {
          onepassword = pkgs._1password-cli;
          opentofu = homelabTofu;
          default = pkgs.buildEnv {
            name = "dotfiles-tools";
            paths =
              with pkgs;
              [
                _1password-cli
                actionlint
                awscli2
                bash-completion
                bat
                chezmoi
                cmake
                # Include pnpm/yarn shims and prefer this over Node's bundled corepack.
                (lib.hiPrio corepack)
                curl
                delta
                direnv
                docker-client
                docker-compose
                eza
                fd
                ffmpeg
                fzf
                gettext
                gh
                git
                gitleaks
                gnumake
                go
                hadolint
                helm-ls
                homelabTofu
                jq
                k9s
                kind
                kube-linter
                kubectl
                kubectx
                kubernetes-helm
                lazygit
                lua5_1
                lua51Packages.luarocks
                ninja
                nodejs_24
                (perl.withPackages (ps: [ ps.NeovimExt ]))
                perlPackages.Appcpanminus
                pkg-config
                ripgrep
                ruby
                shellcheck
                shfmt
                starship
                stdenv.cc
                terraform
                terraform-ls
                tmux
                tree-sitter
                ueberzugpp
                uv
                wget
                xdg-ninja
                yq-go
                zoxide
                zsh-autosuggestions
                zsh-syntax-highlighting
              ]
              ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin (
                with pkgs;
                [
                  blueutil
                  jankyborders
                  switchaudio-osx
                ]
              );
            pathsToLink = [
              "/bin"
              "/share"
            ];
            postBuild = ''
              ln -s ${pkgs.lua5_1}/bin/lua $out/bin/lua5.1
            '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
              ln -s ${pkgs.llvmPackages.llvm}/bin/dsymutil $out/bin/dsymutil
            '';
          };
        }
      );
    };
}
