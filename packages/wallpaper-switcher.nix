{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "my-wallpaper-switcher";
  version = "1.0";

  src = ../wallpaper-switcher;

  installPhase = ''
    mkdir -p $out/share/my-wallpaper-switcher
    cp -r . $out/share/my-wallpaper-switcher

    mkdir -p $out/bin

    cat > $out/bin/my-wallpaper-switcher <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.quickshell}/bin/quickshell \
      -p $out/share/my-wallpaper-switcher
    EOF

    chmod +x $out/bin/my-wallpaper-switcher
  '';

  meta = {
    mainProgram = "my-wallpaper-switcher";
  };
}

