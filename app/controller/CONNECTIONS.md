# Hardware Connections Guide

## Overview

This document describes the hardware connections between the BeagleBone Black (BBB), relay modules, OLED display, and Growatt inverters for the controller system.

## Relay Module Connection

### Module Specifications

- **Model**: 4-Channel Relay Module with Optocoupler Isolation
- **Link**: https://invize.se/produkt/mod-relay-4ch/
- **Input Voltage**: 5V DC
- **Trigger**: Active-LOW (but ULN2803 driver inverts to active-HIGH behavior)

### Why a ULN2803 Driver is Required

The BBB's 3.3V GPIO pins cannot reliably drive the relay module's 5V optocoupler inputs directly. The ULN2803 Darlington transistor array provides:

- **Level shifting** - Accepts 3.3V inputs, outputs can sink to GND with 5V pull-ups
- **Current amplification** - Provides sufficient current for optocouplers
- **Built-in base resistors** - No external components needed on inputs
- **Signal inversion** - Converts active-LOW relay to fail-safe active-HIGH behavior

### Wiring Diagram

All connections use the P9 header only (single-header cape design):

Channels are assigned in ascending GPIO order, so they run straight down the
ULN2803 from IN1 to IN4.

```
BeagleBone Black          ULN2803A (DIP-18)       4-Channel Relay
────────────────          ─────────────────       ────────────────

  P9_15 (GPIO48) ────────→ Pin 1  (IN1)
  P9_23 (GPIO49) ────────→ Pin 2  (IN2)
  P9_30 (GPIO112)────────→ Pin 3  (IN3)
  P9_27 (GPIO115)────────→ Pin 4  (IN4)

                           Pin 18 (OUT1) ───────→ IN1
                           Pin 17 (OUT2) ───────→ IN2
                           Pin 16 (OUT3) ───────→ IN3
                           Pin 15 (OUT4) ───────→ IN4

  P9_1  (GND)    ────────→ Pin 9  (GND) ────────→ GND
  P9_7  (5V)     ────────→ Pin 10 (COM) ────────→ VCC
```

**ULN2803A pin numbering.** Inputs are pins 1-8, outputs pins 11-18, mirrored:
IN1 (pin 1) drives OUT1 (pin 18), IN2 (pin 2) drives OUT2 (pin 17), and so on.
Pin 9 is GND; pin 10 is COM, the flyback-diode common, which ties to +5V.

> **Pin 18 is OUT1, not a supply pin.** Do not connect it to 5V - driving IN1
> high would then sink the 5V rail to ground through that Darlington with no
> current limit and most likely destroy the channel. An earlier revision of
> this document listed pin 18 as a 5V connection and numbered the outputs
> 17/16/15/14; both were wrong.

### GPIO Pin Reference (BeagleBone Black P9 Header)

| Ch | Phase   | GPIO Number | Header Pin | ULN2803 Input | ULN2803 Output |
|----|---------|-------------|------------|---------------|----------------|
| 0  | Phase 1 | GPIO 48     | P9_15      | IN1 (Pin 1)   | OUT1 (Pin 18)  |
| 1  | Phase 2 | GPIO 49     | P9_23      | IN2 (Pin 2)   | OUT2 (Pin 17)  |
| 2  | Phase 3 | GPIO 112    | P9_30      | IN3 (Pin 3)   | OUT3 (Pin 16)  |
| 3  | Phase 4 | GPIO 115    | P9_27      | IN4 (Pin 4)   | OUT4 (Pin 15)  |

Pins are listed in ascending GPIO order so the channel index, the GPIO number
and the ULN2803 input all increase together.

Configure these in `app/controller-c/switch.c` by modifying the `DEFAULT_PINS` definition.

#### Verified against hardware

This mapping was checked on the board, not just on paper. Two constraints
drive it:

