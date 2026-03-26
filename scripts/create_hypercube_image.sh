#!/bin/bash
# create_hypercube_image.sh
# Build a FAT32 disk image containing bzImage + rootfs.ext4 + qvm config
# for booting the HyperCube fuzzer as a Linux guest on QNX Hypervisor.
#
# Workflow:
#   1. Build hypercube_fuzzer (static) and inject into rootfs via debugfs
#   2. Pack bzImage + rootfs.ext4 + hypercube.qvmcfg + start script into FAT32 image
#   3. Image is passed to QEMU as drv2 (/dev/hd2 in QNX)
#
# After QNX boots, the image is mounted and copied automatically by setup-qnx.sh.
# Manual equivalent on QNX host:
#   mkdir -p /tmp/hc_data && mount -t dos /dev/hd2 /tmp/hc_data
#   mkdir -p /data/hypervisor/hypercube
#   cp /tmp/hc_data/bzImage /tmp/hc_data/rootfs.ext4 \
#      /tmp/hc_data/hypercube.qvmcfg /data/hypervisor/hypercube/
#   cp /tmp/hc_data/start_hypercube.sh /data/hypervisor/
#   chmod +x /data/hypervisor/start_hypercube.sh
#   sh /data/hypervisor/start_hypercube.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
HYPERCUBE_DIR="$ROOT/Hypercube"
BUILDROOT_IMAGES="$ROOT/buildroot/output/images"
OUTPUT_IMG="$ROOT/buildroot/hypercube-data.img"

# --- Step 1: Build hypercube_fuzzer and inject into rootfs -------------------
echo "[1/3] Building hypercube_fuzzer (static)..."
make -C "$HYPERCUBE_DIR/os/linux" clean all
strip "$HYPERCUBE_DIR/os/linux/hypercube_fuzzer"
echo "      Binary: $(du -sh "$HYPERCUBE_DIR/os/linux/hypercube_fuzzer" | cut -f1)"

echo "      Injecting into rootfs..."
ROOTFS="$BUILDROOT_IMAGES/rootfs.ext2"

debugfs -w "$ROOTFS" <<EOF 2>/dev/null
rm /usr/bin/hypercube_fuzzer
write $HYPERCUBE_DIR/os/linux/hypercube_fuzzer /usr/bin/hypercube_fuzzer
set_inode_field /usr/bin/hypercube_fuzzer mode 0100755
EOF
echo "      Done."

# --- Step 2: Create FAT32 disk image -----------------------------------------
# Sizing: bzImage (~11 MB) + rootfs (~64 MB) + buffer = 128 MB
echo "[2/3] Creating FAT32 disk image: $OUTPUT_IMG"
dd if=/dev/zero of="$OUTPUT_IMG" bs=1M count=128 status=progress
mformat -F -i "$OUTPUT_IMG" ::

mcopy -i "$OUTPUT_IMG" "$BUILDROOT_IMAGES/bzImage"              ::bzImage
mcopy -i "$OUTPUT_IMG" "$BUILDROOT_IMAGES/rootfs.ext2"          ::rootfs.ext4
mcopy -i "$OUTPUT_IMG" "$HYPERCUBE_DIR/docs/hypercube.qvmcfg"   ::hypercube.qvmcfg
# mcopy -i "$OUTPUT_IMG" "$SCRIPT_DIR/start_hypercube.sh"         ::start_hypercube.sh

echo "      Files packed:"
mdir -i "$OUTPUT_IMG" ::

# --- Step 3: Done ------------------------------------------------------------
echo "[3/3] Done: $OUTPUT_IMG ($(du -sh "$OUTPUT_IMG" | cut -f1))"
echo ""
echo "Next: launch QEMU with this image (it is already referenced by run-qnx.sh as drv2)"
echo ""
echo "Automated setup: make fuzz  (builds, boots QEMU, SSHes into QNX, starts fuzzer)"
echo ""
echo "Manual setup on QNX host after boot:"
echo "  mkdir -p /tmp/hc_data && mount -t dos /dev/hd2 /tmp/hc_data"
echo "  mkdir -p /data/hypervisor/hypercube"
echo "  cp /tmp/hc_data/bzImage /tmp/hc_data/rootfs.ext4 \\"
echo "     /tmp/hc_data/hypercube.qvmcfg /data/hypervisor/hypercube/"
echo "  cp /tmp/hc_data/start_hypercube.sh /data/hypervisor/"
echo "  chmod +x /data/hypervisor/start_hypercube.sh"
echo "  sh /data/hypervisor/start_hypercube.sh"
