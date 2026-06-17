{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "my-bar";
  version = "1.0";

  src = ../bar;

  installPhase = ''
    mkdir -p $out/share/my-bar
    cp -r . $out/share/my-bar

    mkdir -p $out/bin

    cat > $out/bin/my-bar <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.quickshell}/bin/quickshell \
      -p $out/share/my-bar
    EOF

    chmod +x $out/bin/my-bar
  '';
  meta = {
    mainProgram = "my-bar";
  };
}