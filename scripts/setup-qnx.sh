#!/bin/bash
# setup-qnx.sh — Automate QNX Hypervisor post-boot setup via SSH
#
# Runs on the Linux host, SSHes into QNX Hypervisor to:
#   1. Mount hypercube-data.img (FAT32, drv2 = /dev/hd2 in QNX)
#   2. Copy bzImage + rootfs.ext4 + hypercube.qvmcfg to /data/hypervisor/hypercube/
#   3. Upload start_hypercube.sh (from linux_image/)
#   4. Start the fuzzer
#
# Environment variables:
#   SSH_PORT=2222   SSH_HOST=localhost   SSH_USER=root   SSH_KEY=<path>
#
# Disk layout in QEMU (run-qnx.sh):
#   /dev/hd0 = disk-qemu.vmdk    (QNX OS)
#   /dev/hd1 = linux-data.img    (plain Linux guest)
#   /dev/hd2 = hypercube-data.img (HyperCube fuzzer, FAT32 raw disk)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LINUX_IMAGE="$ROOT/linux_image"

SSH_PORT="${SSH_PORT:-2222}"
SSH_HOST="${SSH_HOST:-localhost}"
SSH_USER="${SSH_USER:-root}"
SSH_KEY="${SSH_KEY:-}"

_ssh_opts="-p $SSH_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o LogLevel=ERROR"
[ -n "$SSH_KEY" ] && _ssh_opts="$_ssh_opts -i $SSH_KEY"

do_ssh() { ssh $_ssh_opts "$SSH_USER@$SSH_HOST" "$@"; }
do_scp() { scp -P "$SSH_PORT" -o StrictHostKeyChecking=no -o LogLevel=ERROR \
               ${SSH_KEY:+-i "$SSH_KEY"} "$@"; }

echo "[setup] Uploading start_hypercube.sh to QNX..."
do_scp "$LINUX_IMAGE/start_hypercube.sh" "$SSH_USER@$SSH_HOST:/tmp/_start_hypercube.sh"

echo "[setup] Running setup on QNX Hypervisor..."
do_ssh 'bash -s' << 'QNXEOF'
set -e

HC_DATA_DEV=/dev/hd2            # 3rd IDE drive = hypercube-data.img (FAT32 raw disk)
HC_MNT=/tmp/hc_data_mnt
HC_DIR=/data/hypervisor/hypercube

echo "[QNX] -- Mounting HyperCube data disk ($HC_DATA_DEV) --"
mkdir -p "$HC_MNT"
# FAT32 raw disk (no partition table) — try /dev/hd2, then /dev/hd2t6 as fallback
mount -t dos "$HC_DATA_DEV" "$HC_MNT" 2>/dev/null || \
mount -t dos "${HC_DATA_DEV}t6" "$HC_MNT" 2>/dev/null || \
{ echo "  [warn] mount failed. Check available devices with: ls /dev/hd*"; exit 1; }

echo "[QNX] -- Copying files to $HC_DIR --"
mkdir -p "$HC_DIR"
cp "$HC_MNT/bzImage"           "$HC_DIR/"
cp "$HC_MNT/rootfs.ext4"       "$HC_DIR/"
cp "$HC_MNT/hypercube.qvmcfg"  "$HC_DIR/"
umount "$HC_MNT"

cp /tmp/_start_hypercube.sh   /data/hypervisor/start_hypercube.sh
chmod +x /data/hypervisor/start_hypercube.sh

echo "[QNX] -- Files ready --"
ls -lh "$HC_DIR/"

echo "[QNX] -- Starting HyperCube fuzzer --"
sh /data/hypervisor/start_hypercube.sh
QNXEOF

echo "[setup] Done. Fuzzer started on QNX."
echo "  Monitor: make monitor   or   ./scripts/monitor.sh"
