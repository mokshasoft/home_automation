/*
 * switch.c - GPIO switch control implementation
 *
 * IO boundary: interacts with sysfs, returns pure values.
 */

#define _DEFAULT_SOURCE  /* for usleep */

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "switch.h"

const Pin DEFAULT_PINS[4] = {66, 67, 68, 69};
const int NUM_DEFAULT_PINS = 4;

#define GPIO_EXPORT    "/sys/class/gpio/export"
#define GPIO_UNEXPORT  "/sys/class/gpio/unexport"
#define GPIO_BASE      "/sys/class/gpio"

/* Helper: check if GPIO is already exported */
static bool gpio_exists(Pin pin) {
    char path[64];
    snprintf(path, sizeof(path), "%s/gpio%d", GPIO_BASE, pin);
    return access(path, F_OK) == 0;
}

/* Helper: write string to file */
static bool write_file(const char *path, const char *value) {
    FILE *f = fopen(path, "w");
    if (f == NULL) return false;
    fprintf(f, "%s", value);
    fclose(f);
    return true;
}

/* Helper: export GPIO pin */
static bool gpio_export(Pin pin) {
    if (gpio_exists(pin)) return true;

    char buf[16];
    snprintf(buf, sizeof(buf), "%d", pin);
    return write_file(GPIO_EXPORT, buf);
}

/* Helper: unexport GPIO pin */
static bool gpio_unexport(Pin pin) {
    if (!gpio_exists(pin)) return true;

    char buf[16];
    snprintf(buf, sizeof(buf), "%d", pin);
    return write_file(GPIO_UNEXPORT, buf);
}

/* Helper: set GPIO direction */
static bool gpio_set_direction(Pin pin, const char *dir) {
    char path[64];
    snprintf(path, sizeof(path), "%s/gpio%d/direction", GPIO_BASE, pin);
    return write_file(path, dir);
}

/* Helper: set GPIO value */
static bool gpio_set_value(Pin pin, int value) {
    char path[64];
    char buf[4];
    snprintf(path, sizeof(path), "%s/gpio%d/value", GPIO_BASE, pin);
    snprintf(buf, sizeof(buf), "%d", value);
    return write_file(path, buf);
}

SwitchHandle switch_init(Pin pin) {
    SwitchHandle sw = { .pin = pin, .is_closed = false };

    if (!gpio_export(pin)) {
        fprintf(stderr, "Failed to export GPIO %d\n", pin);
        sw.pin = -1;
        return sw;
    }

    /* Small delay for sysfs to create the files */
    usleep(100000);

    if (!gpio_set_direction(pin, "out")) {
        fprintf(stderr, "Failed to set GPIO %d direction\n", pin);
        sw.pin = -1;
        return sw;
    }

    if (!gpio_set_value(pin, 0)) {
        fprintf(stderr, "Failed to set GPIO %d value\n", pin);
        sw.pin = -1;
        return sw;
    }

    return sw;
}

SwitchHandle switch_set(SwitchHandle sw, bool closed) {
    if (sw.pin < 0) return sw;

    gpio_set_value(sw.pin, closed ? 1 : 0);
    sw.is_closed = closed;
    return sw;
}

void switch_cleanup(SwitchHandle sw) {
    if (sw.pin < 0) return;

    gpio_set_value(sw.pin, 0);
    gpio_unexport(sw.pin);
}

void switch_print(const SwitchHandle *switches, int count) {
    for (int i = 0; i < count; i++) {
        const char *state = switches[i].is_closed ? "CLOSED" : "OPEN";
        printf("Switch %d (GPIO %d): %s\n", i, switches[i].pin, state);
    }
}
