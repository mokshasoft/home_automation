# BeagleBone Black One-Time Setup

This guide covers the initial setup for flashing and deploying to the BeagleBone Black.

## Prerequisites

- BeagleBone Black with USB cable
- MicroSD card (any size, used only for initial bootstrap)
- Host machine with `make`, `dd`, `ssh`

## Initial Bootstrap (One-Time)

### 1. Flash SD Card

First, flash the Debian image to an SD card:

```bash
make download
make unpack
make flash SD_DEV=/dev/sdX   # Replace with your SD card device
```

### 2. Boot from SD Card

1. Insert the SD card into the BBB
2. **Hold the boot button** (S2, near the SD card slot)
3. Connect USB power
4. **Keep holding for ~5 seconds** until LEDs flash
5. Release the button

### 3. Connect via Serial Console

The new image doesn't have USB networking configured by default. Connect via serial:

```bash
screen /dev/ttyUSB0 115200
```

Default credentials:
- Username: `debian`
- Password: `temppwd` (you'll be prompted to change it on first login)

### 4. Configure USB Networking

Check that usb0 exists and has an IP:

```bash
ip addr show usb0
```

If no IP is assigned:

```bash
sudo ip addr add 192.168.7.2/24 dev usb0
```

To make this permanent, create `/etc/network/interfaces.d/usb0`:

```bash
sudo tee /etc/network/interfaces.d/usb0 << 'EOF'
auto usb0
iface usb0 inet static
    address 192.168.7.2
    netmask 255.255.255.0
EOF
```

### 5. Enable Passwordless Sudo

Required for remote deployment:

```bash
sudo visudo
```

Add at the end:

```
debian ALL=(ALL) NOPASSWD: ALL
```

### 6. Flash to eMMC

From your **host machine**:

```bash
cat bb-image/bb-debian.img | ssh debian@192.168.7.2 "sudo dd of=/dev/mmcblk1 bs=4M status=progress conv=fsync && sync"
```

This takes a few minutes. Once complete:

1. Power off the BBB
2. Remove the SD card
3. Power on - it will boot from eMMC

### 7. Repeat USB Network Setup on eMMC

After booting from eMMC, the USB network config needs to be set up again (same steps as #4 and #5 above).

## Updating the Image

After the one-time setup, you can reflash the eMMC anytime without an SD card:

### Option A: Reflash Entire Image

Build and flash a new image:

```bash
make create-bbb-image
cat bb-image/bb-debian.img | ssh debian@192.168.7.2 "sudo dd of=/dev/mmcblk1 bs=4M status=progress conv=fsync && sync"
ssh debian@192.168.7.2 "sudo reboot"
```

**Note:** You'll need to redo the USB network and sudo setup after a full reflash.

### Option B: Deploy Only Binaries (Recommended)

For iterating on the controller/monitor code, just deploy the binaries:

```bash
make deploy-local BBB_HOST=debian@192.168.7.2
```

This builds on the BBB and restarts the service. No reboot needed.

## Quick Reference

| Task | Command |
|------|---------|
| Serial console | `screen /dev/ttyUSB0 115200` |
| Deploy binaries | `make deploy-local BBB_HOST=debian@192.168.7.2` |
| Flash eMMC | `cat bb-image/bb-debian.img \| ssh debian@192.168.7.2 "sudo dd of=/dev/mmcblk1 bs=4M status=progress"` |
| Check boot device | `ssh debian@192.168.7.2 "lsblk"` |
| Restart controller | `ssh debian@192.168.7.2 "sudo systemctl restart growatt-controller"` |
| View controller logs | `ssh debian@192.168.7.2 "journalctl -u growatt-controller -f"` |
| Run monitor | `ssh debian@192.168.7.2 "monitor /dev/ttyUSB0"` |

## Troubleshooting

### No USB network on host

Check if the interface exists:

```bash
ip addr | grep 192.168.7
```

If missing, the BBB may not have USB gadget enabled. Use serial console.

### SSH host key changed

After reflashing:

```bash
ssh-keygen -R 192.168.7.2
```

### Can't boot from SD card

- Ensure you're holding the boot button **before** applying power
- Hold for at least 5 seconds
- Try a different SD card
