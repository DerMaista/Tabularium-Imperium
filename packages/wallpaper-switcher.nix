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

# evaluation warning: getExe: Package "my-wallpaper-switcher-1.0" does not have the meta.mainProgram attribute. We'll assume that the main program has the same name for now, but this behavior is deprecated, because it leads to surprising errors when the assumption does not hold. If the package has a main program, please set `meta.mainProgram` in its definition to make this warning go away. Otherwise, if the package does not have a main program, or if you don't control its definition, use getExe' to specify the name to the program, such as lib.getExe' foo "bar".
