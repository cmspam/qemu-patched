{ final, prev, virglrenderer-src, patchSrc }:

prev.virglrenderer.overrideAttrs (oldAttrs: {
  version = "git-${virglrenderer-src.shortRev or virglrenderer-src.rev}";
  src = virglrenderer-src;

  patches = (oldAttrs.patches or []) ++ [
    "${patchSrc}/virglrenderer-xe-native-context.patch"
  ];

  mesonFlags = (oldAttrs.mesonFlags or []) ++ [
    "-Ddrm-renderers=xe-experimental"
  ];
})
