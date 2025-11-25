# Hardware Connections Guide

## Overview

This document describes the hardware connections between the BeagleBone Black (BBB), relay modules, and Growatt inverters for the controller system.

## Relay Module Connection

### Module Specifications

- **Model**: 4-Channel Relay Module with Optocoupler Isolation
- **Link**: https://invize.se/produkt/mod-relay-4ch/
- **Input Voltage**: 5V DC
- **Trigger**: Configurable (Active-HIGH recommended)

### Why This Module is Safe for Direct Connection

The relay module includes built-in protection that eliminates the need for external components:

- ✅ **Optocoupler isolation** - Protects GPIO from relay kickback voltage
- ✅ **Built-in current limiting resistors** - On the input signal lines
- ✅ **Flyback diodes** - Protects against inductive voltage spikes
- ✅ **LED indicators** - Visual feedback for relay state

**Result**: GPIO pins can be connected directly to the module inputs without additional resistors or capacitors.

### Wiring Diagram

```
BeagleBone Black          4-Channel Relay Module
─────────────────         ──────────────────────
GPIO 66 (P8_7)  ────────→ IN1 (Phase 1)
GPIO 67 (P8_8)  ────────→ IN2 (Phase 2)
GPIO 68 (P8_9)  ────────→ IN3 (Phase 3)
                          IN4 (unused)
GND             ────────→ GND
5V (P9_7/P9_8)  ────────→ VCC
```

### GPIO Pin Reference (BeagleBone Black P8 Header)

| Phase   | GPIO Number | Header Pin | Relay Input |
|---------|-------------|------------|-------------|
| Phase 1 | GPIO 66     | P8_7       | IN1         |
| Phase 2 | GPIO 67     | P8_8       | IN2         |
| Phase 3 | GPIO 68     | P8_9       | IN3         |

Configure these in `src/Switch.hs` by modifying the `defaultPins` definition.

### Trigger Mode Configuration

**IMPORTANT**: Set the relay module to **Active-HIGH** trigger mode.

#### Why Active-HIGH?

Active-HIGH provides **fail-safe behavior**:

- GPIO HIGH (1) = Relay ON
- GPIO LOW (0) = Relay OFF

**Safety Benefits**:
1. **Controller failure**: If the controller crashes, GPIOs go LOW → relays turn OFF
2. **Power loss**: If BBB loses power, GPIOs go LOW → relays turn OFF
3. **Boot sequence**: GPIOs default to LOW → relays stay OFF until controller explicitly enables them
4. **Predictable defaults**: System defaults to safe state (all loads disconnected)

#### Configuration Jumper

Most relay modules have a jumper to select trigger mode:
- Set jumper to **"H"** or **"HIGH"** position
- Avoid **"L"** or **"LOW"** trigger mode (would invert behavior)

Some modules may label this as:
- "High Level Trigger" vs "Low Level Trigger"
- "Active High" vs "Active Low"

Consult your specific module's documentation if the jumper labels differ.

### Power Supply Considerations

1. **Relay coil voltage**: 5V DC (not 3.3V)
2. **GPIO signal voltage**: 3.3V (BBB GPIO output level)
3. **Module compatibility**: The optocoupler accepts 3.3V signals with 5V relay coils

#### Power Source Options

**Option 1: BeagleBone 5V Pin** (for light use)
- Use P9_7 or P9_8 (VDD_5V pins)
- Suitable for 1-2 relays switching simultaneously
- May be insufficient for all 4 relays at once

**Option 2: External 5V Supply** (recommended for production)
- Use dedicated 5V power supply
- Connect supply GND to BBB GND (common ground required)
- Provides stable voltage for all relays
- Recommended for switching multiple high-power loads

## Modbus RTU Connection (Growatt Inverters)

### Hardware Requirements

- **Adapters**: USB-to-RS485 converters (one per inverter)
- **Cable**: RS485 twisted pair cable
- **Connectors**: RJ45 or terminal blocks (depending on inverter model)

### Wiring

```
BeagleBone Black          USB-RS485 Adapter          Growatt Inverter
─────────────────         ──────────────────         ────────────────
USB Port        ────────→ USB Connector

                          RS485 A+        ────────→  Modbus A+ (485+)
                          RS485 B-        ────────→  Modbus B- (485-)
                          GND (optional)  ────────→  GND (if available)
```

### Default Serial Port Assignment

| Inverter   | USB Device    | Configure in                  |
|------------|---------------|-------------------------------|
| Inverter 1 | `/dev/ttyUSB0` | `app/ControllerMain.hs`      |
| Inverter 2 | `/dev/ttyUSB1` | `app/ControllerMain.hs`      |
| Inverter 3 | `/dev/ttyUSB2` | `app/ControllerMain.hs`      |

