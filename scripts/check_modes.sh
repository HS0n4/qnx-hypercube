#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT=$(dirname "$SCRIPT_DIR")

. "$SCRIPT_DIR/common.sh"

MODES="virtio-net shmem watchdog all"

step "Checking basic fuzzing modes"
for mode in $MODES; do
    step "Mode: $mode"
    run_step "generate config" python3 "$SCRIPT_DIR/configure_mode.py" "$mode"
    require_file "$ROOT/Hypercube/config.h"
    run_step "build Linux userspace fuzzer" make -C "$ROOT/Hypercube/os/linux" clean all
    require_file "$ROOT/Hypercube/os/linux/hypercube_fuzzer"
done

step "Mode checks completed"
info "Verified modes: $MODES"
