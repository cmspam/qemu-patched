{
  description = "QEMU from git master with virglrenderer from git, PAT patch, and full graphics support";

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

        # virglrenderer built from git HEAD
        virglrenderer = prev.virglrenderer.overrideAttrs (oldAttrs: {
          version = "git-${virglrenderer-src.shortRev or virglrenderer-src.rev}";
          src = virglrenderer-src;
          patches = (oldAttrs.patches or [ ]) ++ [
            ./0001-virgl_video-support-non-mesa-vaapi-drivers.patch
          ];
          mesonFlags = (oldAttrs.mesonFlags or []) ++ [
           (lib.mesonBool "vaapi-all-drivers" vaapiSupport)
          ];

        });

        # QEMU built from git HEAD, using our git virglrenderer, with full graphics stack
        qemu = (prev.qemu.override {
          # Use our git virglrenderer
          virglrenderer    = final.virglrenderer;

          # Graphics / display
          virglSupport     = true;
          openGLSupport    = true;
          sdlSupport       = true;
          gtkSupport       = true;
          vncSupport       = true;
          spiceSupport     = true;
          usbredirSupport  = true;

          # Audio
          pulseSupport     = true;
          pipewireSupport  = true;
          alsaSupport      = true;

          # System / misc
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

            rm -rf build/meson-private
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
          default       = pkgs.qemu;
          qemu          = pkgs.qemu;
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
            buildInputs = [ pkgs.qemu pkgs.virglrenderer ];
          };
        });
    };
}
