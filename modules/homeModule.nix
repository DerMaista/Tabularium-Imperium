{ lib, pkgs, ... }:
{
  systemd.user.services.wl-gammarelay-rs = {
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
}
