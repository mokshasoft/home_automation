#!/bin/bash
# bbb-pins.sh - Identify and verify every pin used by the controller.
#
# Run ON the BeagleBone Black:
#   scp scripts/bbb-pins.sh debian@192.168.7.2:/tmp/
#   ssh debian@192.168.7.2 "sudo bash /tmp/bbb-pins.sh"
#
# Reports facts only; it does not change any configuration.
# The --toggle option drives each relay GPIO so you can confirm with a
# multimeter which physical P9 pin actually moves.

set -u

# GPIO, P9 pin, control-module offset, signal name
# Relay channels, in ascending GPIO order (ch0..ch3 -> ULN2803 IN1..IN4).
PINS=(
    "48:P9_15:0x840:gpmc_a0"
    "49:P9_23:0x844:gpmc_a1"
    "112:P9_30:0x998:mcasp0_axr0"
    "115:P9_27:0x9a4:mcasp0_fsr"
)
# Known-unusable: P9_25/GPIO117 is owned by 48038000.mcasp (HDMI audio).
KNOWN_BAD=(
    "117:P9_25:0x9ac:mcasp0_ahclkx"
)
I2C_PINS=(
    "13:P9_19:0x97c:uart1_rtsn/i2c2_scl"
    "12:P9_20:0x978:uart1_ctsn/i2c2_sda"
)

hr() { printf '%s\n' "----------------------------------------------------------------"; }
hdr() { hr; printf '%s\n' "$1"; hr; }

if [ "${1:-}" = "--hold" ]; then
    # Drive ONE pin HIGH and keep it there, so it can be hunted with a meter.
    # Usage: bbb-pins.sh --hold <gpio> [seconds]     (default 60s)
    hold_gpio="${2:-}"
    hold_secs="${3:-60}"
    if [ -z "$hold_gpio" ]; then
        echo "usage: $0 --hold <gpio> [seconds]"
        echo "relay channels: 48 (P9_15), 49 (P9_23), 112 (P9_30), 115 (P9_27)"
        exit 1
    fi
    label=""
    for entry in "${PINS[@]}"; do
        IFS=: read -r g p9 off sig <<< "$entry"
        [ "$g" = "$hold_gpio" ] && label=" ($p9)"
    done
    hdr "HOLDING GPIO${hold_gpio}${label} HIGH for ${hold_secs}s"
    { echo "$hold_gpio" > /sys/class/gpio/export; } 2>/dev/null
    sleep 0.3
    if [ ! -d "/sys/class/gpio/gpio$hold_gpio" ]; then
        echo "could not export GPIO$hold_gpio"; exit 1
    fi
    echo out > "/sys/class/gpio/gpio$hold_gpio/direction"
    echo 1 > "/sys/class/gpio/gpio$hold_gpio/value"
    echo "Pin is HIGH. Probe for 3.3V against a GND pin (P9_1, P9_2, P9_43..P9_46)."
    echo "Every other GPIO on the header stays LOW, so exactly one pin reads 3.3V."
    echo "Releasing in ${hold_secs}s ..."
    sleep "$hold_secs"
    echo 0 > "/sys/class/gpio/gpio$hold_gpio/value"
    { echo "$hold_gpio" > /sys/class/gpio/unexport; } 2>/dev/null
    echo "Released; pin is LOW and unexported."
    exit 0
fi


hdr "1. Board and kernel"
[ -r /proc/device-tree/model ] && printf 'Model:  %s\n' "$(tr -d '\0' < /proc/device-tree/model)"
printf 'Kernel: %s\n' "$(uname -r)"
[ -r /etc/dogtag ] && printf 'Image:  %s\n' "$(cat /etc/dogtag)"

hdr "2. Device-tree overlays (HDMI/audio can steal McASP0 pins)"
if [ -r /boot/uEnv.txt ]; then
    grep -E '^[^#]*(overlay|dtb|cape)' /boot/uEnv.txt || echo "(no active overlay lines)"
