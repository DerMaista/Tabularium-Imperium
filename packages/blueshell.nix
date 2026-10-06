{ pkgs, inputs }:

let
    runtimeDeps = [ pkgs.quickshell inputs.chromarium-mechanicus.packages.${pkgs.stdenv.hostPlatform.system}.chromarium-mechanicus pkgs.wl-gammarelay-rs ];
in
pkgs.buildGoModule {
  pname = "blueshell";
  version = "2.0";

  src = pkgs.lib.cleanSource ../src;

  vendorHash = "sha256-cVe/wX2183N4Nn1uDYQMPo6svy27umi4pG2tKHeiYSw=";

  ldflags = [ "-s" "-w" "-X main.Version=2.0" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/blueshell \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps} \
      --suffix XDG_DATA_DIRS : ${pkgs.adwaita-icon-theme}/share
  '';

  meta = {
    description = "The blueshell desktop: a Go backend daemon and a quickshell UI";
    mainProgram = "blueshell";
  };
}
