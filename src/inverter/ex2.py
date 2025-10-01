import os
import time
import json
from pymodbus.client import ModbusSerialClient as ModbusClient
from pymodbus.exceptions import ModbusIOException
from pprint import pprint

port = "/dev/ttyUSB0"
client = ModbusClient(port=port, baudrate=9600, stopbits=1, parity='N', bytesize=8, timeout=1)
client.connect()

def get_single(registers, index, unit):
    return round(float(registers[index]) * unit, 1)

def get_double(registers, index, unit):
    return round(float((registers[index] << 16) + registers[index+1])*unit, 1)

while True:
    row = client.read_input_registers(address=0, count=125).registers
    print(f"{row}")
    value_input_voltage = row[1]
    value_charge = row[17]
    value_percent = row[18]

    print(f"charge voltage: {value_input_voltage/10}V")
    print(f"charge voltage: {value_charge/100}V")
    print(f"percent charge: {value_percent}%")
    time.sleep(5)

# [12, 1467, 0, 0, 1540, 0, 0, 30, 0, 0, 110, 0, 500, 0, 0, 0, 0, 5054, 93, 4093, 0, 0, 2300, 5000, 0, 287, 219, 2, 0, 0, 0, 0, 283, 285, 2, 17, 0, 0, 0, 0, 0, 0, 0, 0, 20105, 0, 0, 0, 0, 41, 0, 25911, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 0, 3939, 0, 0, 0, 0, 0, 0, 110, 0, 500, 0, 0, 0, 0, 65535, 64426, 0, 0, 0, 25, 21, 0, 0, 12, 0, 803, 0, 60, 1, 4326, 0, 0, 4944, 4018, 1639, 2297, 5000]
# 93% batteri och 50.5V
