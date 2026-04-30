#!/bin/bash
# fuzz.sh — Master fuzzing pipeline
#
# Pipeline:
#   1. Build artifacts (optional, skippable)
#   2. Launch QEMU with QNX Hypervisor (background)
#   3. Wait for QNX to boot and SSH to become available
#   4. Automate QNX setup via SSH (mount disk -> copy files -> start fuzzer)
#   5. Monitor serial log (foreground, Ctrl+C to detach)
#
# Usage:
#   ./scripts/fuzz.sh                  # full pipeline
#   ./scripts/fuzz.sh --skip-build     # skip build step
#   ./scripts/fuzz.sh --no-monitor     # start fuzzer without tailing the log
#   SKIP_BUILD=1 ./scripts/fuzz.sh     # same as --skip-build
#
# Environment variables:
#   SSH_PORT=2222   SSH_HOST=localhost   SSH_USER=root   SSH_KEY=<path>
#   SKIP_BUILD=0    QNX_BOOT_TIMEOUT=120

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/scripts"
LINUX_IMAGE="$ROOT/linux_image"

SSH_PORT="${SSH_PORT:-2222}"
SSH_HOST="${SSH_HOST:-localhost}"
SSH_USER="${SSH_USER:-root}"
SSH_KEY="${SSH_KEY:-}"
SKIP_BUILD="${SKIP_BUILD:-0}"
BOOT_TIMEOUT="${QNX_BOOT_TIMEOUT:-120}"

_ssh_opts="-p $SSH_PORT -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o LogLevel=ERROR"
[ -n "$SSH_KEY" ] && _ssh_opts="$_ssh_opts -i $SSH_KEY"

MONITOR=1
for arg in "$@"; do
    case "$arg" in
        --skip-build)   SKIP_BUILD=1 ;;
        --no-monitor)   MONITOR=0 ;;
        --help|-h)
            grep '^#' "$0" | head -20 | sed 's/^# \{0,1\}//'
            exit 0
            ;;
    esac
done

header() { echo ""; echo "+== $* ==+"; }

# --- Step 1: Build ------------------------------------------------------------
header "1/4  Build"
if [ "$SKIP_BUILD" = "0" ]; then
    "$SCRIPTS/build.sh"
else
    echo "  Skipped (SKIP_BUILD=1)"
    for img in hypercube-data.img linux-data.img; do
        [ -f "$LINUX_IMAGE/$img" ] || \
            { echo "  ERROR: $LINUX_IMAGE/$img not found. Run without --skip-build first."; exit 1; }
    done
fi

# --- Step 2: Launch QEMU ------------------------------------------------------
header "2/4  Launch QEMU"
mkdir -p "$LINUX_IMAGE/output"
QEMU_LOG="$LINUX_IMAGE/output/qemu.log"
QEMU_PID_FILE="$LINUX_IMAGE/output/qemu.pid"

# Stop any existing QEMU instance
if [ -f "$QEMU_PID_FILE" ]; then
    OLD_PID=$(cat "$QEMU_PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "  Stopping existing QEMU (PID $OLD_PID)..."
        kill "$OLD_PID"
        sleep 2
    fi
    rm -f "$QEMU_PID_FILE"
fi

# Launch QEMU in background, redirect output to log file
"$LINUX_IMAGE/run-qnx.sh" > "$QEMU_LOG" 2>&1 &
QEMU_BG_PID=$!
echo "  QEMU PID: $QEMU_BG_PID"
echo "  QEMU log: $QEMU_LOG"
echo "  (follow boot: tail -f $QEMU_LOG)"

# --- Step 3: Wait for QNX SSH -------------------------------------------------
header "3/4  Waiting for QNX SSH (port $SSH_PORT)"
ELAPSED=0
while ! ssh $_ssh_opts "$SSH_USER@$SSH_HOST" "echo ready" 2>/dev/null | grep -q ready; do
    if ! kill -0 "$QEMU_BG_PID" 2>/dev/null; then
        echo ""
        echo "  ERROR: QEMU exited unexpectedly. Check $QEMU_LOG"
        exit 1
    fi
    if [ "$ELAPSED" -ge "$BOOT_TIMEOUT" ]; then
        echo ""
        echo "  TIMEOUT after ${BOOT_TIMEOUT}s. QNX has not booted or SSH is not up."
        echo "  Hint: tail $QEMU_LOG"
        exit 1
    fi
    printf "\r  [%3ds/%ds] Waiting..." "$ELAPSED" "$BOOT_TIMEOUT"
    sleep 3
    ELAPSED=$((ELAPSED + 3))
done
echo ""
echo "  QNX SSH ready (${ELAPSED}s after launch)"

# --- Step 4: Setup QNX + Start Fuzzer -----------------------------------------
header "4/4  Setup QNX + Start HyperCube Fuzzer"
"$SCRIPTS/setup-qnx.sh"

# --- Monitor ------------------------------------------------------------------
if [ "$MONITOR" = "1" ]; then
    echo ""
    echo "Fuzzer started. Attaching monitor (Ctrl+C to detach, fuzzer keeps running)."
    echo "  Reconnect later: make monitor"
    echo ""
    "$SCRIPTS/monitor.sh"
else
    echo ""
    echo "Fuzzer started. To monitor:"
    echo "  make monitor   or   ssh -p $SSH_PORT $SSH_USER@$SSH_HOST 'tail -f /tmp/hc_serial.log'"
fi
