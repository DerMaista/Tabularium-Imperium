{
  description = "Tabularium Imperium Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    chromarium-mechanicus = {
      url = "github:DerMaista/Chromarium-Mechanicus"; # https://github.com/DerMaista/Chromarium-Mechanicus
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {

    flake =
      let
        # The home module needs *this* flake's blueshell, so it is closed over
        # here. It cannot ask for `self`: home-manager hands a module the
        # importing flake's self, which has no packages of ours.
        homeModule = args@{ pkgs, ... }:
          import ./modules/homeModule.nix (args // {
            blueshell = self.packages.${pkgs.stdenv.hostPlatform.system}.blueshell;
          });
      in
      {
        nixosModules.default = import ./modules/nixosModule.nix;

        homeManagerModules.default = homeModule;
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