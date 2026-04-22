{
  description = "QEMU 11.0.0 with patched virglrenderer from nixpkgs";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs supportedSystems;
    in {
      overlays.default = final: prev:
        let
          patchSrc = builtins.path {
            path = ./patches;
            name = "qemu-virgl-patches";
            filter = path: type:
              type == "directory" ||
              builtins.elem (builtins.baseNameOf path) [
                "qemu-all-in-one.patch"
                "virglrenderer-xe-native-context.patch"
              ];
          };
        in {
          virglrenderer = import ./pkgs/virglrenderer.nix {
            inherit prev patchSrc;
          };

          qemu = import ./pkgs/qemu.nix {
            inherit prev patchSrc;
            virglrenderer = final.virglrenderer;
          };
        };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        in {
          default = pkgs.qemu;
          qemu = pkgs.qemu;
          virglrenderer = pkgs.virglrenderer;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in {
          default = pkgs.mkShell {
            buildInputs = [ pkgs.qemu pkgs.virglrenderer ];
          };
        });
    };
}
