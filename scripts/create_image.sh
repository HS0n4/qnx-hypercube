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

mcopy -i "$OUTPUT_IMG" "$IMAGES/bzImage"                        ::bzImage
mcopy -i "$OUTPUT_IMG" "$IMAGES/rootfs.ext2"                    ::rootfs.ext4
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/start_linux_guest.sh"       ::start_linux_guest.sh
mcopy -i "$OUTPUT_IMG" "$QVM_SCRIPT/linux.qvmcfg"               ::linux.qvmcfg
# mcopy -i "$OUTPUT_IMG" "$SCRIPT_DIR/linux-fuzzer.qvmcfg"    ::linux-fuzzer.qvmcfg
# mcopy -i "$OUTPUT_IMG" "$SCRIPT_DIR/start_linux_guest.sh"   ::start_linux_guest.sh

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
