#!/usr/bin/env python3
import os
import sys
import time
import paho.mqtt.client as mqtt
from pymodbus.client.sync import ModbusSerialClient

def get_env_var(name, default=None, required=False, cast=str):
    value = os.getenv(name, default)
    if value is None and required:
        print(f"Missing required environment variable: {name}")
        sys.exit(1)
    try:
        return cast(value)
    except Exception:
        print(f"Invalid value for {name}: {value}")
        sys.exit(1)

# Environment variables
MODBUS_PORT = get_env_var("MODBUS_PORT", "/dev/ttyUSB0")
MODBUS_BAUDRATE = get_env_var("MODBUS_BAUDRATE", 9600, cast=int)
MODBUS_UNIT_ID = get_env_var("MODBUS_UNIT_ID", 1, cast=int)
BATTERY_REG = get_env_var("BATTERY_REG", required=True, cast=int)

MQTT_HOST = get_env_var("MQTT_HOST", "localhost")
MQTT_PORT = get_env_var("MQTT_PORT", 1883, cast=int)
MQTT_TOPIC = get_env_var("MQTT_TOPIC", "growatt/battery")

POLL_INTERVAL = get_env_var("POLL_INTERVAL", 10, cast=int)

# Connect to Modbus
client = ModbusSerialClient(
    method="rtu",
    port=MODBUS_PORT,
    baudrate=MODBUS_BAUDRATE,
    timeout=1
)

if not client.connect():
    print("Failed to connect to Modbus device")
    sys.exit(1)

# Connect to MQTT
mqtt_client = mqtt.Client()
mqtt_client.connect(MQTT_HOST, MQTT_PORT, 60)

print("Starting Growatt → MQTT bridge...")
while True:
    try:
        rr = client.read_holding_registers(BATTERY_REG, 1, unit=MODBUS_UNIT_ID)
        if rr.isError():
            print("Error reading battery register")
        else:
            battery_value = rr.registers[0]
            mqtt_client.publish(MQTT_TOPIC, battery_value)
            print(f"Battery: {battery_value}% → {MQTT_TOPIC}")
    except Exception as e:
        print(f"Error: {e}")
    time.sleep(POLL_INTERVAL)
