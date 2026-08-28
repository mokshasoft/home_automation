/*
 * switch.h - GPIO switch control
 *
 * IO boundary for controlling GPIO pins via sysfs.
 */

#ifndef SWITCH_H
#define SWITCH_H

#include <stdbool.h>

/* GPIO pin type */
typedef int Pin;

/* Switch handle (opaque, but simple enough to be a value) */
typedef struct {
    Pin pin;
    bool is_closed;
} SwitchHandle;

/*
 * Default GPIO pins, in ascending GPIO order:
 *   GPIO48 (P9_15), GPIO49 (P9_23), GPIO112 (P9_30), GPIO115 (P9_27).
 * See docs/relay-wiring.md for the full pin mapping.
 */
extern const Pin DEFAULT_PINS[4];
extern const int NUM_DEFAULT_PINS;

/*
 * Initialize a GPIO pin as output.
 * Returns handle on success, or handle with pin=-1 on failure.
 *
 * IO function: writes to sysfs.
 */
SwitchHandle switch_init(Pin pin);

/*
 * Set switch state.
 * Returns updated handle with new state.
 *
 * IO function: writes to sysfs.
 * Returns a value (functional style).
 */
SwitchHandle switch_set(SwitchHandle sw, bool closed);

/*
 * Cleanup a switch (unexport GPIO).
 *
 * IO function: writes to sysfs.
 */
void switch_cleanup(SwitchHandle sw);

/*
 * Print switch states (for debugging).
 *
 * IO function: writes to stdout.
 */
void switch_print(const SwitchHandle *switches, int count);

#endif /* SWITCH_H */
