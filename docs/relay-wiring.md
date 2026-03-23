# Connecting the 4-Channel Relay Module to BeagleBone Black

This guide describes how to wire the relay module to the BBB for GPIO control.

## Relay Module

**Product:** Reläkort 4 kanaler (MOD-RELAY-4CH)
**Link:** https://invize.se/produkt/mod-relay-4ch/

| Specification | Value |
|---------------|-------|
| Operating voltage | 5V |
| Channels | 4 |
| Input isolation | Optocoupler |
| Max load | 10A @ 220VAC / 30VDC |

## Finding the Pins on the BBB

The BeagleBone Black has two 46-pin expansion headers: **P8** and **P9**.

```
         USB
          |
    +-----+-----+
    |           |
    |    BBB    |
    |           |
   P9          P8
    |           |
    +-----------+
       Ethernet
```

**Pin numbering:** Pin 1 is closest to the Ethernet jack, pin 2 is next to it. Odd pins are on the inner row, even pins on the outer row.

```
P8 Header (top view, Ethernet at bottom):

          Inner    Outer
          (odd)    (even)
           ┌──┬──┐
  Pin 1 →  │1 │2 │
           ├──┼──┤
           │3 │4 │
           ├──┼──┤
           │5 │6 │
           ├──┼──┤
  GPIO66 → │7 │8 │ ← GPIO67
           ├──┼──┤
  GPIO68 → │9 │10│ ← GPIO69
           ├──┼──┤
           │: │: │
           └──┴──┘

P9 Header (top view, Ethernet at bottom):

           ┌──┬──┐
  GND   →  │1 │2 │ ← GND
           ├──┼──┤
           │3 │4 │
           ├──┼──┤
           │5 │6 │
           ├──┼──┤
  5V    →  │7 │8 │ ← 5V
           ├──┼──┤
           │: │: │
           └──┴──┘
```

## Wiring Diagram

Connect the relay module to the BBB as follows:

| BBB Pin | BBB Function | Relay Module |
|---------|--------------|--------------|
| P9_1 or P9_2 | GND | GND |
| P9_7 or P9_8 | 5V | VCC |
| P8_7 | GPIO66 | IN1 |
| P8_8 | GPIO67 | IN2 |
| P8_9 | GPIO68 | IN3 |
| P8_10 | GPIO69 | IN4 |

```
BeagleBone Black                4-Channel Relay Module
────────────────                ──────────────────────
                                 ┌─────────────────┐
  P9_1 (GND)  ──────────────────│ GND             │
                                 │                 │
  P9_7 (5V)   ──────────────────│ VCC             │
                                 │                 │
  P8_7  (GPIO66) ───────────────│ IN1     [RLY1]  │
                                 │                 │
  P8_8  (GPIO67) ───────────────│ IN2     [RLY2]  │
                                 │                 │
  P8_9  (GPIO68) ───────────────│ IN3     [RLY3]  │
                                 │                 │
  P8_10 (GPIO69) ───────────────│ IN4     [RLY4]  │
                                 └─────────────────┘
```

## Safety Notes

- **Power off before wiring** - Always disconnect power when making connections
- **Double-check VCC** - The 5V wire must go to VCC on the relay, never to a GPIO pin
- **BBB GPIOs are 3.3V** - Never connect 5V to any GPIO pin; it will damage the processor
- **Optocoupler protection** - This module has optocouplers, so the relay side is isolated from the BBB

## Testing

After wiring, test the connection:

```bash
# Export GPIO66 and set as output
echo 66 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio66/direction

# Turn relay ON (active-low: 0 = ON)
echo 0 > /sys/class/gpio/gpio66/value

# Turn relay OFF
echo 1 > /sys/class/gpio/gpio66/value

# Cleanup
echo 66 > /sys/class/gpio/unexport
```

You should hear the relay click and see the LED indicator change state.
