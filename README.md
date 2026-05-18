# AI-Augmented Security Analysis of Inter-VM Communication on QNX Hypervisor

Capstone Project, Ho Chi Minh City University of Technology (HCMUT), 2026

This repository contains the build scripts, guest images, and orchestration artifacts used in our security analysis of the QNX Hypervisor 2.2 inter-VM communication stack. The project combines HyperCube-based fuzzing, Linux guest instrumentation, and QNX host automation to exercise shared-memory and virtual-device interfaces in a reproducible testbed.

The current repository focuses on the fuzzing testbed and execution pipeline. It packages the Linux-side fuzzer, Buildroot guest image, QNX launch scripts, and smoke-test workflow used to validate end-to-end execution on the hypervisor.

## Authors

- Dương Hoàng Khôi (2211672)
- Thịnh Trần Khánh Linh (2211862)
- Trương Anh Khôi (2211701)
- Mai Hải Sơn (2212940)

Academic Advisor: TS. Nguyễn An Khương (HCMUT)  

## Overview

The repository assembles a QNX Hypervisor fuzzing pipeline around two main components: a HyperCube-based Linux fuzzing target and a Buildroot-generated guest image. Supporting scripts automate image creation, QNX-side deployment, guest launch, and smoke testing so experiments can be reproduced on a KVM-backed host with a licensed QNX environment.

## Repository Structure

| Path | Contents |
|------|----------|
| `Hypercube/` | HyperCube fuzzer source tree as a git submodule |
| `buildroot/` | Buildroot-based Linux guest image source tree as a git submodule |
| `scripts/` | Build, packaging, QNX deployment, launch, and smoke-test scripts |
| `Makefile` | Top-level build entry points for the fuzzing workflow |

## Submodule Customizations

This repository relies on two pinned forks rather than stock upstream trees:

- `Hypercube/` at commit `028956f` from `HS0n4/Hypercube`
- `buildroot/` at commit `b793cbea84` from `HS0n4/buildroot`

The main customizations relevant to this toolchain are:

### Hypercube

- A Linux userspace port of the fuzzer was added under `os/linux/`, producing a static `hypercube_fuzzer` binary instead of requiring the original standalone guest-only flow.
- `os/linux/linux_main.c` adds Linux-side PCI enumeration, `/dev/mem` and `iopl(3)` based access, and signal-based crash recovery so fuzzing can continue after `SIGILL`, `SIGSEGV`, or `SIGBUS`.
- `os/src/virtio_net.c` was extended for QNX Hypervisor fuzzing, including virtio-net initialization, virtqueue setup, and registration of queue memory and device regions as fuzz targets.
- `os/src/shmem.c` adds support for both QEMU `ivshmem` and the QNX native shared-memory device, including the QNX factory-page attach protocol.
- QNX-specific guest configuration and usage notes were added in `docs/hypercube.qvmcfg` and `docs/qnx-hypervisor-usage.md`.
- The top-level workflow in this repository uses `scripts/configure_mode.py` to generate `Hypercube/config.h` for predefined modes such as `virtio-net`, `shmem`, `watchdog`, and `all`.

### Buildroot

- A dedicated board configuration was added for the QNX nested guest environment in `configs/qvm_x86_64_defconfig`.
- `board/qvm/x86_64/linux_qvm.fragment` enables only the kernel features needed by the fuzzer setup, such as serial console, legacy VirtIO PCI, ext filesystem support, `UIO`, `/proc/self/pagemap`, and permissive `/dev/mem` access, while disabling graphics and other boot-problematic subsystems.
- `board/qvm/x86_64/post-build.sh` builds and installs `hypercube_fuzzer` into the target rootfs, creates the `S99hypercube` auto-start script, removes `tty1` console entries, and ensures serial-root access through `ttyS0`.
- `board/qvm/x86_64/S41network` brings up `eth0` with a fixed guest-side address for the QNX `vdevpeer` network path.
- The resulting Buildroot image is therefore not a generic Linux guest image; it is tailored to boot cleanly under QNX Hypervisor and start the fuzzing binary automatically.

## Prerequisites

- Linux host with KVM enabled
- QNX SDP 7.1.0 and QNX Hypervisor 2.2 assets, obtained separately under the appropriate license
- `git`, `make`, `python3`, and standard Linux build tooling
- SSH access from the Linux host to the QNX host for automated deployment
- Optional reverse-engineering and analysis tools depending on the evaluation workflow

## Getting Started

Clone the repository and initialize the submodules:

```bash
git clone <repository-url>
cd qnx-hypercube
git submodule update --init --recursive
```

Build all Linux-side artifacts:

```bash
make build
```

This produces the main outputs used by the QNX workflow:

- `Hypercube/os/linux/hypercube_fuzzer`
- `buildroot/output/images/bzImage`
- `buildroot/output/images/rootfs.ext2`
- `buildroot/hypercube-data.img`
- `buildroot/linux-data.img`

During image packaging, working copies of the Buildroot filesystem are injected and then stored inside the FAT images under the runtime filename `rootfs.ext4`, which is the name expected by the QNX-side launch scripts.

Useful build targets:

```bash
make build-fuzzer
make build-linux
make build-images
make check-modes
make shmem-test
```

## Running on QNX Hypervisor

After the Linux-side artifacts are built, copy or expose the generated images to the QNX host and start the guest with the provided scripts.

Typical flow:

```bash
# From the Linux host
./scripts/setup-qnx.sh
```

On the QNX host, the runtime entry point is:

```bash
sh /data/hypervisor/start_hypercube.sh
```

To validate that the guest reaches the fuzzing loop:

```bash
./scripts/qnx_smoke_hypercube.sh
```

To monitor guest serial output from the Linux host:

```bash
make monitor
```

## Reproducibility

| Component | Self-contained | Notes |
|-----------|----------------|-------|
| Linux-side build pipeline | Partial | Reproducible after submodule initialization and host dependency setup |
| HyperCube fuzzer build | Partial | Depends on the `Hypercube/` submodule state |
| Buildroot guest image | Partial | Depends on the `buildroot/` submodule state and host toolchain |
| QNX deployment and launch | No | Requires licensed QNX SDP/Hypervisor environment |
| Vulnerability PoC artifacts | Withheld | Not included in this repository at the current disclosure stage |

## Disclosure Status

## License



## Citation

```
