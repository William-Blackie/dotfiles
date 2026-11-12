{ pkgs }:
let
  # Match projects that enforce an exact required-version for uv.
  version = "0.13.6";
  releases = {
    aarch64-darwin = {
      platform = "aarch64-apple-darwin";
      hash = "sha256-YPvVyKHtaBhF7qKNnWIvzeA8UekaQ0ZbZKHhfbHtNHI=";
    };
    aarch64-linux = {
      platform = "aarch64-unknown-linux-musl";
      hash = "sha256-gZaS5ATSPlqua8RMDiYPH1SS/RkQq0aTssZQ+Sbb6AA=";
    };
    x86_64-linux = {
      platform = "x86_64-unknown-linux-musl";
      hash = "sha256-XWHya2xyE3ee2pDtxpceprC3lr+41JpXTIrWm1mDhUg=";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "uv";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/astral-sh/uv/releases/download/${version}/uv-${release.platform}.tar.gz";
    inherit (release) hash;
  };

  nativeBuildInputs = [
    pkgs.installShellFiles
    pkgs.makeBinaryWrapper
  ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 uv "$out/bin/uv"
    install -Dm755 uvx "$out/bin/uvx"
    installShellCompletion --cmd uv \
      --bash <($out/bin/uv generate-shell-completion bash) \
      --fish <($out/bin/uv generate-shell-completion fish) \
      --zsh <($out/bin/uv generate-shell-completion zsh)
    # Preserve Nixpkgs' certificate handling; uvx invokes the adjacent uv.
    wrapProgram $out/bin/uv --set-default UV_SYSTEM_CERTS 1
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  doInstallCheck = true;
  meta = {
    inherit (pkgs.uv.meta) description homepage license;
    mainProgram = "uv";
    platforms = builtins.attrNames releases;
  };
}
