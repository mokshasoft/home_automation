# Connecting the 4-Channel Relay Module to BeagleBone Black

This guide describes how to wire the relay module to the BBB using a ULN2803 driver IC.

## Why a Driver IC is Needed

The BBB's 3.3V GPIO pins cannot reliably drive the relay module's optocoupler inputs, which are designed for 5V logic. The ULN2803 Darlington transistor array solves this by:

- Accepting 3.3V logic inputs directly (has built-in base resistors)
- Providing sufficient current to drive the optocouplers
- Inverting the signal, giving fail-safe active-high behavior

## Parts List

Order from Electrokit (electrokit.com) or similar supplier:

| Qty | Part | Article # | Price (SEK) |
|-----|------|-----------|-------------|
| 1 | Experimentkort 70x90mm FR4 | 41010658 | 16 |
| 1 | ULN2803A DIP-18 | 41035597 | 10 |
| 1 | DIL-hållare 18-pin (IC socket) | 40410018 | 2.40 |
| 1 | Stiftlist 2.54mm 2x40p brytbar guld | 41001168 | 14.40 |
| 1 | Skruvplint 2.54mm 5-pol | 41002455 | 7.50 |
| 1 | Jumper wire kit 140st | 41002700 | 64.35 |
| 1 | LCD OLED 0.91" 128x32px I2C | 41018396 | 69 |

**Total:** ~184 SEK

## Relay Module

**Product:** Reläkort 4 kanaler (MOD-RELAY-4CH)
**Link:** https://invize.se/produkt/mod-relay-4ch/

| Specification | Value |
|---------------|-------|
| Operating voltage | 5V |
| Channels | 4 |
| Input isolation | Optocoupler |
| Max load | 10A @ 220VAC / 30VDC |

## P9 Header Pinout

All connections use the P9 header only, allowing a single-header cape design.

```
P9 Header (top view, Ethernet at top):

           Ethernet
              ↓
           ┌──┬──┐
  GND   →  │1 │2 │ ← GND
           ├──┼──┤
  3.3V  →  │3 │4 │ ← 3.3V
           ├──┼──┤
           │5 │6 │
           ├──┼──┤
  5V    →  │7 │8 │ ← 5V
           ├──┼──┤
           │: │: │
           ├──┼──┤
 GPIO48 →  │15│16│
           ├──┼──┤
           │: │: │
           ├──┼──┤
I2C2_SCL→  │19│20│ ← I2C2_SDA
           ├──┼──┤
           │: │: │
           ├──┼──┤
 GPIO49 →  │23│24│
           ├──┼──┤
           │25│26│   (P9_25 unusable: HDMI audio)
           ├──┼──┤
 GPIO115→  │27│28│
           ├──┼──┤
           │29│30│ ← GPIO112
           ├──┼──┤
           │: │: │
           └──┴──┘
```

## Wiring Diagram

Channels are assigned in ascending GPIO order, so they run straight down the
ULN2803 from IN1 to IN4.

```
BeagleBone Black          ULN2803A (DIP-18)         4-Channel Relay
────────────────          ─────────────────         ────────────────

                         ┌────────────────┐
  P9_15 (GPIO48)  ──────→│1  IN1  OUT1  18├────────→ IN1
                         │                │
  P9_23 (GPIO49)  ──────→│2  IN2  OUT2  17├────────→ IN2
                         │                │
  P9_30 (GPIO112) ──────→│3  IN3  OUT3  16├────────→ IN3
                         │                │
  P9_27 (GPIO115) ──────→│4  IN4  OUT4  15├────────→ IN4
                         │                │
                         │5  IN5  OUT5  14│  unused
                         │6  IN6  OUT6  13│  unused
                         │7  IN7  OUT7  12│  unused
                         │8  IN8  OUT8  11│  unused
                         │                │
  P9_1  (GND) ──────────→│9  GND  COM   10├────────→ +5V rail
                         └────────────────┘

  P9_7  (5V)  ──────────────────────────────────────→ VCC
  P9_1  (GND) ──────────────────────────────────────→ GND
```

**ULN2803A pin numbering.** Inputs are pins 1-8 and outputs are pins 11-18,
mirrored: IN1 (pin 1) drives OUT1 (pin 18), IN2 (pin 2) drives OUT2 (pin 17),
and so on. Pin 9 is GND and **pin 10 is COM**, the common cathode for the
built-in flyback diodes, which ties to the +5V relay rail.

> **Do not connect pin 18 to 5V.** Pin 18 is OUT1, not a supply pin. Tying it
> to 5V and then driving IN1 high makes that Darlington sink the 5V rail to
> ground with no current limit, which will most likely destroy the channel.
> An earlier revision of this document showed pin 18 as a 5V connection and
> numbered the outputs 17/16/15/14; both were wrong. Check against the
> ULN2803A datasheet before soldering.

### Pin Mapping Summary

| Ch | BBB Pin | GPIO | ULN2803 In | ULN2803 Out | Relay |
|----|---------|------|------------|-------------|-------|
| 0 | P9_15 | GPIO48 | Pin 1 (IN1) | Pin 18 (OUT1) | IN1 |
| 1 | P9_23 | GPIO49 | Pin 2 (IN2) | Pin 17 (OUT2) | IN2 |
| 2 | P9_30 | GPIO112 | Pin 3 (IN3) | Pin 16 (OUT3) | IN3 |
| 3 | P9_27 | GPIO115 | Pin 4 (IN4) | Pin 15 (OUT4) | IN4 |

