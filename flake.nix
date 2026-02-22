{
  description = "QEMU with VAAPI hardware acceleration and latency tweaks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      overlays.default = final: prev: {
        # We use 'prev.qemu' to grab the original, then 'overrideAttrs' to change it
        qemu = prev.qemu.overrideAttrs (oldAttrs: {
          pname = "qemu-patched";

          # The missing semicolon was here!
          patches = (oldAttrs.patches or [ ]) ++ [
            ./qemu-all-in-one.patch
          ];
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
          # Now 'pkgs.qemu' refers to your patched version
          default = pkgs.qemu;
          qemu-patched = pkgs.qemu;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.default ]; };
        in
        {
          default = pkgs.mkShell {
            # This puts your patched QEMU into the PATH of the shell
            buildInputs = [ pkgs.qemu ];
          };
        });
    };
}
