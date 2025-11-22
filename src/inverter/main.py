import time
import growatt_rs485 as growatt


def changed_fields(prev, cur):
    """Compare two register lists and return a list of 'idx:val' strings."""
    diffs = []
    for i, (p, c) in enumerate(zip(prev, cur)):
        if p != c:
            diffs.append(f"{i}:{c}")
    return diffs


def loop_print_changes(client):
    """Print register changes to help identify correct register addresses."""
    previous_row = None
    while True:
        response = client.read_input_registers(address=0, count=125)
        if not response.isError():
            row = response.registers

            if previous_row is not None:
                diffs = changed_fields(previous_row, row)
                if diffs:
                    print("Changed:", ", ".join(diffs))
            else:
                print("First read - no previous data to diff against")

            previous_row = row.copy()
        else:
            print("Modbus error:", response)

        time.sleep(5)


def loop_print_status(client):
    """Print inverter status in a loop."""
    while True:
        status = growatt.read(client)
        if status:
            growatt.print_status(status)
        time.sleep(5)


if __name__ == "__main__":
    client = growatt.get_client()
    loop_print_status(client)
