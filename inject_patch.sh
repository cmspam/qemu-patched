#!/usr/bin/env bash
# inject_patch.sh
# Modifies the Arch Linux QEMU PKGBUILD to include qemu-all-in-one.patch.
# Run from the directory containing the PKGBUILD and the patch file.
set -euo pipefail

PATCH_FILE="qemu-all-in-one.patch"
PKGBUILD="PKGBUILD"

if [[ ! -f "$PKGBUILD" ]]; then
    echo "ERROR: PKGBUILD not found in current directory"
    exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
    echo "ERROR: $PATCH_FILE not found in current directory"
    exit 1
fi

echo "Computing sha256sum for $PATCH_FILE..."
PATCH_SHA256=$(sha256sum "$PATCH_FILE" | awk '{print $1}')
echo "  sha256: $PATCH_SHA256"

# ── 1. Add patch to source array ─────────────────────────────────────────────
if grep -q "$PATCH_FILE" "$PKGBUILD"; then
    echo "Patch already present in source=(), skipping."
else
    # Find the closing ) of the source=() block and insert before it
    perl -i -0pe 's|(source=\(.*?)(\n\))|\1\n        '"'"'qemu-all-in-one.patch'"'"'\2|s' "$PKGBUILD"
    echo "Added $PATCH_FILE to source=()"
fi

# ── 2. Add sha256sum entry ────────────────────────────────────────────────────
if grep -q "$PATCH_SHA256" "$PKGBUILD"; then
    echo "sha256sum already present, skipping."
else
    perl -i -0pe "s|(sha256sums=\(.*?)(\n\))|\1\n        '$PATCH_SHA256'\2|s" "$PKGBUILD"
    echo "Added sha256sum for $PATCH_FILE"
fi

# ── 3. Add patch application to prepare() ────────────────────────────────────
PATCH_CMD="  patch -Np1 -i \"\${srcdir}/qemu-all-in-one.patch\""

if grep -q "qemu-all-in-one.patch" "$PKGBUILD" && \
   grep -A5 "prepare()" "$PKGBUILD" | grep -q "qemu-all-in-one"; then
    echo "Patch command already in prepare(), skipping."
elif grep -q "^prepare()" "$PKGBUILD"; then
    # prepare() exists — insert our line as the first command inside it
    perl -i -pe "s|^(prepare\(\) \{)\$|\$1\n${PATCH_CMD}|" "$PKGBUILD"
    echo "Injected patch command into existing prepare()"
else
    # No prepare() — create one before build()
    perl -i -0pe "s|(^build\(\))|prepare() {\n${PATCH_CMD}\n}\n\n\$1|m" "$PKGBUILD"
    echo "Created new prepare() function with patch command"
fi

echo ""
echo "=== inject_patch.sh complete. Relevant PKGBUILD lines: ==="
grep -n "qemu-all-in-one\|^prepare()\|^build()" "$PKGBUILD" | head -20
