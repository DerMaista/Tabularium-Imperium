{
  description = "My Quickshell setup";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    perSystem = { pkgs, ... }: {
      packages = {
        quickshell-bar = import ./packages/bar.nix { inherit pkgs; };
        quickshell-notification-daemon =
          import ./packages/notification-daemon.nix { inherit pkgs; };
        quickshell-wallpaper-switcher =
          import ./packages/wallpaper-switcher.nix { inherit pkgs; };
      };
    };
  };
}