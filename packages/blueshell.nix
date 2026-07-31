{ pkgs }:

let
  runtimeDeps = [ pkgs.playerctl ];
in
pkgs.stdenv.mkDerivation {
  pname = "my-blueshell";
  version = "1.0";

  src = ../blueshell;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/share/my-blueshell
    cp -r . $out/share/my-blueshell

    mkdir -p $out/bin

    cat > $out/bin/my-blueshell <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.quickshell}/bin/quickshell \
      -p $out/share/my-blueshell
    EOF

    chmod +x $out/bin/my-blueshell

    wrapProgram $out/bin/my-blueshell \
      --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
  '';

  meta = {
    mainProgram = "my-blueshell";
  };
}

