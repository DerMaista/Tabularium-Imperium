{ ... }:
{
  # Enables the D-Bus-activated system services that blueshell widgets
  # depend on (e.g. Battery.qml -> Quickshell.Services.UPower).
  services.upower.enable = true;
}
