{ prev, patchSrc }:

prev.virglrenderer.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or []) ++ [
    "${patchSrc}/virglrenderer-xe-native-context.patch"
  ];

  mesonFlags = (oldAttrs.mesonFlags or []) ++ [
    "-Ddrm-renderers=xe-experimental"
  ];
})