**1. HDMI audio owns four P9 pins.** The stock image loads
`BB-HDMI-TDA998x-00A0`, and the McASP0 driver (`48038000.mcasp`) claims
P9_25, P9_28, P9_29 and P9_31. Phase 4 originally used P9_25 (GPIO117); the
four channels were reassigned to P9_15/P9_23/P9_30/P9_27 (GPIO 48/49/112/115),
kept in ascending GPIO order.

This failure is silent and worth understanding. Exporting a GPIO does not
touch the pin mux, so `echo 117 > export` succeeds, `echo 1 > value` is
accepted, and the GPIO bank's DATAOUT bit really does go high - but the pad
is still routed to the audio controller, so DATAIN stays 0 and the physical
pin never moves. Nothing reports an error. Verify with
`scripts/bbb-pins.sh`, or a multimeter, rather than trusting a clean export.

**2. All four pins must default to pull-down.** Pad conf `0x27` is
pull-down, `0x37` is pull-up. Because the ULN2803 wiring is active-high, a
pull-up pin would push current through the chip's 2.7k base resistor during
boot, before the controller sets direction; Darlington gain can make that
enough to weakly energise a relay and defeat the fail-safe design.

Free P9 pins defaulting to pull-down (safe spares): P9_14 (GPIO50),
P9_16 (GPIO51), P9_41 (GPIO20), P9_42 (GPIO7).

Free but pull-up, so unsuitable without an external pull-down: P9_11, P9_12,
P9_13, P9_17, P9_18, P9_21, P9_22, P9_24, P9_26.

Also confirmed on the board: the gpiochip bases are the classic
0 / 32 / 64 / 96, so the plain sysfs numbers in `switch.c` address the
intended lines. I2C2 enumerates as `/dev/i2c-2`.

### Logic Behavior

With the ULN2803 driver, the system uses **active-HIGH** logic from software perspective:

| GPIO State | ULN2803 Output | Relay Module IN | Relay State |
|------------|----------------|-----------------|-------------|
| LOW (0)    | Open (high-Z)  | HIGH (via pull-up) | OFF |
| HIGH (1)   | Sinks to GND   | LOW             | ON |

### Fail-Safe Design

The ULN2803 provides **fail-safe behavior**:

- GPIO HIGH (1) = Relay ON
- GPIO LOW (0) = Relay OFF

**Safety Benefits**:
1. **Controller failure**: If the controller crashes, GPIOs go LOW → relays turn OFF
2. **Power loss**: If BBB loses power, GPIOs go LOW → relays turn OFF
3. **Boot sequence**: GPIOs default to LOW → relays stay OFF until controller explicitly enables them
4. **Predictable defaults**: System defaults to safe state (all loads disconnected)

### Power Supply Considerations

1. **Relay coil voltage**: 5V DC (not 3.3V)
2. **GPIO signal voltage**: 3.3V (BBB GPIO output level)
3. **ULN2803**: Accepts 3.3V inputs directly (built-in 2.7K base resistors)

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

## OLED Display Connection

A 0.91" 128x32 pixel OLED display shows real-time power readings. Connects via I2C.

### Display Specifications

- **Model**: 0.91" OLED 128x32px I2C (SSD1306 controller)
- **Article #**: 41018396 (Electrokit)
- **Interface**: I2C (address 0x3C)
- **Voltage**: 3.3V (direct connection to BBB, no level shifter needed)

### Wiring

```
BeagleBone Black              OLED Display
────────────────              ────────────

  P9_1  (GND)    ────────────→ GND
  P9_3  (3.3V)   ────────────→ VCC
  P9_19 (I2C2_SCL) ──────────→ SCL
  P9_20 (I2C2_SDA) ──────────→ SDA
```

### I2C Pin Reference

| BBB Pin | Function | Display Pin |
|---------|----------|-------------|
| P9_1 | GND | GND |
| P9_3 | 3.3V | VCC |
| P9_19 | I2C2_SCL | SCL |
| P9_20 | I2C2_SDA | SDA |

### Testing I2C Connection

