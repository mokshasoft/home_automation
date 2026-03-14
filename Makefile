# Makefile for BeagleBone Black automation on Fedora host

DOWNLOAD_DIR = ./downloads
IMAGE_URL = https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-debian-13.3-base-v5.10-ti-armhf-2026-02-12-4gb.img.xz
IMAGE_CHECKSUM_URL = https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-debian-13.3-base-v5.10-ti-armhf-2026-02-12-4gb.img.xz.sha256sum
IMAGE_FILE = $(DOWNLOAD_DIR)/bb-debian.img.xz
IMAGE_CHECKSUM_FILE = $(DOWNLOAD_DIR)/bb-debian.img.xz.sha256sum
TARGET_IMG_DIR = ./bb-image
TARGET_IMG = $(TARGET_IMG_DIR)/bb-debian.img
MOUNT_DIR = ./mnt
SYSTEMD_DIR = ./systemd
# dnf install qemu-user-static-arm (on Fedora)
QEMU_BIN = $(shell which qemu-arm-static)
QEMU = qemu-system-arm

# SD card device for flashing (override with: make flash SD_DEV=/dev/sdX)
SD_DEV ?= /dev/mmcblk0

# BeagleBone Black SSH connection (override with: make deploy BBB_HOST=user@host)
BBB_HOST ?= debian@192.168.7.2

create-bbb-image: download unpack mount setup-resolv led-service controller-service fixup-fstab unmount
	@echo "Wrote BeagleBone Black image to $(TARGET_IMG)"

# 1. Download Debian ARM image
download:
	mkdir -p $(DOWNLOAD_DIR)
	@if [ ! -f $(IMAGE_FILE) ]; then \
		wget -O $(IMAGE_FILE) $(IMAGE_URL); \
	else \
		echo "$(IMAGE_FILE) already exists, skipping download."; \
	fi
	@if [ ! -f $(IMAGE_CHECKSUM_FILE) ]; then \
		wget -O $(IMAGE_CHECKSUM_FILE) $(IMAGE_CHECKSUM_URL); \
	else \
		echo "$(IMAGE_CHECKSUM_FILE) already exists, skipping download."; \
	fi

# 2. Extract the image
unpack:
	mkdir -p $(TARGET_IMG_DIR)
	unxz -c $(IMAGE_FILE) > $(TARGET_IMG)

# 3. Mount root filesystem with loopback
mount:
	sudo mkdir -p $(MOUNT_DIR)
	# Automatically find rootfs offset
	OFFSET=$$(fdisk -l $(TARGET_IMG) | grep Linux | awk 'NR==2 {print $$2 * 512}'); \
	sudo mount -o loop,offset=$$OFFSET $(TARGET_IMG) $(MOUNT_DIR)
	# Copy QEMU-arm for chroot
	sudo cp $(QEMU_BIN) $(MOUNT_DIR)/usr/bin/

# 4. Put a working resolv.conf inside the chroot
setup-resolv:
	# Remove the symlink if it exists
	sudo rm -f $(MOUNT_DIR)/etc/resolv.conf
	# Write a static DNS file with the desired nameservers
	@echo "nameserver 8.8.8.8" | sudo tee $(MOUNT_DIR)/etc/resolv.conf > /dev/null
	@echo "nameserver 1.1.1.1" | sudo tee -a $(MOUNT_DIR)/etc/resolv.conf > /dev/null


# 5. Install LED blinker service
led-service:
	@echo "Copying LED blinker script and service into image..."
	sudo mkdir -p $(MOUNT_DIR)/opt/bbb
	sudo cp app/blink/led_blink.py $(MOUNT_DIR)/opt/bbb/
	sudo chmod +x $(MOUNT_DIR)/opt/bbb/led_blink.py
	sudo cp app/blink/led-blink.service $(MOUNT_DIR)/etc/systemd/system/
	# Enable the service inside chroot
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable led-blink.service"

