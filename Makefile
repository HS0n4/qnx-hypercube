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
#   make shmem-test   # build dedicated shmem verification image

ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
HYPERCUBE   := $(ROOT)/Hypercube
BUILDROOT := $(ROOT)/buildroot
SCRIPTS     := $(ROOT)/scripts
MODE        ?= all

.PHONY: all build build-fuzzer build-linux build-images \
        generate-config configure-buildroot monitor check-modes shmem-test clean help

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
	@echo "    make monitor        Monitor fuzzing via SSH (attach to running session)"
	@echo ""
	@echo "    make shmem-test     Build shmem-test-data.img for end-to-end shmem verification"
	@echo "    make clean          Remove build artifacts"
	@echo ""
	@echo "  Environment variables:"
	@echo "    SSH_PORT=2222  SSH_USER=root  SSH_KEY=<path>"
	@echo ""

all: build

build: build-linux build-fuzzer build-images

generate-config:
	@echo "[BUILD] Generating config.h (mode=$(MODE))..."
	cd $(ROOT) && python3 $(SCRIPTS)/configure_mode.py $(MODE)

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
	$(SCRIPTS)/create_image.sh
	$(SCRIPTS)/create_hypercube_image.sh

clean:
	$(MAKE) -C $(HYPERCUBE)/os/linux clean
	$(MAKE) -C $(BUILDROOT) clean
	rm -f $(HYPERCUBE)/config.h
	rm -f $(BUILDROOT)/hypercube-data.img
	rm -f $(BUILDROOT)/linux-data.img
	rm -f $(BUILDROOT)/shmem-test-data.img
	rm -f $(BUILDROOT)/output/qemu.pid
	rm -f $(BUILDROOT)/output/qemu.log

monitor:
	@echo "Monitor guest serial output from the QNX host, for example:"
	@echo "  ssh -p 2222 root@localhost 'tail -f /tmp/hc_serial.log'"

check-modes:
	@echo "[CHECK] Verifying basic modes (virtio-net, shmem, watchdog, all)..."
	$(SCRIPTS)/check_modes.sh
