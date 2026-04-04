#!/bin/sh

HC_MNT=/tmp/ld_data

mkdir -p /data/hypervisor/linux
cp "$HC_MNT/bzImage"          /data/hypervisor/linux/
cp "$HC_MNT/linux.qvmcfg"     /data/hypervisor/linux/

QVM_CFG=/data/hypervisor/linux/linux.qvmcfg

echo "[LINUX] Setting up block device for Linux rootfs..."
# rootfs.ext4 is read directly from the FAT32 mount (/tmp/ld_data) — not copied
devb-loopback loopback prefix=lxdisk,fd=/tmp/ld_data/rootfs.ext4

echo "[LINUX] Setting up virtio-net peer (vp0 = 192.168.1.1)..."
# System name in qvmcfg is "linux-fuzzer"; vdev name is "net_g1"
mount -T io-pkt \
    -o peer=/dev/qvm/linux-fuzzer/net_g1,bind=/dev/vdevpeers/vp0 \
    devnp-vdevpeer-net.so && ifconfig vp0 192.168.1.1 up || \
    echo "  [warn] virtio-net peer not available"

qvm @"$QVM_CFG" 2>&1 | tee /tmp/qvm_crash.log
