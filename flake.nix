{
  description = "My Quickshell setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    chromarium-mechanicus = {
      url = "github:DerMaista/Chromarium-Mechanicus"; # https://github.com/DerMaista/Chromarium-Mechanicus
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {

    flake = {
      hmModules.default = import ./modules/tabularium-imperium.nix;
      nixosModules.default = import ./modules/services.nix;
    };

    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    perSystem = { pkgs, ... }:
      let
        blueshell = import ./packages/blueshell.nix { inherit pkgs inputs; };
      in {
      packages = {
        quickshell-bar = import ./packages/bar.nix { inherit pkgs; };
        quickshell-notification-daemon =
          import ./packages/notification-daemon.nix { inherit pkgs; };
        quickshell-wallpaper-switcher =
          import ./packages/wallpaper-switcher.nix { inherit pkgs; };

        inherit blueshell;
      };

      apps = {
        blueshell = {
          type = "app";
          program = "${blueshell}/bin/blueshell";
          meta.description = "The blueshell desktop: a Go backend daemon and a quickshell UI";
        };
        default = {
          type = "app";
          program = "${blueshell}/bin/blueshell";
          meta.description = "The blueshell desktop: a Go backend daemon and a quickshell UI";
        };
      };
    };
  };
}