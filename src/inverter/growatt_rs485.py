from collections import namedtuple
from pymodbus.client import ModbusSerialClient as ModbusClient
from pymodbus.exceptions import ModbusIOException

# Define the structure with fields
InverterStatus = namedtuple('InverterStatus',
               [ 'inputVoltage'
               , 'batteryVoltage'
               , 'batteryPercentage'
               , 'outputWatt'])


def get_client():
    port = "/dev/ttyUSB0"
    client = ModbusClient(port=port, baudrate=9600, stopbits=1, parity='N', bytesize=8, timeout=1)
    client.connect()
    return client


def read(client):
    status = None
    response = client.read_input_registers(address=0, count=125)
    if not response.isError():
        row = response.registers
        status = InverterStatus( inputVoltage      = row[1] / 10
                          , batteryVoltage    = row[17] / 100
                          , batteryPercentage = row[18]
                          , outputWatt        = row[70] / 10)

    else:
        # Something went wrong with the Modbus request
        print("Modbus error:", response)

    return status