```bash
# Detect I2C devices (display should appear at 0x3c)
i2cdetect -y -r 2   # I2C2 confirmed to enumerate as /dev/i2c-2
```

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
┌───────────────────────────────────────────────────────────────────────┐
│ BeagleBone Black                                                      │
│                                                                       │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐        │
│  │  Controller  │─────→│  GPIO Pins   │      │   I2C Bus    │        │
│  │     (C)      │      │ 48,49,112,115│      │  P9_19/P9_20 │        │
│  └──────────────┘      └──────┬───────┘      └──────┬───────┘        │
│         │                     │                     │                 │
│         ├───→ USB0 ───────────┼─────────┐           │                 │
│         ├───→ USB1 ───────────┼─────────┼───┐       │                 │
│         └───→ USB2 ───────────┼─────────┼───┼───┐   │                 │
│                               │         │   │   │   │                 │
└───────────────────────────────┼─────────┼───┼───┼───┼─────────────────┘
                                │         │   │   │   │
                                │ ┌───────┘   │   │   │
                                │ │  ┌────────┘   │   │
                                │ │  │  ┌─────────┘   │
                                ▼ ▼  ▼  ▼             ▼
                         ┌──────────────┐     ┌─────────────┐
                         │ USB-RS485 x3 │     │   Driver    │
                         │   Adapters   │     │    Cape     │
                         └──────┬───────┘     │ ┌─────────┐ │
                                │             │ │ ULN2803 │ │
                       ┌────────┼────────┐    │ └─────────┘ │
                       ▼        ▼        ▼    │ ┌─────────┐ │
                 ┌─────────┬─────────┬─────┐  │ │  OLED   │ │
                 │Inverter1│Inverter2│Inv.3│  │ │ 128x32  │ │
                 │(Modbus) │(Modbus) │(Mod)│  │ └─────────┘ │
                 └─────────┴─────────┴─────┘  └──────┬──────┘
                                                     │
                                            ┌────────┼────────┐
                                            ▼        ▼        ▼
                                       ┌────────┬────────┬────────┐
                                       │ Phase1 │ Phase2 │ Phase3 │
                                       │ Switch │ Switch │ Switch │
                                       └────────┴────────┴────────┘
                                              Relay Module
```

## Troubleshooting

### Relay Not Activating

1. **Check ULN2803**: Verify IC is seated properly in socket
2. **Check power supply**: Verify 5V is present at relay VCC pin
3. **Check GPIO output**: Verify GPIO is exported and set to output mode
4. **Check signal**: Use multimeter to verify GPIO pin outputs 3.3V when set HIGH
5. **Check wiring**: Verify ULN2803 outputs connect to relay inputs
6. **Check LED**: Module LED should light when relay is activated

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

### OLED Display Not Working

1. **Check I2C detection**: Run `i2cdetect -y -r 2` - display should appear at 0x3c
2. **Check wiring**: Verify SDA/SCL are not swapped
3. **Check voltage**: Verify 3.3V at display VCC pin
4. **Check I2C bus**: Ensure I2C2 is enabled in device tree

## References

- BeagleBone Black System Reference Manual: https://www.ti.com/lit/ml/sprm245/sprm245.pdf
- Growatt Modbus Protocol: See `docs/MAX Series Modbus RTU Protocol.pdf`
- GPIO sysfs Interface: https://www.kernel.org/doc/Documentation/gpio/sysfs.txt
- ULN2803 Datasheet: Search for "ULN2803A datasheet"
- SSD1306 OLED Datasheet: Search for "SSD1306 datasheet"
- Relay Wiring Guide: See `docs/relay-wiring.md`

## Related Files

- `app/controller-c/switch.c` - GPIO control implementation (C version)
- `src/Switch.hs` - GPIO control implementation (Haskell version)
- `src/Growatt.hs` - Modbus RTU communication
- `src/Controller.hs` - Control logic and state machine
- `app/ControllerMain.hs` - Main executable with port configuration
- `docs/relay-wiring.md` - Detailed wiring guide with parts list
