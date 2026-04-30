#!/usr/bin/env python3
import argparse
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Hypercube"))

from scripts.compile import generate_config_header_file  # noqa: E402


MODES = {
    "virtio-net": dict(
        enable_virtio_net=True,
        target_filters=["virtio-net-regs", "virtio-net-vq"],
    ),
    "shmem": dict(
        enable_shmem=True,
        target_filters=["shmem"],
    ),
    "watchdog": dict(
        enable_watchdog=True,
        target_filters=["ib700-wdt"],
    ),
    "all": dict(
        enable_virtio_net=True,
        enable_shmem=True,
        target_filters=["virtio-net-regs", "virtio-net-vq", "shmem"],
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate HyperCube config.h for a predefined mode")
    parser.add_argument("mode", choices=sorted(MODES), help="fuzzing mode to generate")
    parser.add_argument("--debug", action="store_true", default=True, help="enable debug logging")
    args = parser.parse_args()

    config = generate_config_header_file(debug=args.debug, **MODES[args.mode])
    dest = ROOT / "Hypercube" / "config.h"
    dest.write_text(config)
    print(f"[MODE] Wrote {dest} for mode={args.mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
