#!/usr/bin/env python3
import time
import signal
import sys
import logging

LED_PATH = "/sys/class/leds/beaglebone:green:usr0/brightness"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),  # goes to systemd journal
        logging.FileHandler("/var/log/led_blink.log")
    ]
)

def write_led(value: int):
    with open(LED_PATH, "w") as f:
        f.write(str(value))

def cleanup_and_exit(signum, frame):
    logging.info("Stop blinking USR0 LED")
    write_led(0)
    sys.exit(0)

# Catch SIGTERM from systemd (when stopping service)
signal.signal(signal.SIGTERM, cleanup_and_exit)

def main():
    logging.info("Start blinking USR0 LED...")
    while True:
        logging.info("blink")
        write_led(1)
        time.sleep(0.5)
        write_led(0)
        time.sleep(0.5)

if __name__ == "__main__":
    main()
