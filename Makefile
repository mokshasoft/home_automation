# Makefile for BeagleBone Black automation on Fedora host

IMAGE_URL = https://debian.beagleboard.org/images/bb-debian-10.3-console-armhf-2020-04-06.img.xz
IMAGE_FILE = bb-debian.img.xz
TARGET_IMG_DIR = ./bb-image
MOUNT_DIR = ./mnt
SYSTEMD_DIR = ./systemd
QEMU_BIN = qemu-arm-static

all: download unpack mount broker systemd unmount

# 1. Download Debian ARM image
download:
	wget -O $(IMAGE_FILE) $(IMAGE_URL)

# 2. Extract the image
unpack:
	mkdir -p $(TARGET_IMG_DIR)
	unxz -c $(IMAGE_FILE) > $(TARGET_IMG_DIR)/bb-debian.img

# 3. Mount root filesystem with loopback
mount:
	sudo mkdir -p $(MOUNT_DIR)
	# Automatically find rootfs offset
	OFFSET=$$(fdisk -l $(TARGET_IMG_DIR)/bb-debian.img | grep Linux | awk 'NR==2 {print $$2 * 512}'); \
	sudo mount -o loop,offset=$$OFFSET $(TARGET_IMG_DIR)/bb-debian.img $(MOUNT_DIR)
	# Copy QEMU-arm for chroot
	sudo cp $(QEMU_BIN) $(MOUNT_DIR)/usr/bin/

# 5. Install MQTT broker (Mosquitto) via chroot
broker:
	sudo chroot $(MOUNT_DIR) $[QEMU_BIN] /bin/bash -c "apt update && apt install -y mosquitto"

# 6. Copy systemd files and enable services
systemd:
	sudo cp $(SYSTEMD_DIR)/* $(MOUNT_DIR)/etc/systemd/system/
	sudo chroot $(MOUNT_DIR) $(QEMU_BIN) /bin/bash -c "systemctl enable mosquitto.service"

# 7. Unmount filesystem
unmount:
	sudo umount $(MOUNT_DIR)

