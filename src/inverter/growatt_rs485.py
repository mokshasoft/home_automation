from collections import namedtuple

# Define the structure with fields
InverterStatus = namedtuple('InverterStatus', ['chargeCurrent', 'batteryPercentage', 'temperature'])

def read():
    # Example data (chargeCurrent in Amps, batteryPercentage as %, temperature in °C)
    battery_data = InverterStatus(chargeCurrent=3.5, batteryPercentage=80.5, temperature=25.0)
    return battery_data
