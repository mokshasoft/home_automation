from pymodbus.client.serial import ModbusSerialClient as ModbusClient

# Replace with your actual serial port
SERIAL_PORT = '/dev/ttyUSB0'  # Or 'COM3' on Windows

# Create Modbus client
client = ModbusClient(
    port=SERIAL_PORT,
    baudrate=9600,
    timeout=1,
    parity='N',
    stopbits=1,
    bytesize=8
)

# Inverter Modbus slave ID (usually 1)
UNIT_ID = 1

def read_register(register, count=1):
    result = client.read_holding_registers(register, count, unit=UNIT_ID)
    if not result.isError():
        return result.registers
    else:
        print(f"Error reading register {register}")
        return None

if __name__ == '__main__':
    if not client.connect():
        print("Failed to connect to inverter.")
        exit(1)

    try:
        # These register addresses may vary by firmware version
        battery_voltage_raw = read_register(3510)[0]  # Register 3510: Battery voltage (tenths of volts)
        battery_current_raw = read_register(3511)[0]  # Register 3511: Battery current (tenths of amps)
        soc_raw = read_register(3515)[0]              # Register 3515: SOC (%)

        battery_voltage = battery_voltage_raw / 10.0
        battery_current = battery_current_raw / 10.0
        soc = soc_raw

        print(f"Battery Voltage: {battery_voltage} V")
        print(f"Battery Current: {battery_current} A")
        print(f"State of Charge: {soc} %")

    finally:
        client.close()