# 6. Install C Controller and Monitor
controller-service:
	@echo "Installing C controller and monitor..."
	# Install build dependencies in the image
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "apt update && apt install -y build-essential libmodbus-dev"
	# Copy source code to image for building
	sudo mkdir -p $(MOUNT_DIR)/tmp/controller-c
	sudo cp app/controller-c/*.c app/controller-c/*.h app/controller-c/Makefile $(MOUNT_DIR)/tmp/controller-c/
	# Build inside chroot
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "cd /tmp/controller-c && make clean && make"
	# Install the binaries
	sudo cp $(MOUNT_DIR)/tmp/controller-c/controller $(MOUNT_DIR)/usr/local/bin/controller
	sudo cp $(MOUNT_DIR)/tmp/controller-c/monitor $(MOUNT_DIR)/usr/local/bin/monitor
	sudo chmod +x $(MOUNT_DIR)/usr/local/bin/controller $(MOUNT_DIR)/usr/local/bin/monitor
	# Clean up build directory
	sudo rm -rf $(MOUNT_DIR)/tmp/controller-c
	# Copy and enable service
	sudo cp deploy/growatt-controller.service $(MOUNT_DIR)/etc/systemd/system/
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable growatt-controller.service"

# 7. Fix fstab for eMMC boot
# BBB eMMC is always mmcblk1 (not mmcblk0), even without SD card
fixup-fstab:
	@echo "Fixing fstab for eMMC boot (mmcblk0 -> mmcblk1)..."
	sudo sed -i 's/mmcblk0/mmcblk1/g' $(MOUNT_DIR)/etc/fstab

# 8. Unmount filesystem
unmount:
	sudo umount $(MOUNT_DIR)

chroot-interactive:
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash

run-qemu:
	$(QEMU) \
		-M versatilepb \
		-cpu cortex-a8 \
		-m 256M \
		-kernel zImage-versatilepb \
		-append "root=/dev/sda2 rw console=ttyAMA0" \
		-hda ./bb-image/bb-debian.img \
		-nographic \
		-net nic -net user,hostfwd=tcp::2222-:22

# Flash image to SD card
# Usage: make flash SD_DEV=/dev/sdX
flash:
	@echo "Flashing $(TARGET_IMG) to $(SD_DEV)..."
	@echo "WARNING: This will overwrite all data on $(SD_DEV)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	sudo dd if=$(TARGET_IMG) of=$(SD_DEV) bs=4M status=progress conv=fsync
	sudo sync
	@echo "Flash complete. Safe to remove SD card."

# Flash image to BBB eMMC over SSH
# Usage: make flash-emmc BBB_HOST=debian@192.168.7.2
# Note: Requires passwordless sudo on BBB (see docs/bbb-setup.md)
flash-emmc:
	@echo "Flashing $(TARGET_IMG) to eMMC on $(BBB_HOST)..."
	@echo "WARNING: This will overwrite the eMMC on the BeagleBone Black"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "Copying image to BBB (this may take a few minutes)..."
	cat $(TARGET_IMG) | ssh $(BBB_HOST) "sudo dd of=/dev/mmcblk1 bs=4M status=progress conv=fsync && sync"
	@echo "Flash complete. Reboot to apply: ssh $(BBB_HOST) 'sudo reboot'"

# Deploy binaries to running BBB via SSH (no reboot needed)
# Usage: make deploy BBB_HOST=root@192.168.7.2
deploy: deploy-build deploy-copy deploy-restart

# Build for ARM inside chroot (reuses mounted image)
deploy-build:
	@echo "Building controller and monitor for ARM..."
	@if [ ! -d "$(MOUNT_DIR)/tmp" ]; then \
		echo "Error: Image not mounted. Run 'make mount' first or use 'make deploy-local' if BBB has build tools."; \
		exit 1; \
	fi
	sudo mkdir -p $(MOUNT_DIR)/tmp/controller-c
	sudo cp app/controller-c/*.c app/controller-c/*.h app/controller-c/Makefile $(MOUNT_DIR)/tmp/controller-c/
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "cd /tmp/controller-c && make clean && make"
	mkdir -p ./build
	cp $(MOUNT_DIR)/tmp/controller-c/controller $(MOUNT_DIR)/tmp/controller-c/monitor ./build/
	sudo rm -rf $(MOUNT_DIR)/tmp/controller-c
	@echo "Binaries built in ./build/"

# Copy binaries to BBB
deploy-copy:
	@echo "Copying binaries to $(BBB_HOST)..."
	scp ./build/controller ./build/monitor $(BBB_HOST):/tmp/
	ssh $(BBB_HOST) "sudo cp /tmp/controller /tmp/monitor /usr/local/bin/ && sudo chmod +x /usr/local/bin/controller /usr/local/bin/monitor"
	scp deploy/growatt-controller.service $(BBB_HOST):/tmp/
	ssh $(BBB_HOST) "sudo cp /tmp/growatt-controller.service /etc/systemd/system/"

# Restart service on BBB
deploy-restart:
	@echo "Restarting controller service on $(BBB_HOST)..."
	ssh $(BBB_HOST) "sudo systemctl daemon-reload && sudo systemctl restart growatt-controller.service"
	@echo "Deploy complete."

# Build on BBB directly (if it has build-essential and libmodbus-dev)
# Usage: make deploy-local BBB_HOST=debian@192.168.7.2
deploy-local:
	@echo "Building and deploying on $(BBB_HOST)..."
	ssh $(BBB_HOST) "mkdir -p /tmp/controller-c"
	scp app/controller-c/*.c app/controller-c/*.h app/controller-c/Makefile $(BBB_HOST):/tmp/controller-c/
	ssh $(BBB_HOST) "cd /tmp/controller-c && make clean && make && sudo cp controller monitor /usr/local/bin/ && rm -rf /tmp/controller-c"
	scp deploy/growatt-controller.service $(BBB_HOST):/tmp/
	ssh $(BBB_HOST) "sudo cp /tmp/growatt-controller.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl restart growatt-controller.service"
	@echo "Deploy complete."

# Quick copy of pre-built binaries (if already built for ARM)
# Usage: make deploy-quick BBB_HOST=debian@192.168.7.2
deploy-quick:
	@echo "Copying pre-built binaries to $(BBB_HOST)..."
	scp ./build/controller ./build/monitor $(BBB_HOST):/tmp/
	ssh $(BBB_HOST) "sudo cp /tmp/controller /tmp/monitor /usr/local/bin/ && sudo systemctl restart growatt-controller.service"
	@echo "Deploy complete."

.PHONY: create-bbb-image download unpack mount setup-resolv led-service controller-service fixup-fstab unmount
.PHONY: chroot-interactive run-qemu flash flash-emmc
.PHONY: deploy deploy-build deploy-copy deploy-restart deploy-local deploy-quick
