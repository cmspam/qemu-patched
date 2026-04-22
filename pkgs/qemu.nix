{ prev, patchSrc, virglrenderer }:

(prev.qemu.override {
  inherit virglrenderer;

  virglSupport = true;
  openGLSupport = true;
  sdlSupport = true;
  gtkSupport = true;
  vncSupport = true;
  spiceSupport = true;
  usbredirSupport = true;

  pulseSupport = true;
  pipewireSupport = true;
  alsaSupport = true;

  numaSupport = true;
  seccompSupport = true;
  smartcardSupport = true;
  tpmSupport = true;
  uringSupport = true;
  fuseSupport = true;
  capstoneSupport = true;
  libiscsiSupport = true;
}).overrideAttrs (oldAttrs: rec {
  pname = "qemu-patched";
  version = "11.0.0";

  src = prev.fetchurl {
    url = "https://download.qemu.org/qemu-${version}.tar.xz";
    hash = "sha256-wEyjYBJlPzLRHGdNNwz1KnEOfT8Ywti2PkkyBSpIVNY";
  };

  patches = (oldAttrs.patches or []) ++ [
    "${patchSrc}/qemu-all-in-one.patch"
  ];

  nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
    prev.python3Packages.setuptools
    prev.python3Packages.wheel
    prev.python3Packages.pip
  ];

  configureFlags = (oldAttrs.configureFlags or []) ++ [
    "--disable-download"
  ];
})
