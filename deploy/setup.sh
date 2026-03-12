#!/bin/bash
# Setup script for Growatt controller on Armbian
# Run this on the BeagleBone Black

set -e

echo "Installing libmodbus..."
apt-get update
apt-get install -y libmodbus5

echo "Installing controller binary..."
cp controller /usr/local/bin/
chmod +x /usr/local/bin/controller

echo "Installing systemd service..."
cp growatt-controller.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable growatt-controller

echo "Done! Start with: systemctl start growatt-controller"
echo "View logs with: journalctl -u growatt-controller -f"
