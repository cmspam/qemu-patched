{
  description = "QEMU from git master with virglrenderer binary graft (no QEMU rebuilds)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    qemu-src = {
      url = "git+https://gitlab.com/qemu-project/qemu.git";
      flake = false;
    };
    # ... (other qemu deps omitted for brevity, keep them in your actual file)
    virglrenderer-src = {
      url = "gitlab:virgl/virglrenderer?host=gitlab.freedesktop.org";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, qemu-src, virglrenderer-src, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = final: prev: {
        
        # 1. The "Custom" virglrenderer you are actively hacking on
        virglrenderer-git = prev.virglrenderer.overrideAttrs (oldAttrs: {
          version = "git-custom";
          src = virglrenderer-src;
          patches = (oldAttrs.patches or [ ]) ++ [ ./virglrenderer-xe-native-context.patch ];
          mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [ "-Ddrm-renderers=xe-experimental" ];
        });

        # 2. The Base QEMU (This build happens once and is cached)
        qemu-base = (prev.qemu.override {
          virglSupport = true;
          # ... (keep all your other spice/gtk/etc flags here)
        }).overrideAttrs (oldAttrs: {
          pname = "qemu-base";
          src = qemu-src;
          # ... (keep your preConfigure and patches here)
        });

        # 3. The Grafted QEMU (The 'Replacement' logic)
        # This replaces the virglrenderer dependency in the binary WITHOUT rebuilding QEMU.
        qemu = prev.replaceDependency {
          drv = final.qemu-base;
          oldDependency = prev.virglrenderer; # The one QEMU was originally built against
          newDependency = final.virglrenderer-git; # Your new hacked version
        };
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          default = pkgs.qemu;
          virglrenderer = pkgs.virglrenderer-git;
        });
    };
}
