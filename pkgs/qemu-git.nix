{ final, prev, qemu-src, patchSrc, inputs, virglrenderer }:

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
}).overrideAttrs (oldAttrs: {
  pname = "qemu-patched-git";
  version = "${prev.lib.substring 0 8 qemu-src.lastModifiedDate}-${qemu-src.shortRev or "dirty"}";
  src = qemu-src;

  patches = (oldAttrs.patches or []) ++ [
    "${patchSrc}/qemu-all-in-one.patch"
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

  nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
    final.python3Packages.setuptools
    final.python3Packages.wheel
    final.python3Packages.pip
    final.git
    final.meson
    final.ninja
  ];

  configureFlags = (oldAttrs.configureFlags or []) ++ [
    "--disable-download"
  ];

  doCheck = false;
})
