#!/bin/sh
# start_hypercube.sh — runs on QNX Hypervisor host
# Boot the Linux guest containing hypercube_fuzzer to fuzz virtio-net + shmem + IB700 WDT
#
# Serial output from the guest is written to $SERIAL_LOG.
# Monitor from Linux host:
#   ssh -p 2222 root@localhost 'tail -f /tmp/hc_serial.log'
#   or: make monitor

SERIAL_LOG=/tmp/hc_serial.log
QVM_PID_FILE=/tmp/hc_qvm.pid
HC_MNT=/tmp/hc_data
QVM_CFG=$HC_MNT/hypercube.qvmcfg

# --- Teardown previous instance if running ------------------------------------
if [ -f "$QVM_PID_FILE" ]; then
    OLD_PID=$(cat "$QVM_PID_FILE")
    kill "$OLD_PID" 2>/dev/null || true
    sleep 1
fi
slay -f devb-loopback 2>/dev/null || true
sleep 1

if [ ! -f "$HC_MNT/rootfs.ext4" ]; then
    echo "[HC] ERROR: rootfs.ext4 not found in $HC_MNT after mount"
    exit 1
fi
echo "[HC] Mounted OK: $(ls $HC_MNT)"

# Copy only small files (bzImage + qvmcfg), NOT rootfs.ext4 (64MB)
mkdir -p /data/hypervisor/hypercube
cp "$HC_MNT/bzImage"          /data/hypervisor/hypercube/
cp "$HC_MNT/hypercube.qvmcfg" /data/hypervisor/hypercube/
QVM_CFG=/data/hypervisor/hypercube/hypercube.qvmcfg

# --- Expose rootfs.ext4 as block device directly from FAT32 mount ------------
echo "[HC] Setting up block device for HyperCube rootfs..."
if ! devb-loopback loopback prefix=hcdisk,fd="$HC_MNT/rootfs.ext4" 2>&1; then
    echo "[HC] ERROR: devb-loopback failed"
    exit 1
fi

# --- Set up virtio-net peer ---------------------------------------------------
echo "[HC] Setting up virtio-net peer (hc_vp0 = 10.99.0.1)..."
mount -T io-pkt \
    -o peer=/dev/qvm/hypercube/hc_net,bind=/dev/vdevpeers/hc_vp0 \
    devnp-vdevpeer-net.so && ifconfig hc_vp0 10.99.0.1 up || \
    echo "  [warn] virtio-net peer not available — fuzzing continues without network mirror"

# --- Start HyperCube guest ----------------------------------------------------
echo "[HC] Starting HyperCube Linux guest..."
echo "[HC] Serial log: $SERIAL_LOG"
echo "[HC] Config:     $QVM_CFG"

# Run qvm in foreground — guest serial (vdev ser8250) is connected to
# this terminal's stdin/stdout, giving an interactive console.
echo "[HC] Starting guest — serial console attached to this terminal."
echo "[HC] Config: $QVM_CFG"
echo "[HC] Log:    $SERIAL_LOG"
qvm @"$QVM_CFG" 2>&1 | tee "$SERIAL_LOG"
echo "[HC] qvm exited (status=$?)"
sloginfo -s 2>/dev/null | tail -50 > /tmp/hc_slog_crash.txt && echo "[HC] slogger2 tail saved to /tmp/hc_slog_crash.txt"
