{ pkgs, inputs }:

let
    runtimeDeps = [ pkgs.quickshell inputs.chromarium-mechanicus.packages.${pkgs.stdenv.hostPlatform.system}.chromarium-mechanicus pkgs.wl-gammarelay-rs ];
in
pkgs.buildGoModule {
  pname = "blueshell";
  version = "2.0";

  src = pkgs.lib.cleanSource ../src;

  vendorHash = "sha256-Kb92FX9cEb5eQhLrbKfA3vlsgKpGvD2pLKjCgSF/Pjc=";

  ldflags = [ "-s" "-w" "-X main.Version=2.0" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/blueshell \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = {
    description = "The blueshell desktop: a Go backend daemon and a quickshell UI";
    mainProgram = "blueshell";
  };
}
