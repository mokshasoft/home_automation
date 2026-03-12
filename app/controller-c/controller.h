/*
 * controller.h - Pure controller logic
 *
 * All functions are pure: no IO, no side effects.
 * They take values and return values.
 */

#ifndef CONTROLLER_H
#define CONTROLLER_H

#include "types.h"

/*
 * Decide what actions to take based on current state and readings.
 * Pure function: state + inputs -> actions
 */
ActionList decide_actions(
    const Config *cfg,
    ControllerState state,
    const InverterStatus *statuses,
    int num_statuses,
    TimeOfDay now,
    int today
);

/*
 * Apply an action to produce a new state.
 * Pure function: state + action -> new state
 */
ControllerState apply_action(ControllerState state, Action action, int today);

/*
 * Get the polling interval based on current state.
 * Pure function: state -> interval
 */
int get_interval(const Config *cfg, ControllerState state, TimeOfDay now);

/*
 * Check if any switch is enabled.
 * Pure function.
 */
bool any_switch_enabled(ControllerState state);

/*
 * Get total PV watts from all inverters.
 * Pure function.
 */
double total_pv_watts(const InverterStatus *statuses, int count);

#endif /* CONTROLLER_H */