Power and ground:

| BBB Pin | Function | ULN2803 | Relay |
|---------|----------|---------|-------|
| P9_1 | GND | Pin 9 (GND) | GND |
| P9_7 | 5V | Pin 10 (COM) | VCC |

## OLED Display Connection

The 0.91" 128x32 OLED display connects via I2C. No additional components needed - direct wiring.

```
BeagleBone Black              OLED Display (SSD1306)
────────────────              ──────────────────────

  P9_1  (GND)    ────────────→ GND
  P9_3  (3.3V)   ────────────→ VCC
  P9_19 (I2C2_SCL) ──────────→ SCL
  P9_20 (I2C2_SDA) ──────────→ SDA
```

### Display Pin Mapping

| BBB Pin | Function | Display Pin |
|---------|----------|-------------|
| P9_1 | GND | GND |
| P9_3 | 3.3V | VCC |
| P9_19 | I2C2_SCL | SCL |
| P9_20 | I2C2_SDA | SDA |

### Display Specifications

| Specification | Value |
|---------------|-------|
| Size | 0.91" diagonal |
| Resolution | 128 x 32 pixels |
| Controller | SSD1306 |
| Interface | I2C (address 0x3C) |
| Voltage | 3.3V |

## Cape Assembly

Build a cape on perfboard that plugs into the BBB P9 header:

```
┌───────────────────────────────────────────┐
│  Screw Terminals (relay)   OLED Display   │
│  [OUT1][OUT2][OUT3][OUT4][GND]  ┌───────┐ │
│    │     │     │     │    │     │128x32 │ │
│    ○─────○─────○─────○────○     │ OLED  │ │
│           ┌─────────┐           └───────┘ │
│           │ ULN2803 │             │ │ │ │ │
│           │(in socket)│          │ │ │ │ │
│           └─────────┘       3.3V─┘ │ │ │ │
│    ○─────○─────○─────○────○    GND─┘ │ │ │
│    │     │     │     │    │    SCL───┘ │ │
│  GPIO48  │   GPIO112 │   5V    SDA─────┘ │
│       GPIO49     GPIO115                  │
│                                           │
│  ┌─────────────────────────────────────┐  │
│  │       2x23 Male Header              │  │
│  │       (plugs into BBB P9)           │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
```

The OLED can be mounted directly on the cape or connected via a short cable.

## Logic Behavior

With the ULN2803 driver, the system uses **active-high** logic from software perspective:

| GPIO State | ULN2803 Output | Relay State |
|------------|----------------|-------------|
| LOW (0) | Open (pulled high) | OFF |
| HIGH (1) | Sinks to GND | ON |

**Fail-safe behavior:** If the BBB loses power or crashes, GPIOs go LOW, ULN2803 outputs go open, and relays turn OFF.

## Safety Notes

- **Power off before wiring** - Always disconnect power when making connections
- **Double-check VCC** - The 5V wire must go to relay VCC, never to a GPIO pin
- **BBB GPIOs are 3.3V** - Never connect 5V to any GPIO pin; it will damage the processor
- **Use IC socket** - Allows replacing the ULN2803 if damaged

## Testing

After assembly, test the connection:

```bash
# Export GPIO49 and set as output
echo 49 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio49/direction

# Turn relay ON (with ULN2803: 1 = ON)
echo 1 > /sys/class/gpio/gpio49/value

# Turn relay OFF
echo 0 > /sys/class/gpio/gpio49/value

# Cleanup
echo 49 > /sys/class/gpio/unexport
```

You should hear the relay click and see the LED indicator change state.

## Verifying Pins on the Board

Do not trust a successful `export` as proof a pin works. On the BBB a pad
can be muxed away from the GPIO controller while sysfs still accepts writes
and latches them - the pin simply never moves.

Run the diagnostic to check mux state, gpiochip bases, I2C and pin claims:

```bash
scp scripts/bbb-pins.sh bbb:/tmp/
ssh bbb "sudo bash /tmp/bbb-pins.sh"
```

Add `--toggle` to drive each relay pin HIGH for 3s for multimeter checks.

### Pins claimed by HDMI audio

The stock image loads `BB-HDMI-TDA998x-00A0`, and the McASP0 audio driver
(`48038000.mcasp`) owns four P9 pins. **Do not use these for GPIO** unless
you disable the HDMI overlay:

| P9 pin | GPIO | Mux mode |
|--------|------|----------|
| P9_25 | 117 | mcasp0_ahclkx |
| P9_28 | 113 | mcasp0_axr2 |
| P9_29 | 111 | mcasp0_fsx |
| P9_31 | 110 | mcasp0_aclkx |

Channel 4 originally used P9_25 and was moved to P9_15 for this reason.

### Pull direction matters

All four relay pins must default to **pull-down** (pad conf `0x27`). A
pull-up pin (`0x37`) feeds current into the ULN2803's 2.7k base resistor
during boot; Darlington gain can turn that into enough sink current to
weakly energise a relay before the controller sets the pin LOW, defeating
the fail-safe design.

Free P9 pins that default to pull-down: **P9_14 (GPIO50), P9_15 (GPIO48),
P9_16 (GPIO51), P9_41 (GPIO20), P9_42 (GPIO7)**.

Free but **pull-up**, so unsuitable without an external pull-down: P9_11,
P9_12, P9_13, P9_17, P9_18, P9_21, P9_22, P9_24, P9_26.
