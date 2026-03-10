# BeagleBone Black Serial Connection

## Hardware Required

- BeagleBone Black
- FTDI TTL-232R-3V3 USB-to-serial cable (6-pin)
- USB cable for powering the BBB

## FTDI Cable Pinout

| Pin | Color  | Function |
|-----|--------|----------|
| 1   | Black  | GND      |
| 2   | Brown  | CTS      |
| 3   | Red    | VCC      |
| 4   | Orange | TXD      |
| 5   | Yellow | RXD      |
| 6   | Green  | RTS      |

## Connecting to BeagleBone Black

The BBB has a 6-pin serial debug header called J1, located near the P9 header.

Plug the FTDI connector directly onto J1 with the **black wire towards the DC barrel jack**. Pin 1 on J1 is marked with a white dot on the PCB.

```
[DC Jack]  [J1 Header]        [P9]
            ┌──────┐
   Pin 1 →  │●○○○○○│  ← Pin 6
            └──────┘
            Black wire this end
```

## Serial Connection

1. Plug the FTDI USB into your computer

2. Check the device is recognized:
   ```bash
   ls /dev/ttyUSB*
   ```
   You should see `/dev/ttyUSB0` or similar.

3. Open a serial terminal (115200 baud):
   ```bash
   screen /dev/ttyUSB0 115200
   ```
   You may need `sudo` or membership in the `dialout` group.

4. Power the BeagleBone Black via USB or 5V barrel jack

5. You should see U-Boot messages, then Linux boot log, then a login prompt

## Default Credentials

- Username: `debian`
- Password: `temppwd`

## Screen Commands

| Action                      | Keys              |
|-----------------------------|-------------------|
| Detach (leave running)      | `Ctrl+a` then `d` |
| Kill session                | `Ctrl+a` then `k` |
| Reattach to session         | `screen -r`       |
| List running sessions       | `screen -ls`      |
