# Growatt Inverter Controller

A Haskell-based controller for managing 3-phase Growatt inverters with intelligent surplus energy management and GPIO-controlled switches.

## Overview

This project provides automated control of three-phase power switches based on battery levels and solar PV production. It communicates with Growatt inverters via Modbus RTU and controls BeagleBone Black (BBB) GPIO pins to engage/disengage phases intelligently.

### Key Features

- **Battery-based phase control**: Automatically enable/disable phases based on battery percentage
- **PV verification**: Verifies power draw from solar panels when engaging new phases
- **Solar window tracking**: Adjusts polling intervals based on daylight hours
- **Modbus RTU communication**: Reads real-time data from Growatt inverters
- **GPIO control**: Direct control of relay switches via BBB GPIO pins
- **Pure functional state machine**: Deterministic decision-making with clear state transitions

## Architecture

The project is organized into three main modules:

- **`Growatt`**: Modbus RTU communication with Growatt inverters
- **`Switch`**: GPIO control for BeagleBone Black switches
- **`Controller`**: Pure state machine logic and main control loop

## Prerequisites

### System Requirements

- NixOS or Nix package manager (recommended)
- BeagleBone Black (for GPIO control)
- Growatt inverters with Modbus RTU support
- USB-to-RS485 adapters for Modbus communication

### Dependencies

The project uses Nix flakes for reproducible builds. All dependencies are managed through:
- `flake.nix` - Nix development environment
- `stack.yaml` - Stack resolver configuration
- `growatt-controller.cabal` - Haskell package definition

## Building

### Using Nix (Recommended)

Enter the development shell with all dependencies:

```bash
nix develop
```

Then build with Stack:

```bash
stack build
```

### Direct Stack Build

If you have Stack and system dependencies installed:

```bash
stack build
```

Required system libraries:
- `libmodbus` - C library for Modbus protocol
- `gmp` - GNU Multiple Precision library
- `zlib` - Compression library

## Development Workflow

**Important**: This project maintains strict code quality standards. Always run the following commands before committing:

```bash
make format && make lint && stack build
```

### Code Formatting

Format all Haskell source files:

```bash
make format
```

This uses `fourmolu` to ensure consistent code style across the project.

### Linting

Check for code quality issues:

```bash
make lint
```

This uses `hlint` to suggest improvements. **All hints must be addressed** - the lint must pass with "No hints" before code can be merged.

### Building

Build the project with all strict warning flags enabled:

```bash
stack build
```

The project uses comprehensive GHC warnings including:
- `-Wall` - All standard warnings
- `-Wcompat` - Compatibility warnings
- `-Wincomplete-record-updates` - Incomplete record updates
- `-Wincomplete-uni-patterns` - Non-exhaustive patterns
- `-Wmissing-export-lists` - Missing export lists (libraries only)
- `-Wredundant-constraints` - Unnecessary type constraints
- `-Wunused-packages` - Unused dependencies
- `-Wunused-type-patterns` - Unused type variables

**All warnings must be addressed** - the build should complete cleanly.

## Project Structure

```
.
├── app/
│   ├── ControllerMain.hs    # Main controller executable
│   └── Main.hs               # Simple monitoring tool
├── src/
│   ├── Controller.hs         # Pure state machine logic
│   ├── Growatt.hs           # Modbus inverter interface
│   └── Switch.hs            # GPIO switch control
├── flake.nix                # Nix development environment
├── growatt-controller.cabal # Haskell package definition
├── stack.yaml               # Stack configuration
├── Makefile                 # Development commands
└── README.md                # This file
```

## Executables

### Controller

The main control loop that manages switches based on battery levels:

```bash
stack exec controller
```

Configuration defaults (in `Controller.hs`):
- Battery enable threshold: 95%
- Battery disable threshold: 90%
- Max watts per inverter: 5000W
- Load headroom: 2000W

### Main (Monitor)

A simple monitoring tool for testing single inverter communication:

```bash
stack exec main
```

This reads and displays inverter status every 5 seconds.

## Configuration

### GPIO Pins

Default GPIO pins (BeagleBone Black **P9** header), driven through a
ULN2803 driver stage:

| Ch | Phase | GPIO | P9 pin | ULN2803 |
|----|-------|------|--------|---------|
| 0 | Phase 1 | GPIO 48 | P9_15 | IN1 (pin 1) |
| 1 | Phase 2 | GPIO 49 | P9_23 | IN2 (pin 2) |
| 2 | Phase 3 | GPIO 112 | P9_30 | IN3 (pin 3) |
| 3 | Phase 4 | GPIO 115 | P9_27 | IN4 (pin 4) |

Configure in `Switch.hs` by modifying `defaultPins`.

**Do not use P9_25 (GPIO117).** It is owned by the HDMI audio driver
(`48038000.mcasp`), and the failure is silent: export succeeds and writes are
latched, but the pad never moves. See `docs/relay-wiring.md` for the full
wiring and `scripts/bbb-pins.sh` to verify pins on the board.

> This Haskell controller is superseded by the C implementation in
> `app/controller-c/`, which is what actually gets deployed. If you change
> pins here, change `DEFAULT_PINS` in `app/controller-c/switch.c` too.

### Serial Ports

Default inverter ports:
- Inverter 1: `/dev/ttyUSB0`
- Inverter 2: `/dev/ttyUSB1`
- Inverter 3: `/dev/ttyUSB2`

Configure in `app/ControllerMain.hs` by modifying `defaultPorts`.

### Modbus Settings

- Baud rate: 9600
- Parity: None
- Data bits: 8
- Stop bits: 1
- Device address: 0

Modify in `Growatt.hs` `getClient` function if needed.

## Code Quality Standards

This project maintains high code quality through:

1. **Mandatory formatting**: All code must be formatted with `fourmolu`
2. **Zero lint warnings**: All `hlint` suggestions must be addressed
3. **Strict compiler warnings**: No warnings allowed in production code
4. **Type safety**: Explicit type signatures for all top-level functions
5. **Pure functions**: State transitions are pure and testable

### Pre-commit Checklist

Before committing any changes:

- [ ] Run `make format` - Code is properly formatted
- [ ] Run `make lint` - No hlint warnings ("No hints")
- [ ] Run `stack build` - Clean build with no warnings
- [ ] Test functionality if applicable
- [ ] Update documentation if behavior changed

## Testing

Manual testing on target hardware:

1. Connect USB-RS485 adapters to inverters
2. Deploy to BeagleBone Black
3. Run controller: `stack exec controller`
4. Monitor logs for state transitions

## Troubleshooting

### "Missing dependency: modbus"

Make sure you're in the Nix development shell:
```bash
nix develop
```

### GPIO permission errors

On BeagleBone Black, ensure GPIO sysfs access:
```bash
sudo chmod 666 /sys/class/gpio/export
sudo chmod 666 /sys/class/gpio/unexport
```

### Modbus connection failures

- Check USB device permissions: `ls -la /dev/ttyUSB*`
- Verify baudrate matches inverter settings
- Test with `modbus-cli` or similar tool first

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following code quality standards
4. Run `make format && make lint && stack build`
5. Ensure all checks pass
6. Submit a pull request

Remember: **No warnings, no lint hints, always formatted.**
