{
  description = "QEMU from git master with virglrenderer from git";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    qemu-src = {
      url = "git+https://gitlab.com/qemu-project/qemu.git";
      flake = false;
    };
    keycodemapdb = {
      url = "git+https://gitlab.com/qemu-project/keycodemapdb.git";
      flake = false;
    };
    berkeley-softfloat-3 = {
      url = "git+https://gitlab.com/qemu-project/berkeley-softfloat-3.git";
      flake = false;
    };
    berkeley-testfloat-3 = {
      url = "git+https://gitlab.com/qemu-project/berkeley-testfloat-3.git";
      flake = false;
    };
    virglrenderer-src = {
      url = "gitlab:virgl/virglrenderer?host=gitlab.freedesktop.org";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, qemu-src, virglrenderer-src, ... }@inputs:
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
          virglrenderer = import ./pkgs/virglrenderer-git.nix {
            inherit final prev virglrenderer-src patchSrc;
          };

          qemu = import ./pkgs/qemu-git.nix {
            inherit final prev qemu-src patchSrc inputs;
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
