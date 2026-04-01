{
  description = "QEMU from git master with a decoupled custom virglrenderer";

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
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = final: prev: {

        # 1. Build your custom virglrenderer separately
        virglrenderer = prev.virglrenderer.overrideAttrs (oldAttrs: {
          version = "git-${virglrenderer-src.shortRev or "dirty"}";
          src = virglrenderer-src;

          patches = (oldAttrs.patches or [ ]) ++ [
            ./virglrenderer-xe-native-context.patch
          ];

          mesonFlags = (oldAttrs.mesonFlags or [ ]) ++ [
            "-Ddrm-renderers=xe-experimental"
          ];
        });

        # 2. Build QEMU using the virglrenderer defined above
        qemu-custom = (prev.qemu.override {
          # This forces QEMU to use the custom package from this overlay
          virglrenderer = final.virglrenderer;

          # Full graphics/audio stack
          virglSupport     = true;
          openGLSupport    = true;
          sdlSupport       = true;
          gtkSupport       = true;
          vncSupport       = true;
          spiceSupport     = true;
          usbredirSupport  = true;
          pulseSupport     = true;
          pipewireSupport  = true;
          alsaSupport      = true;
          numaSupport      = true;
          seccompSupport   = true;
          smartcardSupport = true;
          tpmSupport       = true;
          uringSupport     = true;
          fuseSupport      = true;
          capstoneSupport  = true;
          libiscsiSupport  = true;
        }).overrideAttrs (oldAttrs: {
          pname = "qemu-patched-git";
          version = "${nixpkgs.lib.substring 0 8 qemu-src.lastModifiedDate}-${qemu-src.shortRev or "dirty"}";
          src = qemu-src;

          patches = (oldAttrs.patches or [ ]) ++ [
            ./qemu-all-in-one.patch
          ];

          preConfigure = ''
            touch .git
            mkdir -p subprojects
            cp -a ${inputs.keycodemapdb} subprojects/keycodemapdb
            cp -a ${inputs.berkeley-softfloat-3} subprojects/berkeley-softfloat-3
            cp -a ${inputs.berkeley-testfloat-3} subprojects/berkeley-testfloat-3
            chmod -R +w subprojects/
            cp -r subprojects/packagefiles/berkeley-softfloat-3/* subprojects/berkeley-softfloat-3/
            cp -r subprojects/packagefiles/berkeley-testfloat-3/* subprojects/berkeley-testfloat-3/
          '';

          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
            final.python3Packages.setuptools
            final.python3Packages.wheel
            final.python3Packages.pip
            final.git
            final.meson
            final.ninja
          ];

          configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
            "--disable-download"
          ];

          doCheck = false;
        });
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        in
        {
          # Now you can build either one independently
          default = pkgs.qemu-custom;
          qemu = pkgs.qemu-custom;
          virglrenderer = pkgs.virglrenderer;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            # Use 'inputsFrom' to get all build deps for virglrenderer 
            # if you want to develop inside the shell.
            inputsFrom = [ pkgs.virglrenderer ];
            buildInputs = [ pkgs.qemu-custom pkgs.virglrenderer ];
          };
        });
    };
}
