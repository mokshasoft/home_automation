import time
from collections import namedtuple
from datetime import datetime, time as dtime
import growatt_rs485 as growatt
import switch

# Thresholds
THRESHOLD_HIGH = 95  # Enable when battery >= this
THRESHOLD_LOW = 90  # Disable when battery < this
MAX_OUTPUT_WATTS = 5000  # Max watts per inverter
LOAD_HEADROOM = 2000  # Headroom needed to enable switch
PV_ON_THRESHOLD = 10  # Watts to consider PV as "on"

# Solar window tracking
SolarWindow = namedtuple("SolarWindow", ["start_time", "end_time"])


def update_solar_window(window, pv_watts, pv_was_on):
    """Update solar window based on current PV state. Returns (new_window, pv_is_on)."""
    now = datetime.now().time()
    pv_is_on = pv_watts > PV_ON_THRESHOLD

    if pv_is_on and not pv_was_on:
        # PV just came on - record start time
        return SolarWindow(start_time=now, end_time=window.end_time), pv_is_on
    elif not pv_is_on and pv_was_on:
        # PV just went off - record end time
        return SolarWindow(start_time=window.start_time, end_time=now), pv_is_on
    else:
        return window, pv_is_on


def outside_solar_window(yesterday_window):
    """Check if current time is past yesterday's end time."""
    if yesterday_window.end_time is None:
        return False
    return datetime.now().time() > yesterday_window.end_time


def rollover_solar_window(today_window):
    """Move today's window to yesterday at start of new day. Returns new today window."""
    return SolarWindow(start_time=None, end_time=None)


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


def should_enable_phase(status, currently_enabled, yesterday_window):
    """Determine if a phase switch should be enabled."""
    if status is None:
        return currently_enabled

    # Don't enable if past yesterday's solar window
    if outside_solar_window(yesterday_window):
        return False

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


def update_phase_switches(switches, statuses, currently_enabled, yesterday_window):
    """Update each switch based on its inverter status. Returns new states and enabled flags."""
    new_switches = []
    new_enabled = []

    for i, (sw, status) in enumerate(zip(switches, statuses)):
        was_enabled = currently_enabled[i] if i < len(currently_enabled) else False
        enable = should_enable_phase(status, was_enabled, yesterday_window)

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
    today_window = SolarWindow(start_time=None, end_time=None)
    yesterday_window = SolarWindow(start_time=None, end_time=None)
    pv_was_on = False
    last_date = datetime.now().date()

    while True:
        statuses = read_all_inverters(clients)

        if len(statuses) == len(switches):
            # Sum PV watts from all inverters
            total_pv_watts = sum(s.pv_watts for s in statuses)

            # Check for day rollover
            current_date = datetime.now().date()
            if current_date != last_date:
                yesterday_window = today_window
                today_window = rollover_solar_window(today_window)
                last_date = current_date
                print(f"New day - yesterday's window: {yesterday_window}")

            # Update solar window tracking
            today_window, pv_was_on = update_solar_window(today_window, total_pv_watts, pv_was_on)

            # Update switches
            switches, switches_enabled = update_phase_switches(
                switches, statuses, switches_enabled, yesterday_window
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