**Note**: USB device enumeration order may vary on boot. Consider using udev rules for persistent device names.

### Modbus Settings

Protocol configuration (defined in `src/Growatt.hs`):

- **Baud rate**: 9600
- **Parity**: None
- **Data bits**: 8
- **Stop bits**: 1
- **Device address**: 0

These match the Growatt inverter default Modbus RTU settings. Consult your inverter manual if settings have been changed.

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│ BeagleBone Black                                        │
│                                                         │
│  ┌──────────────┐      ┌──────────────┐                │
│  │  Controller  │─────→│  GPIO Pins   │────────┐       │
│  │   (Haskell)  │      │  66, 67, 68  │        │       │
│  └──────────────┘      └──────────────┘        │       │
│         │                                       │       │
│         │                                       │       │
│         ├───→ USB0 ────────────────┐            │       │
│         ├───→ USB1 ────────────────┼────┐       │       │
│         └───→ USB2 ────────────────┼────┼───┐   │       │
│                                    │    │   │   │       │
└────────────────────────────────────┼────┼───┼───┼───────┘
                                     │    │   │   │
                             ┌───────┘    │   │   │
                             │  ┌─────────┘   │   │
                             │  │  ┌──────────┘   │
                             ▼  ▼  ▼              ▼
                      ┌──────────────┐    ┌──────────────┐
                      │ USB-RS485 x3 │    │ Relay Module │
                      │   Adapters   │    │  (4-channel) │
                      └──────┬───────┘    └──────┬───────┘
                             │                   │
                    ┌────────┼────────┐          │
                    ▼        ▼        ▼          │
              ┌─────────┬─────────┬─────────┐    │
              │Inverter1│Inverter2│Inverter3│    │
              │(Modbus) │(Modbus) │(Modbus) │    │
              └─────────┴─────────┴─────────┘    │
                                                 │
                                        ┌────────┼────────┐
                                        ▼        ▼        ▼
                                   ┌────────┬────────┬────────┐
                                   │ Phase1 │ Phase2 │ Phase3 │
                                   │ Switch │ Switch │ Switch │
                                   └────────┴────────┴────────┘
```

## Safety Features

### Fail-Safe Design

1. **Default state**: All relays OFF
2. **Boot behavior**: GPIOs default LOW → relays remain OFF
3. **Controller crash**: GPIOs return to LOW → relays turn OFF
4. **Power loss**: No GPIO signal → relays turn OFF
5. **Explicit control**: Controller must actively write HIGH to enable relays

### Electrical Isolation

- **Optocoupler**: Isolates GPIO circuits from relay coil circuits
- **Separate power domains**: 3.3V GPIO signals, 5V relay coils, high-voltage switched loads
- **Flyback protection**: Diodes prevent inductive kickback from damaging components

## Troubleshooting

### Relay Not Activating

1. **Check power supply**: Verify 5V is present at VCC pin
2. **Check GPIO output**: Verify GPIO is exported and set to output mode
3. **Check signal**: Use multimeter to verify GPIO pin outputs 3.3V when set HIGH
4. **Check jumper**: Ensure trigger mode is set to Active-HIGH
5. **Check LED**: Module LED should light when relay is activated

### GPIO Permission Errors

On BeagleBone Black, ensure sysfs GPIO access permissions:

```bash
sudo chmod 666 /sys/class/gpio/export
sudo chmod 666 /sys/class/gpio/unexport
```

Or configure udev rules for persistent permissions.

### Modbus Communication Failures

1. **Check USB devices**: `ls -la /dev/ttyUSB*`
2. **Verify permissions**: User must have access to serial ports (dialout group)
3. **Check wiring**: Verify A+ and B- are not swapped
4. **Test independently**: Use `modbus-cli` or similar tool to verify inverter responds
5. **Check settings**: Verify baudrate (9600) matches inverter configuration

### Relay Clicking but Not Switching Load

1. **Check relay rating**: Ensure relay can handle the load current and voltage
2. **Check wiring**: Verify load is connected to NO (Normally Open) or NC (Normally Closed) as intended
3. **Measure voltage**: Use multimeter to verify relay contacts are switching

## References

- BeagleBone Black System Reference Manual: https://www.ti.com/lit/ml/sprm245/sprm245.pdf
- Growatt Modbus Protocol: See `docs/MAX Series Modbus RTU Protocol.pdf`
- GPIO sysfs Interface: https://www.kernel.org/doc/Documentation/gpio/sysfs.txt

## Related Files

- `src/Switch.hs` - GPIO control implementation
- `src/Growatt.hs` - Modbus RTU communication
- `src/Controller.hs` - Control logic and state machine
- `app/ControllerMain.hs` - Main executable with port configuration
- `README.md` - Project overview and build instructions
