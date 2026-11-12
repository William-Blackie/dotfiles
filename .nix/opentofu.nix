{ pkgs }:
let
  version = "1.12.1";
  releases = {
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-fVwms/5YOue9qujQfrku6rX71D+4TTQU3kF7pVjENkk=";
    };
    aarch64-linux = {
      platform = "linux_arm64";
      hash = "sha256-/Tuw3YH43POPwuhMI4GhUwqUSoXg/P7ekA1WtL06ahw=";
    };
    x86_64-linux = {
      platform = "linux_amd64";
      hash = "sha256-joGMovFLtO5ZQjHJCMp37DQVyeGUMCqwySyJR72QhnA=";
    };
  };
  release = releases.${pkgs.stdenv.hostPlatform.system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opentofu";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/opentofu/opentofu/releases/download/v${version}/tofu_${version}_${release.platform}.tar.gz";
    inherit (release) hash;
  };

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 tofu "$out/bin/tofu"
    runHook postInstall
  '';
  meta.mainProgram = "tofu";
}
