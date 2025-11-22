import time
import growatt_rs485 as growatt
import switch

# Thresholds
THRESHOLD_HIGH = 95  # Enable when battery >= this
THRESHOLD_LOW = 90  # Disable when battery < this
MAX_OUTPUT_WATTS = 5000  # Max watts per inverter
LOAD_HEADROOM = 2000  # Headroom needed to enable switch


def get_clients(ports=None):
    """Initialize clients for multiple inverters."""
    if ports is None:
        ports = ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2"]

    return [growatt.get_client(port) for port in ports]


def read_all_inverters(clients):
    """Read status from all inverters. Returns list of InverterStatus."""
    statuses = []
    for client in clients:
        status = growatt.read(client)
        if status:
            statuses.append(status)
    return statuses


def can_enable_phase(status):
    """Check if phase can be enabled without overloading inverter."""
    return (status.output_watts + LOAD_HEADROOM) <= MAX_OUTPUT_WATTS


def should_enable_phase(status, currently_enabled):
    """Determine if a phase switch should be enabled."""
    if status is None:
        return currently_enabled

    # Check battery thresholds (hysteresis)
    if status.battery_percentage >= THRESHOLD_HIGH:
        # Only enable if we have capacity headroom
        return can_enable_phase(status)
    elif status.battery_percentage < THRESHOLD_LOW:
        return False
    else:
        # In hysteresis band - keep current state but check capacity
        if currently_enabled and not can_enable_phase(status):
            return False  # Disable if overloaded
        return currently_enabled


def update_phase_switches(switches, statuses, currently_enabled):
    """Update each switch based on its inverter status. Returns new states and enabled flags."""
    new_switches = []
    new_enabled = []

    for i, (sw, status) in enumerate(zip(switches, statuses)):
        was_enabled = currently_enabled[i] if i < len(currently_enabled) else False
        enable = should_enable_phase(status, was_enabled)

        new_sw = switch.set_switch(sw, enable)
        new_switches.append(new_sw)
        new_enabled.append(enable)

        if enable != was_enabled:
            action = "Enabling" if enable else "Disabling"
            print(f"{action} phase {i} (output: {status.output_watts:.0f}W)")

    return new_switches, new_enabled


def print_controller_status(statuses, switches_enabled):
    """Print current controller status."""
    print("--- Controller Status ---")
    if statuses:
        print(f"Battery: {statuses[0].battery_percentage}%")
    for i, status in enumerate(statuses):
        state = "ON" if switches_enabled[i] else "OFF"
        print(f"Phase {i}: {status.output_watts:.0f}W [{state}]")
    print()


def run_controller(clients, switches, interval=5):
    """Main controller loop."""
    switches_enabled = [False] * len(switches)

    while True:
        statuses = read_all_inverters(clients)

        if len(statuses) == len(switches):
            switches, switches_enabled = update_phase_switches(
                switches, statuses, switches_enabled
            )
            print_controller_status(statuses, switches_enabled)
        else:
            print(f"Warning: got {len(statuses)} statuses for {len(switches)} switches")

        time.sleep(interval)


if __name__ == "__main__":
    clients = get_clients()
    switches = switch.init_switches()

    try:
        run_controller(clients, switches)
    finally:
        switch.cleanup_switches(switches)