else
    echo "/boot/uEnv.txt not present"
fi
echo
echo "Loaded overlays:"
if [ -d /proc/device-tree/chosen/overlays ]; then
    ls -1 /proc/device-tree/chosen/overlays 2>/dev/null | grep -v '^name$' || echo "(none)"
else
    echo "(no /proc/device-tree/chosen/overlays)"
fi

hdr "3. gpiochip bases  <-- decides if sysfs numbers 49/112/115/117 are valid"
if [ -d /sys/class/gpio ]; then
    for c in /sys/class/gpio/gpiochip*; do
        [ -e "$c" ] || continue
        printf '%-28s base=%-5s ngpio=%-4s label=%s\n' \
            "$(basename "$c")" \
            "$(cat "$c/base" 2>/dev/null)" \
            "$(cat "$c/ngpio" 2>/dev/null)" \
            "$(cat "$c/label" 2>/dev/null)"
    done
    echo
    echo "EXPECTED for switch.c to be correct: a chip with base=0 label=gpio-0-31,"
    echo "i.e. the four banks based at 0, 32, 64, 96. If the bases start at 512"
    echo "(or anything else), the hardcoded numbers in switch.c address WRONG lines."
else
    echo "/sys/class/gpio missing - CONFIG_GPIO_SYSFS not enabled in this kernel."
    echo "switch.c would need porting to libgpiod (/dev/gpiochipN)."
fi

hdr "4. libgpiod view (authoritative line names and who holds them)"
if command -v gpiodetect >/dev/null 2>&1; then
    gpiodetect
    echo
    for bank in 1 3; do
        echo "--- gpiochip$bank ---"
        gpioinfo "gpiochip$bank" 2>/dev/null | grep -E 'line +(1[6-9]|2[01]|17)\b' || true
    done
    echo
    echo "(full dump of any line that is currently 'used':)"
    gpioinfo 2>/dev/null | grep used || echo "(no lines reported as used)"
else
    echo "gpiod tools not installed.  sudo apt-get install -y gpiod"
fi

