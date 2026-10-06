{ config, lib, ... }:
{
  services.upower.enable = true;

  security.pam.services.blueshell.fprintAuth = false;
  security.pam.services.blueshell-fingerprint = lib.mkIf config.services.fprintd.enable {
    unixAuth = false;
    fprintAuth = true;
  };
}
