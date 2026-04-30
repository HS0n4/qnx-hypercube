#!/bin/sh
# Run on the QNX host after hypercube-data.img is mounted and copied.
# This script starts the HyperCube guest and waits for the Linux fuzzer
# to reach the fuzzing loop, using the serial log as the readiness signal.

set -eu

START_SCRIPT=${START_SCRIPT:-/data/hypervisor/start_hypercube.sh}
SERIAL_LOG=${SERIAL_LOG:-/tmp/hc_serial.log}
SMOKE_LOG=${SMOKE_LOG:-/tmp/hc_smoke.log}
TIMEOUT_SEC=${TIMEOUT_SEC:-60}
POLL_SEC=${POLL_SEC:-1}

fail() {
    echo "[SMOKE] ERROR: $*" >&2
    exit 1
}

[ -x "$START_SCRIPT" ] || fail "start script is not executable: $START_SCRIPT"

rm -f "$SERIAL_LOG" "$SMOKE_LOG"

echo "[SMOKE] starting HyperCube guest via $START_SCRIPT"
sh "$START_SCRIPT" >"$SMOKE_LOG" 2>&1 &
SMOKE_PID=$!

cleanup() {
    if kill -0 "$SMOKE_PID" 2>/dev/null; then
        kill "$SMOKE_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

elapsed=0
while [ "$elapsed" -lt "$TIMEOUT_SEC" ]; do
    if [ -f "$SERIAL_LOG" ]; then
        if grep -q "Starting fuzzing loop" "$SERIAL_LOG"; then
            echo "[SMOKE] PASS: guest reached fuzzing loop"
            exit 0
        fi

        if grep -q "No fuzz areas registered" "$SERIAL_LOG"; then
            fail "guest booted but registered no fuzz areas"
        fi

        if grep -q "Kernel Panic" "$SERIAL_LOG"; then
            fail "guest hit kernel panic before fuzzing loop"
        fi
    fi

    if ! kill -0 "$SMOKE_PID" 2>/dev/null; then
        fail "start script exited before readiness; inspect $SMOKE_LOG and $SERIAL_LOG"
    fi

    sleep "$POLL_SEC"
    elapsed=$((elapsed + POLL_SEC))
done

fail "timeout after ${TIMEOUT_SEC}s waiting for serial readiness marker"
