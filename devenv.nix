{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.qmllint pkgs.quickshell ];

  # https://devenv.sh/languages/
  languages = {
    go = {
      enable = true;
      version = "1.26.0"
    };
  };
  scripts.execBlueshell.exec = ''
    nix shell run .#blueshell -- run
  '';
}
