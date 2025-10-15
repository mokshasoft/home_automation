import os
import time
import json
from pymodbus.client import ModbusSerialClient as ModbusClient
from pymodbus.exceptions import ModbusIOException
from pprint import pprint
import growatt_rs485 as Growatt

port = "/dev/ttyUSB0"
client = ModbusClient(port=port, baudrate=9600, stopbits=1, parity='N', bytesize=8, timeout=1)
client.connect()

def get_single(registers, index, unit):
    return round(float(registers[index]) * unit, 1)

def get_double(registers, index, unit):
    return round(float((registers[index] << 16) + registers[index+1])*unit, 1)

# ----------------------------------------------------------------------
# Helper: return a list of "index:new_value" strings for all changed cells
def changed_fields(prev, cur):
    """Compare two register lists and return a list of 'idx:val' strings."""
    diffs = []
    for i, (p, c) in enumerate(zip(prev, cur)):
        if p != c:
            diffs.append(f"{i}:{c}")
    return diffs
# ----------------------------------------------------------------------

previous_row = None          # no baseline yet

while False:
    # Read the 125 holding registers starting at address 0
    response = client.read_input_registers(address=0, count=125)
    if not response.isError():
        row = response.registers               # <-- this is a list of 125 ints

        # ----- 1️⃣ Print only the changed indices/value pairs ----------
        if previous_row is not None:            # skip diff on the very first read
            diffs = changed_fields(previous_row, row)
            if diffs:                           # print only when something changed
                print("Changed →", ", ".join(diffs))
        else:
            # First iteration – we have nothing to compare against
            print("First read – no previous data to diff against")

        # ----- 2️⃣ Keep the current row for the next iteration ----------
        previous_row = row.copy()

        # ----- 3️⃣ Your original human‑readable prints -------------------
        value_input_voltage = row[1]   # raw value (tenths of a volt)
        value_charge        = row[17]  # raw value (hundredths of a volt)
        value_percent       = row[18]  # percent
        watt_out = row[70]

        print(f"output watt? : {watt_out/10:.1f} W")
        print(f"input voltage : {value_input_voltage/10:.1f} V")
        print(f"charge voltage: {value_charge/100:.2f} V")
        print(f"percent charge: {value_percent}%")
    else:
        # Something went wrong with the Modbus request
        print("Modbus error:", response)

    # Wait before polling again
    time.sleep(5)

while True:
    row = client.read_input_registers(address=0, count=125).registers
    print(f"{row}")
    value_input_voltage = row[1]   # raw value (tenths of a volt)
    value_charge        = row[17]  # raw value (hundredths of a volt)
    value_percent       = row[18]  # percent
    watt_out = row[70]

    print(f"panel voltage  : {value_input_voltage/10:.1f} V")
    print(f"battery voltage: {value_charge/100:.2f} V")
    print(f"percent charge : {value_percent}%")
    print(f"output watt?   : {watt_out/10:.1f} W")

    status = Growatt.read(client)
    print(f"panel voltage  : {status.inputVoltage:.1f} V")
    print(f"battery voltage: {status.batteryVoltage:.2f} V")
    print(f"percent charge : {status.batteryPercentage}%")
    print(f"output watt?   : {status.outputWatt:.1f} W")

    time.sleep(5)

# [12, 1467, 0, 0, 1540, 0, 0, 30, 0, 0, 110, 0, 500, 0, 0, 0, 0, 5054, 93, 4093, 0, 0, 2300, 5000, 0, 287, 219, 2, 0, 0, 0, 0, 283, 285, 2, 17, 0, 0, 0, 0, 0, 0, 0, 0, 20105, 0, 0, 0, 0, 41, 0, 25911, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 0, 3939, 0, 0, 0, 0, 0, 0, 110, 0, 500, 0, 0, 0, 0, 65535, 64426, 0, 0, 0, 25, 21, 0, 0, 12, 0, 803, 0, 60, 1, 4326, 0, 0, 4944, 4018, 1639, 2297, 5000]
# 93% batteri och 50.5V
