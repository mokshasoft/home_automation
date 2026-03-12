/*
 * controller.c - Pure controller logic implementation
 *
 * This module contains only pure functions.
 * No IO, no global state, no side effects.
 */

#include "controller.h"

/* Helper: add minutes to time (wraps at midnight) */
static TimeOfDay add_minutes(TimeOfDay t, int mins) {
    int total_mins = t.hour * 60 + t.minute + mins;
    if (total_mins < 0) total_mins += 24 * 60;
    total_mins = total_mins % (24 * 60);
    return (TimeOfDay){
        .hour = total_mins / 60,
        .minute = total_mins % 60,
        .second = 0
    };
}

/* Helper: compare times (returns -1, 0, 1) */
static int compare_time(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour < b.hour ? -1 : 1;
    if (a.minute != b.minute) return a.minute < b.minute ? -1 : 1;
    if (a.second != b.second) return a.second < b.second ? -1 : 1;
    return 0;
}

/* Helper: check if time is after window end */
static bool outside_solar_window(const Config *cfg, SolarWindow window, TimeOfDay now) {
    (void)cfg;
    if (!window.has_end) return false;
    TimeOfDay end = { window.end_hour, window.end_minute, 0 };
    return compare_time(now, end) > 0;
}

/* Helper: check if within active polling window */
static bool within_active_window(const Config *cfg, SolarWindow window, TimeOfDay now) {
    if (!window.has_start || !window.has_end) return true;

    TimeOfDay start = { window.start_hour, window.start_minute, 0 };
    TimeOfDay end = { window.end_hour, window.end_minute, 0 };

    TimeOfDay buffered_start = add_minutes(start, -cfg->window_buffer_minutes);
    TimeOfDay buffered_end = add_minutes(end, cfg->window_buffer_minutes);

    return compare_time(now, buffered_start) >= 0 &&
           compare_time(now, buffered_end) <= 0;
}

/* Helper: check if phase has capacity headroom */
static bool can_enable_phase(const Config *cfg, InverterStatus status) {
    return status.output_watts + cfg->load_headroom <= cfg->max_output_watts;
}

/* Helper: decide if phase should be enabled */
static bool should_enable_phase(
    const Config *cfg,
    InverterStatus status,
    bool currently_enabled,
    SolarWindow window,
    TimeOfDay now
) {
    if (outside_solar_window(cfg, window, now)) return false;
    if (status.battery_percentage >= cfg->threshold_high) return can_enable_phase(cfg, status);
    if (status.battery_percentage < cfg->threshold_low) return false;
    if (currently_enabled && !can_enable_phase(cfg, status)) return false;
    return currently_enabled;
}

/* Helper: verify PV increase after enabling switch */
static bool verify_pv_increase(const Config *cfg, double before, double after) {
    double increase = after - before;
    double expected = cfg->load_headroom - cfg->pv_increase_tolerance;
    return increase >= expected;
}

/* Helper: update solar window based on PV state transition */
static SolarWindow update_solar_window(
    const Config *cfg,
    SolarWindow window,
    double pv_watts,
    bool was_on,
    TimeOfDay now,
    bool *is_on_out
) {
    bool is_on = pv_watts > cfg->pv_on_threshold;
    *is_on_out = is_on;

    if (is_on && !was_on) {
        /* PV just turned on - record start */
        window.has_start = true;
        window.start_hour = now.hour;
        window.start_minute = now.minute;
    } else if (!is_on && was_on) {
        /* PV just turned off - record end */
        window.has_end = true;
        window.end_hour = now.hour;
        window.end_minute = now.minute;
    }
    return window;
}

/* Helper: add action to list */
static void add_action(ActionList *list, Action action) {
    if (list->count < MAX_ACTIONS) {
        list->actions[list->count++] = action;
    }
}

/*
 * decide_actions - Pure function to determine all actions
 *
 * Takes immutable inputs, returns a list of actions.
 * Does not modify any state.
 */
