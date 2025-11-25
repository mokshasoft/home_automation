# Python Growatt Controller (DEPRECATED)

**⚠️ This implementation is deprecated and archived.**

The active implementation is now in Haskell, located at `../../controller/`.

## Why Deprecated?

This Python implementation has been replaced with a Haskell implementation that provides:
- Better type safety
- Pure functional state machines for testability
- Stricter compile-time guarantees
- Better performance characteristics

## What Was This?

This was the original Python implementation of the Growatt inverter controller. It provided:
- Modbus RTU communication with Growatt inverters
- GPIO control for BeagleBone Black switches
- Battery-based phase control logic
- Solar window tracking
- MQTT publishing for monitoring

## Original Files

- `controller.py` - Main controller logic
- `growatt_rs485.py` - Modbus communication
- `switch.py` - GPIO control
- `main.py` - Entry point
- `growatt-mqtt.service` - Systemd service file
- `flake.nix`, `pyproject.toml`, `uv.lock` - Python dependencies

## For Reference Only

This code is preserved for reference but should not be used in production. If you need to understand the original design or logic, refer to these files. All new development should happen in the Haskell implementation.

## Migration Notes

The Haskell implementation follows the same high-level architecture but with significant improvements:
- Pure state transitions (no side effects in decision logic)
- Explicit action types for all controller decisions
- Better separation of concerns (IO vs pure logic)
- Comprehensive test coverage through pure functions

See `../../controller/README.md` for the current implementation documentation.