hdr "5. Pinmux claims for OUR pins  <-- proves whether HDMI audio took them"
PINMUX=/sys/kernel/debug/pinctrl/44e10800.pinmux
if [ ! -d "$PINMUX" ]; then
    PINMUX=$(ls -d /sys/kernel/debug/pinctrl/*pinmux* 2>/dev/null | head -1)
fi
if [ -n "${PINMUX:-}" ] && [ -d "$PINMUX" ]; then
    echo "Using $PINMUX"
    echo
    for entry in "${PINS[@]}" "${KNOWN_BAD[@]}" "${I2C_PINS[@]}"; do
        IFS=: read -r gpio p9 off sig <<< "$entry"
        printf '%-6s GPIO%-4s %-22s ' "$p9" "$gpio" "$sig"
        line=$(grep -i "$(printf '%s' "${off#0x}")" "$PINMUX/pins" 2>/dev/null | head -1)
        if [ -n "$line" ]; then
            printf '%s\n' "$line"
        else
            printf '(offset %s not found in pins file)\n' "$off"
        fi
    done
    echo
    echo "Driver claims (pinmux-pins). This file is indexed by PIN NUMBER,"
    echo "not by register address, so look pins up by index = (offset-0x800)/4:"
    for entry in "${PINS[@]}" "${KNOWN_BAD[@]}" "${I2C_PINS[@]}"; do
        IFS=: read -r gpio p9 off sig <<< "$entry"
        idx=$(( ( off - 0x800 ) / 4 ))
        line=$(grep -E "^pin $idx " "$PINMUX/pinmux-pins" 2>/dev/null \
               | sed -E "s/^pin $idx \\([^)]*\\): //")
        printf '  %-6s GPIO%-4s pin %-4s %s\n' "$p9" "$gpio" "$idx" "${line:-(not listed)}"
    done
    echo
    echo "A line ending in 'UNCLAIMED' is free for GPIO use."
    echo "A line naming a device (e.g. davinci-mcasp / hdmi) means that pin is TAKEN."
else
    echo "debugfs pinctrl not mounted. Try: sudo mount -t debugfs none /sys/kernel/debug"
fi

hdr "6. I2C buses (OLED expected at 0x3c)"
ls -1 /dev/i2c-* 2>/dev/null || echo "(no /dev/i2c-* nodes)"
echo
if command -v i2cdetect >/dev/null 2>&1; then
    for bus in $(ls /dev/i2c-* 2>/dev/null | sed 's|/dev/i2c-||'); do
        echo "--- bus $bus ---"
        i2cdetect -y -r "$bus" 2>&1 | sed 's/^/  /'
    done
else
    echo "i2cdetect not installed.  sudo apt-get install -y i2c-tools"
fi

hdr "7. USB serial adapters (Growatt RS485)"
ls -la /dev/ttyUSB* 2>/dev/null || echo "(no /dev/ttyUSB* - RS485 adapters not plugged in)"
echo
command -v lsusb >/dev/null 2>&1 && lsusb

hdr "8. Export test - can each relay GPIO actually be claimed?"
if [ ! -w /sys/class/gpio/export ]; then
    echo "/sys/class/gpio/export is not writable here."
    echo "Either this kernel lacks CONFIG_GPIO_SYSFS, or you are not root."
    echo "Skipping export and toggle tests."
    exit 0
fi
for entry in "${PINS[@]}"; do
    IFS=: read -r gpio p9 off sig <<< "$entry"
    printf '%-6s GPIO%-4s ' "$p9" "$gpio"
    if [ -d "/sys/class/gpio/gpio$gpio" ]; then
        echo "already exported (direction=$(cat "/sys/class/gpio/gpio$gpio/direction" 2>/dev/null), value=$(cat "/sys/class/gpio/gpio$gpio/value" 2>/dev/null))"
        continue
    fi
    if { echo "$gpio" > /sys/class/gpio/export; } 2>/dev/null; then
        sleep 0.2
        if [ -d "/sys/class/gpio/gpio$gpio" ]; then
            echo "EXPORT OK"
            { echo "$gpio" > /sys/class/gpio/unexport; } 2>/dev/null
        else
            echo "export wrote but no sysfs dir appeared"
        fi
    else
        echo "EXPORT FAILED (busy = claimed by another driver, or bad number)"
    fi
done

if [ "${1:-}" = "--toggle" ]; then
    hdr "9. Toggle test - measure each P9 pin against P9_1 (GND) with a meter"
    echo "Each pin is driven HIGH for 3s, then LOW. Expect 3.3V then 0V."
    echo
    for entry in "${PINS[@]}"; do
        IFS=: read -r gpio p9 off sig <<< "$entry"
        { echo "$gpio" > /sys/class/gpio/export; } 2>/dev/null
        sleep 0.2
        if [ ! -d "/sys/class/gpio/gpio$gpio" ]; then
            echo "$p9 GPIO$gpio: cannot export, skipping"
            continue
        fi
        echo out > "/sys/class/gpio/gpio$gpio/direction"
        printf '>>> %s (GPIO%s) HIGH - measure now ... ' "$p9" "$gpio"
        echo 1 > "/sys/class/gpio/gpio$gpio/value"
        sleep 3
        echo 0 > "/sys/class/gpio/gpio$gpio/value"
        echo "LOW"
        { echo "$gpio" > /sys/class/gpio/unexport; } 2>/dev/null
        sleep 1
    done
    echo
    echo "Toggle test done. All pins returned LOW."
else
    hr
    echo "Multimeter helpers:"
    echo "  sudo bash $0 --toggle              # pulse each relay pin HIGH 3s"
    echo "  sudo bash $0 --hold <gpio> [secs]  # hold ONE pin HIGH to hunt for it"
    hr
fi
