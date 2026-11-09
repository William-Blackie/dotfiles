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
            config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "1password-cli";
          };
        in
        {
          onepassword = pkgs._1password-cli;
          default = pkgs.buildEnv {
            name = "dotfiles-tools";
            paths =
              with pkgs;
              [
                _1password-cli
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
                gnumake
                go
                hadolint
                jq
                k9s
                kind
                kube-linter
                kubectl
                kubectx
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
                tmux
                tree-sitter
                ueberzugpp
                uv
                wget
                xdg-ninja
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
