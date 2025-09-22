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
    result = client.read_holding_registers(register, count=count, device_id=UNIT_ID)
    if not result.isError():
        return result.registers
    else:
        print(f"Error reading register {register}")
        return None

def loop_registers(low, high):
    for register in range(low, high):
        try:
            # Attempt to read the register
            raw_value = read_register(register)[0]
            if raw_value is not None:
                # Print the result, flush the output immediately
                print(f"Register {register} raw value: {raw_value} | {hex(raw_value)}", flush=True)
        except ModbusIOException as e:
            # Catch Modbus-specific errors like no response after retries
            print(f"Modbus Error for Register {register}: {e}", flush=True)
        except Exception as e:
            # Catch any other general exceptions
            print(f"Error reading Register {register}: {e}", flush=True)
            
def register_repl():
    print("Connected to inverter. You can now enter register addresses to read (or type 'exit' to quit).")
    
    while True:
        try:
            # Ask user for register address
            register_input = input("Enter Modbus register address (hex or dec) or 'exit' to quit: ")
            
            if register_input.lower() == 'exit':
                print("Exiting REPL.")
                break

            # Convert register input to integer (handles both hex and decimal)
            if register_input.startswith('0x'):
                register = int(register_input, 16)
            else:
                register = int(register_input)

            # Read the register value(s)
            result = read_register(register)
            
            if result:
                print(f"Register {hex(register)}: {result[0]} (Decimal) | {hex(result[0])} (Hex)")

        except ValueError:
            print("Invalid input. Please enter a valid register address (hex or decimal).")
    
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

        # register_repl()
        loop_registers(2000, 3000)
    finally:
        client.close()
