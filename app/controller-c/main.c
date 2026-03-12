/*
 * main.c - Controller main loop
 *
 * This is the IO shell that:
 * 1. Reads from hardware (Modbus, clock)
 * 2. Calls pure functions to decide actions
 * 3. Performs IO for each action
 *
 * The pattern mirrors the Haskell version:
 * - Pure core (controller.c) has no side effects
 * - IO happens only at the edges (this file)
 */

#define _DEFAULT_SOURCE  /* for usleep */

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <time.h>
#include <errno.h>

#include "types.h"
#include "controller.h"
#include "growatt.h"
#include "switch.h"

#define NUM_PHASES 3

static const char *DEFAULT_PORTS[NUM_PHASES] = {
    "/dev/ttyUSB0",
    "/dev/ttyUSB1",
    "/dev/ttyUSB2"
};

/* Global flag for clean shutdown */
static volatile sig_atomic_t running = 1;

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

/* Get current time as pure value */
static TimeOfDay get_current_time(void) {
    time_t now = time(NULL);
    struct tm *tm = localtime(&now);
    return (TimeOfDay){
        .hour = tm->tm_hour,
        .minute = tm->tm_min,
        .second = tm->tm_sec
    };
}

/* Get day of year */
static int get_day_of_year(void) {
    time_t now = time(NULL);
    struct tm *tm = localtime(&now);
    return tm->tm_yday;
}

/* Perform IO for a single action */
static void perform_action(Action action, SwitchHandle *switches) {
    switch (action.type) {
    case ACTION_ENABLE_SWITCH:
        printf("Engaging phase %d for verification (PV: %.1fW)\n",
               action.phase_index, action.pv_watts);
        switches[action.phase_index] = switch_set(switches[action.phase_index], true);
        break;

    case ACTION_DISABLE_SWITCH:
        printf("Disabling phase %d\n", action.phase_index);
        switches[action.phase_index] = switch_set(switches[action.phase_index], false);
        break;

    case ACTION_VERIFY_SUCCESS:
        printf("Phase %d verified (PV: %.1fW)\n",
               action.phase_index, action.pv_watts);
        break;

    case ACTION_VERIFY_FAILED:
        printf("Phase %d failed verification (PV: %.1fW), disabling\n",
               action.phase_index, action.pv_watts);
        switches[action.phase_index] = switch_set(switches[action.phase_index], false);
        break;

    case ACTION_DAY_ROLLOVER:
        printf("New day - yesterday's window: %02d:%02d - %02d:%02d\n",
               action.window.start_hour, action.window.start_minute,
               action.window.end_hour, action.window.end_minute);
        break;

    case ACTION_UPDATE_SOLAR_WINDOW:
    case ACTION_NONE:
        /* Silent actions */
        break;
    }
}

/* Print status summary */
static void print_status(const InverterStatus *statuses, int count,
                         const bool *enabled) {
    printf("--- Controller Status ---\n");
    if (count > 0) {
        printf("Battery: %d%%\n", statuses[0].battery_percentage);
    }
    for (int i = 0; i < count; i++) {
        const char *state = enabled[i] ? "ON" : "OFF";
        printf("Phase %d: %.1fW [%s]\n", i, statuses[i].output_watts, state);
    }
    printf("\n");
}

int main(void) {
    printf("Starting inverter controller...\n");

    /* Setup signal handlers for clean shutdown */
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    /* Initialize configuration (pure value) */
    Config cfg = default_config();

    /* IO: Connect to inverters */
    GrowattClient *clients[NUM_PHASES];
    int connected = 0;
    for (int i = 0; i < NUM_PHASES; i++) {
        clients[i] = growatt_connect(DEFAULT_PORTS[i]);
        if (clients[i] != NULL) connected++;
    }

    if (connected == 0) {
        fprintf(stderr, "Failed to connect to any inverters\n");
        return 1;
    }
    printf("Connected to %d inverters\n", connected);

    /* IO: Initialize switches */
    SwitchHandle switches[NUM_PHASES];
    for (int i = 0; i < NUM_PHASES; i++) {
        if (i < NUM_DEFAULT_PINS) {
            switches[i] = switch_init(DEFAULT_PINS[i]);
        } else {
            switches[i] = (SwitchHandle){ .pin = -1, .is_closed = false };
        }
    }

    /* Initialize state (pure value) */
    ControllerState state = initial_state(NUM_PHASES, get_day_of_year());

    /* Main loop */
    while (running) {
        /* IO: Read all inverters */
        InverterStatus statuses[NUM_PHASES];
        int read_count = 0;
        for (int i = 0; i < NUM_PHASES; i++) {
            if (clients[i] != NULL) {
                if (growatt_read(clients[i], &statuses[read_count])) {
                    read_count++;
                }
            }
        }

        if (read_count != NUM_PHASES) {
            fprintf(stderr, "Warning: got %d statuses for %d phases\n",
                    read_count, NUM_PHASES);
            usleep(cfg.interval_idle_us);
            continue;
        }

        /* Get current time (IO -> pure value) */
        TimeOfDay now = get_current_time();
        int today = get_day_of_year();

        /* PURE: Decide actions based on state and inputs */
        ActionList actions = decide_actions(&cfg, state, statuses,
                                            NUM_PHASES, now, today);

        /* PURE: Apply actions to get new state */
        for (int i = 0; i < actions.count; i++) {
            state = apply_action(state, actions.actions[i], today);
        }

        /* IO: Perform side effects for each action */
        for (int i = 0; i < actions.count; i++) {
            perform_action(actions.actions[i], switches);
        }

        /* IO: Print status */
        print_status(statuses, NUM_PHASES, state.switches_enabled);

        /* PURE: Calculate sleep interval */
        int interval = get_interval(&cfg, state, now);

        /* IO: Sleep */
        usleep(interval);
    }

    /* Cleanup */
    printf("\nShutting down...\n");

    for (int i = 0; i < NUM_PHASES; i++) {
        switch_cleanup(switches[i]);
        growatt_close(clients[i]);
    }

    printf("Done.\n");
    return 0;
}
