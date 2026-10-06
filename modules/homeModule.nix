{ config, lib, pkgs, blueshell, ... }:
let
  cfg = config.programs.tabularium-imperium;

  json = pkgs.formats.json { };
  configFile = json.generate "tabularium-imperium-config.json" cfg.settings;
  managed = cfg.settings != { };
in
{
  options.programs.tabularium-imperium.settings = lib.mkOption {
    type = json.type;
    default = { };
    example = lib.literalExpression ''
      {
        bar.height = 35;
        text = {
          fontfamily = "NerdFont Mono";
          fontsize = 14;
        };
        osd.timeout = 2000;
        lock = {
          idleTimeout = 600;
          lockOnStartup = true;
        };
        animation = {
          colorDuration = 400;
          colorEasing = "OutCubic";
        };
        sigil.dir = "''${config.home.homeDirectory}/.dotfiles/modules/style/svgs";
        wallpaper_switcher = {
          wallpaperDir = "''${config.home.homeDirectory}/.dotfiles/modules/style/wallpapers";
          wallpaperCmd = "switch-wallpaper";
        };
      }
    '';
    description = ''
      Written to {file}`$XDG_CONFIG_HOME/tabularium-imperium/config.json`.
      Leave a key out and the shell uses its own default for it;
      {file}`src/shell/config/config.json` lists every key with its default.

      While this is empty, home-manager does not touch the file, so a
      hand-written one keeps working.
    '';
  };

  config = {
    xdg.configFile."tabularium-imperium/config.json" = lib.mkIf managed {
      source = configFile;
    };

    systemd.user.services = {
      wl-gammarelay-rs = {
        Unit = {
          Description = "wl-gammarelay-rs";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.wl-gammarelay-rs} run";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      tabularium = {
        Unit = {
          Description = "Tabularium-Imperium";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # A switch replaces the symlink rather than writing through it, which
          # the UI's file watch can miss; restarting on a changed file is sure.
          X-Restart-Triggers = lib.optional managed "${configFile}";
        };

        Service = {
          ExecStart = "${lib.getExe blueshell} run";
          Restart = "always";
          RestartSec = 2;
          KillMode = "control-group";
          TimeoutStopSec = 5;
          SuccessExitStatus = 143;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