ActionList decide_actions(
    const Config *cfg,
    ControllerState state,
    const InverterStatus *statuses,
    int num_statuses,
    TimeOfDay now,
    int today
) {
    ActionList actions = { .count = 0 };

    double total_pv = 0;
    for (int i = 0; i < num_statuses; i++) {
        total_pv += statuses[i].pv_watts;
    }

    /* Day rollover action */
    if (today != state.last_day) {
        add_action(&actions, (Action){
            .type = ACTION_DAY_ROLLOVER,
            .window = state.today_window
        });
    }

    /* Solar window update action */
    bool new_pv_on;
    SolarWindow new_window = update_solar_window(
        cfg, state.today_window, total_pv, state.pv_was_on, now, &new_pv_on
    );
    add_action(&actions, (Action){
        .type = ACTION_UPDATE_SOLAR_WINDOW,
        .window = new_window,
        .pv_on = new_pv_on
    });

    /* Verification actions */
    if (state.pending.active) {
        if (verify_pv_increase(cfg, state.pending.pv_before, total_pv)) {
            add_action(&actions, (Action){
                .type = ACTION_VERIFY_SUCCESS,
                .phase_index = state.pending.phase_index,
                .pv_watts = total_pv
            });
        } else {
            add_action(&actions, (Action){
                .type = ACTION_VERIFY_FAILED,
                .phase_index = state.pending.phase_index,
                .pv_watts = total_pv
            });
        }
    }

    /* Use yesterday's window for decisions */
    SolarWindow window = state.yesterday_window;

    /* Disable actions - check each enabled phase */
    for (int i = 0; i < num_statuses && i < state.num_switches; i++) {
        if (state.switches_enabled[i]) {
            if (!should_enable_phase(cfg, statuses[i], true, window, now)) {
                add_action(&actions, (Action){
                    .type = ACTION_DISABLE_SWITCH,
                    .phase_index = i
                });
            }
        }
    }

    /* Enable action - find first candidate (only if no pending verification) */
    if (!state.pending.active) {
        for (int i = 0; i < num_statuses && i < state.num_switches; i++) {
            if (!state.switches_enabled[i]) {
                if (should_enable_phase(cfg, statuses[i], false, window, now)) {
                    add_action(&actions, (Action){
                        .type = ACTION_ENABLE_SWITCH,
                        .phase_index = i,
                        .pv_watts = total_pv
                    });
                    break; /* Only enable one at a time */
                }
            }
        }
    }

    return actions;
}

/*
 * apply_action - Pure state transition function
 *
 * Takes current state and action, returns new state.
 * Does not modify the input state.
 */
ControllerState apply_action(ControllerState state, Action action, int today) {
    switch (action.type) {
    case ACTION_ENABLE_SWITCH:
        state.switches_enabled[action.phase_index] = true;
        state.pending.active = true;
        state.pending.phase_index = action.phase_index;
        state.pending.pv_before = action.pv_watts;
        break;

    case ACTION_DISABLE_SWITCH:
        state.switches_enabled[action.phase_index] = false;
        break;

    case ACTION_VERIFY_SUCCESS:
        state.pending.active = false;
        break;

    case ACTION_VERIFY_FAILED:
        state.switches_enabled[action.phase_index] = false;
        state.pending.active = false;
        break;

    case ACTION_UPDATE_SOLAR_WINDOW:
        state.today_window = action.window;
        state.pv_was_on = action.pv_on;
        break;

    case ACTION_DAY_ROLLOVER:
        state.yesterday_window = action.window;
        state.today_window = (SolarWindow){ .has_start = false, .has_end = false };
        state.last_day = today;
        break;

    case ACTION_NONE:
        break;
    }
    return state;
}

/*
 * any_switch_enabled - Check if any switch is on
 */
bool any_switch_enabled(ControllerState state) {
    for (int i = 0; i < state.num_switches; i++) {
        if (state.switches_enabled[i]) return true;
    }
    return false;
}

/*
 * get_interval - Determine polling interval
 *
 * Pure function based on state.
 */
int get_interval(const Config *cfg, ControllerState state, TimeOfDay now) {
    if (any_switch_enabled(state)) {
        return cfg->interval_engaged_us;
    }
    if (within_active_window(cfg, state.yesterday_window, now)) {
        return cfg->interval_idle_us;
    }
    return cfg->interval_sleep_us;
}

/*
 * total_pv_watts - Sum PV watts from all inverters
 */
double total_pv_watts(const InverterStatus *statuses, int count) {
    double total = 0;
    for (int i = 0; i < count; i++) {
        total += statuses[i].pv_watts;
    }
    return total;
}
