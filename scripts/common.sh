#!/bin/sh

set -eu

step() {
    printf '\n== %s ==\n' "$*"
}

info() {
    printf '  . %s\n' "$*"
}

fail() {
    printf '  FAIL %s\n' "$*" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing file: $1"
}

require_dir() {
    [ -d "$1" ] || fail "missing directory: $1"
}

run_step() {
    desc="$1"
    shift
    info "$desc"
    "$@" || fail "$desc"
}
