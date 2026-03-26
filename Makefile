# QNX / HyperCube Fuzzing — top-level Makefile
#
# Repo layout:
#   Hypercube/       — bare-metal fuzzer OS + Linux userspace variant
#   buildroot/     	 — Buildroot Linux guest (bzImage + rootfs)
#   scripts/         — orchestration scripts (build / run / setup / monitor)
#   images/          — pre-built reference images + shmem test tools
#
# Quick start:
#   make build        # build all artifacts
#   make run          # launch QEMU with QNX Hypervisor
#   make fuzz         # full pipeline: build -> boot -> setup -> monitor
#   make shmem-test   # build dedicated shmem verification image

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
HYPERCUBE   := $(ROOT)/Hypercube
BUILDROOT := $(ROOT)/buildroot
SCRIPTS     := $(ROOT)/scripts

.PHONY: all build build-fuzzer build-linux build-images \
        generate-config configure-buildroot run fuzz monitor shmem-test clean help

help:
	@echo ""
	@echo "  QNX HyperCube Fuzzing"
	@echo ""
	@echo "  Targets:"
	@echo "    make build          Build everything (fuzzer + Linux image + FAT32 data images)"
	@echo "    make build-fuzzer   Build only hypercube_fuzzer (Linux binary)"
	@echo "    make build-linux    Build only buildroot (bzImage + rootfs)"
	@echo "    make build-images   Pack FAT32 data images only"
	@echo ""
	@echo "    make run            Launch QEMU with QNX Hypervisor (foreground)"
	@echo "    make fuzz           Full pipeline: build -> boot -> auto-setup -> monitor"
	@echo "    make monitor        Monitor fuzzing via SSH (attach to running session)"
	@echo ""
	@echo "    make shmem-test     Build shmem-test-data.img for end-to-end shmem verification"
	@echo "    make clean          Remove build artifacts"
	@echo ""
	@echo "  Environment variables:"
	@echo "    SSH_PORT=2222  SSH_USER=root  SSH_KEY=<path>  SKIP_BUILD=1"
	@echo ""

all: build

build: build-linux build-fuzzer build-images

generate-config:
	@echo "[BUILD] Generating config.h (virtio-net + shmem + watchdog)..."
	cd $(HYPERCUBE) && python3 -c "\
from scripts.compile import generate_config_header_file; \
cfg = generate_config_header_file(enable_virtio_net=True, enable_shmem=True, enable_watchdog=True, debug=True); \
open('config.h','w').write(cfg)"

build-fuzzer: generate-config
	@echo "[BUILD] hypercube_fuzzer..."
	$(MAKE) -C $(HYPERCUBE)/os/linux clean all

configure-buildroot:
	@if [ ! -f $(BUILDROOT)/.config ]; then \
		echo "[BUILD] Configuring buildroot (qvm_x86_64_defconfig)..."; \
		$(MAKE) -C $(BUILDROOT) qvm_x86_64_defconfig; \
	fi

build-linux: configure-buildroot
	@echo "[BUILD] buildroot Linux image..."
	$(MAKE) -C $(BUILDROOT)

build-images: build-fuzzer build-linux
	@echo "[BUILD] Packing FAT32 data images..."
	$(SCRIPTS)/create_hypercube_image.sh
	$(SCRIPTS)/create_image.sh

run:
	$(BUILDROOT)/run-qnx.sh

fuzz:
	$(SCRIPTS)/fuzz.sh

monitor:
	$(SCRIPTS)/monitor.sh

shmem-test:
	$(BUILDROOT)/create_shmem_test_image.sh

clean:
	$(MAKE) -C $(HYPERCUBE)/os/linux clean
	$(MAKE) -C $(BUILDROOT) clean
	rm -f $(HYPERCUBE)/config.h
	rm -f $(BUILDROOT)/hypercube-data.img
	rm -f $(BUILDROOT)/linux-data.img
	rm -f $(BUILDROOT)/shmem-test-data.img
	rm -f $(BUILDROOT)/output/qemu.pid
	rm -f $(BUILDROOT)/output/qemu.log
