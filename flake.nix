{
  description = "QEMU with VAAPI hardware acceleration and latency tweaks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      # Add or remove systems as needed
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # This allows you to use the overlay in your NixOS configuration
      overlays.default = self: super: {
        qemu = super.qemu.overrideAttrs (oldAttrs: rec {
          pname = "qemu-patched";
          version = "10.2.0";

          src = super.fetchurl {
            url = "https://download.qemu.org/qemu-${version}.tar.xz";
            hash = "sha256-njCtG4ufe0RjABWC0aspfznPzOpdCFQMDKbWZyeFiDo=";
          };

    patches = (oldAttrs.patches or [ ]) ++ [
      (super.writeText "vaapi_smart.patch" ''
        --- a/hw/display/virtio-gpu-virgl.c
        +++ b/hw/display/virtio-gpu-virgl.c
        @@ -17,6 +17,13 @@
         #include "hw/virtio/virtio-gpu-pixman.h"
         #include "ui/egl-helpers.h"
         
        +extern int qemu_drm_rendernode_open(const char *rendernode);
        +static int virgl_get_drm_fd(void *opaque)
        +{
        +    /* Respect VAAPI_DEVICE env var, fallback to NULL (auto) if not set */
        +    return qemu_drm_rendernode_open(getenv("VAAPI_DEVICE"));
        +}
        +
         #include <virglrenderer.h>
         
         struct virtio_gpu_virgl_resource {
        @@ -1077,6 +1084,7 @@
         #else
             .version             = 1,
         #endif
        +    .get_drm_fd          = virgl_get_drm_fd,
         };
         
         static void virtio_gpu_print_stats(void *opaque)
        @@ -1145,6 +1151,7 @@
             int ret;
             uint32_t flags = 0;
             VirtIOGPUGL *gl = VIRTIO_GPU_GL(g);
        +    flags |= VIRGL_RENDERER_USE_VIDEO;
         
         #if VIRGL_RENDERER_CALLBACKS_VERSION >= 4
             if (qemu_egl_display) {
      '')
    ];

          postPatch = (oldAttrs.postPatch or "") + ''
            # 1. Add stdlib
            sed -i '/#include "qemu\/osdep.h"/a #include <stdlib.h>' hw/display/edid-generate.c

            # 2. Dynamic Refresh Rate logic
            sed -i 's/uint32_t refresh_rate = info->refresh_rate ? info->refresh_rate : .*;/ \
                uint32_t refresh_rate = 60000; \
                char *env_refresh = getenv("QEMU_REFRESH_RATE"); \
                if (env_refresh \&\& *env_refresh) { \
                    refresh_rate = (uint32_t)strtoul(env_refresh, NULL, 10); \
                    fprintf(stderr, "VIRTIO-GPU: EDID Rate set to %u mHz\\n", refresh_rate); \
                } else if (info->refresh_rate) { \
                    refresh_rate = info->refresh_rate; \
                }/' hw/display/edid-generate.c

            # 3. HID & UI Latency tweaks
            sed -i 's/.bInterval               = 0x0a/.bInterval               = 0x01/g' hw/usb/dev-hid.c
            sed -i 's/.bInterval               = 7, \/\* 2 ^ (8-1)/.bInterval               = 1, \/\* 2 ^ (8-7)/g' hw/usb/dev-hid.c
            sed -i 's/#define GUI_REFRESH_INTERVAL_DEFAULT    30/#define GUI_REFRESH_INTERVAL_DEFAULT    1/' include/ui/console.h

            # 4. Meson Fix
            sed -i "/get_option('virglrenderer'))/a \ \nif virgl.found()\n  virgl = declare_dependency(compile_args: '-DVIRGL_RENDERER_UNSTABLE_APIS', dependencies: virgl)\nendif" meson.build
          '';
        });
      };

      # The package exposed by the flake
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
            config.allowUnfree = true;
          };
        in
        {
          qemu-patched = pkgs.qemu;
          default = pkgs.qemu;
        });

      # Development shell for testing the build locally
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ self.packages.${system}.default ];
          };
        });
    };
}
