{ lib, pkgs, blueshell, ... }:
{
  systemd.user.services = {
    wl-gammarelay-rs = {
      Unit = {
        Description = "wl-gammarelay-rs";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.wl-gammarelay-rs} run";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    tabularium = {
      Unit = {
        Description = "Tabularium-Imperium";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe blueshell} run";
        Restart = "on-failure";
        RestartSec = 2;
        KillMode = "control-group";
        TimeoutStopSec = 5;
        SuccessExitStatus = 143;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
