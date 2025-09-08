# Makefile for BeagleBone Black automation on Fedora host

DOWNLOAD_DIR = ./downloads
IMAGE_URL = https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-debian-12.11-base-v6.15-armhf-2025-08-08-4gb.img.xz
IMAGE_CHECKSUM_URL = https://files.beagle.cc/file/beagleboard-public-2021/images/am335x-debian-12.11-base-v6.15-armhf-2025-08-08-4gb.img.xz.sha256sum
IMAGE_FILE = $(DOWNLOAD_DIR)/bb-debian.img.xz
IMAGE_CHECKSUM_FILE = $(DOWNLOAD_DIR)/bb-debian.img.xz.sha256sum
TARGET_IMG_DIR = ./bb-image
TARGET_IMG = $(TARGET_IMG_DIR)/bb-debian.img
MOUNT_DIR = ./mnt
SYSTEMD_DIR = ./systemd
# dnf install qemu-user-static-arm (on Fedora)
QEMU_BIN = $(shell which qemu-arm-static)
QEMU = qemu-system-arm

create-bbb-image: download unpack mount setup-resolv broker led-service growatt-mqtt unmount
	@echo "Wrote BeagleBone Black ISO to $(TARGET_IMG)"

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


# 5. Install MQTT broker (Mosquitto) via chroot
broker:
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "apt update && apt install -y mosquitto"
	# Enable the service inside chroot
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable mosquitto.service"

# 6. Install LED blinker service
led-service:
	@echo "Copying LED blinker script and service into image..."
	sudo mkdir -p $(MOUNT_DIR)/opt/bbb
	sudo cp src/blink/led_blink.py $(MOUNT_DIR)/opt/bbb/
	sudo chmod +x $(MOUNT_DIR)/opt/bbb/led_blink.py
	sudo cp src/blink/led-blink.service $(MOUNT_DIR)/etc/systemd/system/
	# Enable the service inside chroot
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable led-blink.service"

# Install Growatt MQTT
growatt-mqtt:
	@echo "Copying Growatt MQTT script and service into image..."
	sudo mkdir -p $(MOUNT_DIR)/opt/bbb
	sudo mkdir -p $(MOUNT_DIR)/etc/default
	sudo cp src/inverter/growatt_mqtt.py $(MOUNT_DIR)/opt/bbb/
	sudo chmod +x $(MOUNT_DIR)/opt/bbb/growatt_mqtt.py
	sudo cp src/inverter/growatt-mqtt.service $(MOUNT_DIR)/etc/systemd/system/
	sudo cp src/inverter/.env $(MOUNT_DIR)/etc/default/growatt-mqtt
	# Enable the service inside chroot
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable growatt-mqtt.service"

# 7. Unmount filesystem
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
