#!/bin/bash
# create_image.sh
# Build a FAT32 disk image containing bzImage + rootfs + qvm config
# for the plain Linux guest (linux-data.img, passed to QEMU as drv1 = /dev/hd1 in QNX).

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_IMG="$ROOT/buildroot/linux-data.img"
IMAGES="$ROOT/buildroot/output/images"
QVM_SCRIPT="$ROOT/scripts"

dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=600 status=progress
mformat -F -i "$OUTPUT_IMG" ::

# --- Build PoC and inject into rootfs ---
POC_SRC="$ROOT/../exploit_research/poc_bug4_race.c"
ROOTFS_ORIG="$IMAGES/rootfs.ext2"
ROOTFS="$IMAGES/rootfs-linux.ext2"

if [ -f "$POC_SRC" ]; then
    echo "[POC] Cross-compiling poc_bug4_race..."
    CROSS_CC="${CROSS_CC:-$(which x86_64-buildroot-linux-uclibc-gcc 2>/dev/null || which x86_64-linux-gnu-gcc 2>/dev/null || echo gcc)}"
    "$CROSS_CC" -static -O2 -pthread -o /tmp/poc_bug4_race "$POC_SRC"
    strip /tmp/poc_bug4_race 2>/dev/null || true
    echo "[POC] Injecting into rootfs..."
    cp "$ROOTFS_ORIG" "$ROOTFS"
    debugfs -w "$ROOTFS" <<DBGEOF 2>/dev/null
rm /usr/bin/poc_bug4_race
write /tmp/poc_bug4_race /usr/bin/poc_bug4_race
set_inode_field /usr/bin/poc_bug4_race mode 0100755
DBGEOF
    # Also build and inject exploit
    EXPLOIT_SRC="$ROOT/../exploit_research/exploit_bug4_rce.c"
    if [ -f "$EXPLOIT_SRC" ]; then
        echo "[POC] Cross-compiling exploit_bug4_rce..."
        "$CROSS_CC" -static -O2 -pthread -o /tmp/exploit_bug4_rce "$EXPLOIT_SRC"
        strip /tmp/exploit_bug4_rce 2>/dev/null || true
        debugfs -w "$ROOTFS" <<DBGEOF2 2>/dev/null
rm /usr/bin/exploit_bug4_rce
write /tmp/exploit_bug4_rce /usr/bin/exploit_bug4_rce
set_inode_field /usr/bin/exploit_bug4_rce mode 0100755
DBGEOF2
        echo "[POC] exploit_bug4_rce injected."
    fi

    # Build and inject Bug #5 PoC
    BUG5_SRC="$ROOT/../exploit_research/poc_bug5_detach.c"
    if [ -f "$BUG5_SRC" ]; then
        echo "[POC] Cross-compiling poc_bug5_detach..."
        "$CROSS_CC" -static -O2 -o /tmp/poc_bug5_detach "$BUG5_SRC"
        strip /tmp/poc_bug5_detach 2>/dev/null || true
        debugfs -w "$ROOTFS" <<DBGEOF3 2>/dev/null
rm /usr/bin/poc_bug5_detach
write /tmp/poc_bug5_detach /usr/bin/poc_bug5_detach
set_inode_field /usr/bin/poc_bug5_detach mode 0100755
DBGEOF3
        echo "[POC] poc_bug5_detach injected."
    fi

    echo "[POC] Done."

# Remove the HyperCube auto-start init script so the Linux guest boots to a shell
debugfs -w "$ROOTFS" -R "rm /etc/init.d/S99hypercube" 2>/dev/null || true
echo "[IMG] Removed S99hypercube from Linux rootfs (boot to shell, not fuzzer)"
else
    echo "[POC] poc_bug4_race.c not found, using original rootfs"
    cp "$ROOTFS_ORIG" "$ROOTFS"
fi

mcopy -i "$OUTPUT_IMG" "$IMAGES/bzImage"                        ::bzImage
mcopy -i "$OUTPUT_IMG" "$ROOTFS"                                ::rootfs.ext4
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/start_linux_guest.sh"       ::start_linux_guest.sh
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/linux.qvmcfg"               ::linux.qvmcfg
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/victim.qvmcfg"              ::victim.qvmcfg
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/start_victim.sh"             ::start_victim.sh

echo "Files packed:"
mdir -i "$OUTPUT_IMG" ::

echo ""
echo "Done: $OUTPUT_IMG ($(du -sh "$OUTPUT_IMG" | cut -f1))"
echo ""
echo "On QNX host after boot:"
echo "  mkdir -p /tmp/ld_data && mount -t dos /dev/hd1 /tmp/ld_data"
echo "  mkdir -p /data/hypervisor/linux"
echo "  cp /tmp/ld_data/* /data/hypervisor/linux/"
echo "  sh /data/hypervisor/start_linux_guest.sh"
