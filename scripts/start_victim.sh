#!/bin/sh
# start_victim.sh - Start victim guest that attaches to hc_shmem
# Run AFTER start_linux_guest.sh (which creates the shmem region)

HC_MNT=/tmp/ld_data

mkdir -p /data/hypervisor/victim
cp "$HC_MNT/bzImage" /data/hypervisor/victim/
cp "$HC_MNT/victim.qvmcfg" /data/hypervisor/victim/

QVM_CFG=/data/hypervisor/victim/victim.qvmcfg

echo "[VICTIM] Copying rootfs for victim guest..."
cp /tmp/ld_data/rootfs.ext4 /tmp/victim_rootfs.ext4

echo "[VICTIM] Setting up block device for rootfs..."
devb-loopback loopback prefix=victdisk,fd=/tmp/victim_rootfs.ext4

echo "[VICTIM] Starting victim guest (attaches to hc_shmem)..."
echo "[VICTIM] Make sure linux guest is already running with shmem created"

qvm @"$QVM_CFG" 2>&1 | tee /tmp/qvm_victim.log
