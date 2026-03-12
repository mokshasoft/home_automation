/*
 * types.h - Core data types for the Growatt controller
 *
 * Pure value types - no pointers to mutable state
 */

#ifndef TYPES_H
#define TYPES_H

#include <stdbool.h>
#include <time.h>

#define MAX_PHASES 4

/* Configuration - immutable after initialization */
typedef struct {
    int threshold_high;        /* Enable when battery >= this */
    int threshold_low;         /* Disable when battery < this */
    double max_output_watts;   /* Max watts per inverter */
    double load_headroom;      /* Headroom needed to enable switch */
    double pv_on_threshold;    /* Watts to consider PV as "on" */
    int interval_engaged_us;   /* Microseconds when switches enabled */
    int interval_idle_us;      /* Microseconds during solar window */
    int interval_sleep_us;     /* Microseconds at night */
    int window_buffer_minutes; /* Start polling X minutes before sunrise */
    double pv_increase_tolerance;
} Config;

/* Solar window - tracks when PV is producing */
typedef struct {
    bool has_start;
    int start_hour;
    int start_minute;
    bool has_end;
    int end_hour;
    int end_minute;
} SolarWindow;

/* Pending verification state */
typedef struct {
    bool active;
    int phase_index;
    double pv_before;
} PendingVerification;

/* Controller state - passed by value to pure functions */
typedef struct {
    bool switches_enabled[MAX_PHASES];
    int num_switches;
    SolarWindow today_window;
    SolarWindow yesterday_window;
    bool pv_was_on;
    int last_day;  /* day of year */
    PendingVerification pending;
} ControllerState;

/* Inverter status reading */
typedef struct {
    double pv_voltage;
    double pv_watts;
    double battery_voltage;
    int battery_percentage;
    double output_watts;
    double utility_watts;
} InverterStatus;

/* Action types - what the controller decides to do */
typedef enum {
    ACTION_NONE,
    ACTION_ENABLE_SWITCH,
    ACTION_DISABLE_SWITCH,
    ACTION_VERIFY_SUCCESS,
    ACTION_VERIFY_FAILED,
    ACTION_UPDATE_SOLAR_WINDOW,
    ACTION_DAY_ROLLOVER
} ActionType;

/* Action with associated data */
typedef struct {
    ActionType type;
    int phase_index;
    double pv_watts;
    SolarWindow window;
    bool pv_on;
} Action;

/* List of actions (fixed size for simplicity) */
#define MAX_ACTIONS 8
typedef struct {
    Action actions[MAX_ACTIONS];
    int count;
} ActionList;

/* Time of day (for pure functions) */
typedef struct {
    int hour;
    int minute;
    int second;
} TimeOfDay;

/* Default configuration */
static inline Config default_config(void) {
    return (Config){
        .threshold_high = 95,
        .threshold_low = 90,
        .max_output_watts = 5000.0,
        .load_headroom = 2000.0,
        .pv_on_threshold = 10.0,
        .interval_engaged_us = 1000000,    /* 1 second */
        .interval_idle_us = 60000000,      /* 60 seconds */
        .interval_sleep_us = 300000000,    /* 300 seconds */
        .window_buffer_minutes = 30,
        .pv_increase_tolerance = 500.0
    };
}

/* Initial state */
static inline ControllerState initial_state(int num_switches, int today) {
    ControllerState state = {
        .num_switches = num_switches,
        .today_window = { .has_start = false, .has_end = false },
        .yesterday_window = { .has_start = false, .has_end = false },
        .pv_was_on = false,
        .last_day = today,
        .pending = { .active = false }
    };
    for (int i = 0; i < MAX_PHASES; i++) {
        state.switches_enabled[i] = false;
    }
    return state;
}

#endif /* TYPES_H */
