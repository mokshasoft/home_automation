from collections import namedtuple
from pathlib import Path

# GPIO sysfs paths
GPIO_EXPORT = Path("/sys/class/gpio/export")
GPIO_UNEXPORT = Path("/sys/class/gpio/unexport")
GPIO_BASE = Path("/sys/class/gpio")

# Define switch state structure
SwitchState = namedtuple(
    "SwitchState",
    ["pin", "is_closed"],
)

# Default GPIO pins for the 4 switch wires (adjust for your BBB setup)
DEFAULT_PINS = [66, 67, 68, 69]  # P8_7, P8_8, P8_9, P8_10


def export_pin(pin):
    """Export a GPIO pin for userspace control."""
    gpio_path = GPIO_BASE / f"gpio{pin}"
    if not gpio_path.exists():
        GPIO_EXPORT.write_text(str(pin))


def unexport_pin(pin):
    """Unexport a GPIO pin."""
    gpio_path = GPIO_BASE / f"gpio{pin}"
    if gpio_path.exists():
        GPIO_UNEXPORT.write_text(str(pin))


def set_direction(pin, direction="out"):
    """Set GPIO pin direction ('in' or 'out')."""
    direction_path = GPIO_BASE / f"gpio{pin}" / "direction"
    direction_path.write_text(direction)


def set_value(pin, value):
    """Set GPIO pin value (0 or 1)."""
    value_path = GPIO_BASE / f"gpio{pin}" / "value"
    value_path.write_text(str(value))


def get_value(pin):
    """Get GPIO pin value."""
    value_path = GPIO_BASE / f"gpio{pin}" / "value"
    return int(value_path.read_text().strip())


def init_switch(pin):
    """Initialize a single switch pin."""
    export_pin(pin)
    set_direction(pin, "out")
    set_value(pin, 0)  # Start open
    return SwitchState(pin=pin, is_closed=False)


def init_switches(pins=None):
    """Initialize all switch pins. Returns list of SwitchState."""
    if pins is None:
        pins = DEFAULT_PINS
    return [init_switch(pin) for pin in pins]


def close_switch(switch):
    """Close the switch (short the wires)."""
    set_value(switch.pin, 1)
    return SwitchState(pin=switch.pin, is_closed=True)


def open_switch(switch):
    """Open the switch (disconnect the wires)."""
    set_value(switch.pin, 0)
    return SwitchState(pin=switch.pin, is_closed=False)


def set_switch(switch, closed):
    """Set switch state. Returns new SwitchState."""
    if closed:
        return close_switch(switch)
    else:
        return open_switch(switch)


def cleanup_switches(switches):
    """Cleanup and unexport all switch pins."""
    for switch in switches:
        set_value(switch.pin, 0)
        unexport_pin(switch.pin)


def print_switches(switches):
    """Print the state of all switches."""
    for i, switch in enumerate(switches):
        state = "CLOSED" if switch.is_closed else "OPEN"
        print(f"Switch {i} (GPIO {switch.pin}): {state}")
