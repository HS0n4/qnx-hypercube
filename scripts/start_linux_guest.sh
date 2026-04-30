#!/bin/sh

set -eu

HC_MNT=/tmp/ld_data
QVM_CFG=/data/hypervisor/linux/linux.qvmcfg
QVM_PID_FILE=/tmp/linux_qvm.pid
QVM_LOG=/tmp/qvm_crash.log

fail() {
    echo "[LINUX] ERROR: $*" >&2
    exit 1
}

[ -f "$HC_MNT/rootfs.ext4" ] || fail "rootfs.ext4 not found in $HC_MNT"
[ -f "$HC_MNT/bzImage" ] || fail "bzImage not found in $HC_MNT"
[ -f "$HC_MNT/linux.qvmcfg" ] || fail "linux.qvmcfg not found in $HC_MNT"

mkdir -p /data/hypervisor/linux
cp "$HC_MNT/bzImage"          /data/hypervisor/linux/ || fail "copy bzImage"
cp "$HC_MNT/linux.qvmcfg"     /data/hypervisor/linux/ || fail "copy linux.qvmcfg"

echo "[LINUX] Setting up block device for Linux rootfs..."
# rootfs.ext4 is read directly from the FAT32 mount (/tmp/ld_data) — not copied
devb-loopback loopback prefix=lxdisk,fd=/tmp/ld_data/rootfs.ext4 || fail "devb-loopback failed"

echo "[LINUX] Setting up virtio-net peer (vp0 = 192.168.1.1)..."
# System name in qvmcfg is "linux-fuzzer"; vdev name is "net_g1"
mount -T io-pkt \
    -o peer=/dev/qvm/linux-fuzzer/net_g1,bind=/dev/vdevpeers/vp0 \
    devnp-vdevpeer-net.so && ifconfig vp0 192.168.1.1 up || \
    echo "  [warn] virtio-net peer not available"

sh -c 'echo $$ > "$1"; exec qvm @"$2" 2>&1' sh "$QVM_PID_FILE" "$QVM_CFG" | tee "$QVM_LOG"
QVM_STATUS=$?
rm -f "$QVM_PID_FILE"
echo "[LINUX] qvm exited (status=$QVM_STATUS)"
exit "$QVM_STATUS"
