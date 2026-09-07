{ pkgs, inputs }:

let
    runtimeDeps = [ pkgs.quickshell inputs.chromarium-mechanicus.packages.${pkgs.stdenv.hostPlatform.system}.chromarium-mechanicus ];
in
pkgs.buildGoModule {
  pname = "blueshell";
  version = "2.0";

  src = pkgs.lib.cleanSource ../blueshell-go;

  # `nix build` will tell you the correct value if this ever goes stale:
  # set it to lib.fakeHash, build, and copy the hash from the error.
  vendorHash = "sha256-Kb92FX9cEb5eQhLrbKfA3vlsgKpGvD2pLKjCgSF/Pjc=";

  ldflags = [ "-s" "-w" "-X main.Version=2.0" ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # quickshell is the only thing the daemon execs, and it must be the exact
  # one this was built against.
  postInstall = ''
    wrapProgram $out/bin/blueshell \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = {
    description = "The blueshell desktop: a Go backend daemon and a quickshell UI";
    mainProgram = "blueshell";
  };
}
