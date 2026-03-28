{
  description = "QEMU from git master with PAT patch";

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
  };

  outputs = { self, nixpkgs, qemu-src, ... }@inputs:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = final: prev: {
        qemu = prev.qemu.overrideAttrs (oldAttrs: {
          pname = "qemu-patched-git";
          
          # DYNAMIC VERSIONING:
          # This creates a version like: "10.2.91-git-20260329-770f50c"
          # It uses the base version, the date of the commit, and the short hash.
          version = "${nixpkgs.lib.substring 0 8 qemu-src.lastModifiedDate}-${qemu-src.shortRev or "dirty"}";

          src = qemu-src;

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
          default = pkgs.qemu;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ pkgs.qemu ];
          };
        });
    };
}
