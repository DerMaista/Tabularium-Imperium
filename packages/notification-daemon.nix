{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "my-notification-daemon";
  version = "1.0";

  src = ../notification-daemon;

  installPhase = ''
    mkdir -p $out/share/my-notification-daemon
    cp -r . $out/share/my-notification-daemon

    mkdir -p $out/bin

    cat > $out/bin/my-notification-daemon <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.quickshell}/bin/quickshell \
      -p $out/share/my-notification-daemon
    EOF

    chmod +x $out/bin/my-notification-daemon

    cat > $out/bin/my-notification-daemon-toggle-center <<EOF
    #!${pkgs.runtimeShell}
    exec ${pkgs.quickshell}/bin/quickshell \
      -p $out/share/my-notification-daemon \
      ipc call notifications toggle
    EOF

    chmod +x $out/bin/my-notification-daemon-toggle-center
  '';

  meta = {
    mainProgram = "my-notification-daemon";
  };
}