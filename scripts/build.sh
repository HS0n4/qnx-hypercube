#!/bin/bash
# build.sh — Build all artifacts required for QNX Hypervisor fuzzing
#
# Build order:
#   1. Build hypercube_fuzzer (static x86_64 Linux binary)
#   2. Build buildroot Linux kernel + rootfs
#   3. Inject fuzzer into rootfs, pack into FAT32 data images
#
# Usage:
#   ./scripts/build.sh                 # build everything
#   ./scripts/build.sh --fuzzer-only   # build only the fuzzer binary
#   ./scripts/build.sh --linux-only    # build only the buildroot image
#   ./scripts/build.sh --images-only   # pack images only (steps 1+2 must be done)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HYPERCUBE="$ROOT/Hypercube"
BUILDROOT="$ROOT/buildroot"
SCRIPTS="$ROOT/scripts"

MODE="${1:-all}"

step()  { echo ""; echo "== $* =="; }
ok()    { echo "  ok $*"; }
fail()  { echo "  FAIL $*" >&2; exit 1; }
info()  { echo "  . $*"; }

# --- Build hypercube_fuzzer --------------------------------------------------
build_fuzzer() {
    step "Building hypercube_fuzzer"
    make -C "$HYPERCUBE/os/linux" clean all
    local bin="$HYPERCUBE/os/linux/hypercube_fuzzer"
    [ -f "$bin" ] || fail "hypercube_fuzzer not produced"
    ok "$(du -sh "$bin" | cut -f1)  $bin"
}

# --- Build Linux kernel + rootfs via buildroot --------------------------------
build_linux() {
    step "Building buildroot Linux image"
    make -C "$BUILDROOT"
    local imgs="$BUILDROOT/output/images"
    [ -f "$imgs/bzImage" ]     || fail "bzImage not found after build"
    [ -f "$imgs/rootfs.ext2" ] || fail "rootfs.ext2 not found after build"
    ok "bzImage:     $(du -sh "$imgs/bzImage" | cut -f1)"
    ok "rootfs.ext2: $(du -sh "$imgs/rootfs.ext2" | cut -f1)"
}

# --- Pack FAT32 data images ---------------------------------------------------
build_images() {
    step "Packing hypercube-data.img"
    "$SCRIPTS/create_hypercube_image.sh"
    ok "$(du -sh "$BUILDROOT/hypercube-data.img" | cut -f1)  hypercube-data.img"

    step "Packing linux-data.img"
    "$SCRIPTS/create_image.sh"
    ok "$(du -sh "$BUILDROOT/linux-data.img" | cut -f1)  linux-data.img"
}

# --- Dispatch -----------------------------------------------------------------
case "$MODE" in
    --fuzzer-only)  build_fuzzer ;;
    --linux-only)   build_linux  ;;
    --images-only)  build_images ;;
    all|*)
        build_fuzzer
        build_linux
        build_images
        echo ""
        echo "Build complete."
        info "hypercube-data.img : $(du -sh "$BUILDROOT/hypercube-data.img" | cut -f1)"
        info "linux-data.img     : $(du -sh "$BUILDROOT/linux-data.img" | cut -f1)"
        echo "Next: boot QNX with the generated images, then run /data/hypervisor/start_hypercube.sh"
        ;;
esac
