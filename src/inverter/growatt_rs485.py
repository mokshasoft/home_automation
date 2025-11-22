from collections import namedtuple
from pymodbus.client import ModbusSerialClient as ModbusClient

# Define the structure with fields
InverterStatus = namedtuple(
    "InverterStatus",
    [
        "pv_voltage",
        "pv_watts",
        "battery_voltage",
        "battery_percentage",
        "output_watts",
        "utility_watts",
    ],
)


def get_client():
    port = "/dev/ttyUSB0"
    client = ModbusClient(
        port=port, baudrate=9600, stopbits=1, parity="N", bytesize=8, timeout=1
    )
    client.connect()
    return client


def read(client):
    status = None
    response = client.read_input_registers(address=0, count=125)
    if not response.isError():
        row = response.registers
        status = InverterStatus(
            pv_voltage=row[1] / 10,
            pv_watts=((row[3] << 16) + row[4]) / 10,  # ?
            battery_voltage=row[17] / 100,
            battery_percentage=row[18],
            output_watts=row[70] / 10,
            utility_watts=((row[21] << 16) + row[22]) / 10,  # ?
        )

    else:
        # Something went wrong with the Modbus request
        print("Modbus error:", response)

    return status


def print_status(status):
    print(f"PV voltage     : {status.pv_voltage:.1f} V")
    print(f"PV watts       : {status.pv_watts:.1f} W")
    print(f"Battery voltage: {status.battery_voltage:.2f} V")
    print(f"Battery percent: {status.battery_percentage}%")
    print(f"Output watts   : {status.output_watts:.1f} W")
    print(f"Utility watts  : {status.utility_watts:.1f} W")
