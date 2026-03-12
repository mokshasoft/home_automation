/*
 * growatt.h - Modbus communication with Growatt inverters
 *
 * This module handles IO. It reads from hardware and returns
 * pure value types that can be passed to the controller logic.
 */

#ifndef GROWATT_H
#define GROWATT_H

#include <modbus/modbus.h>
#include "types.h"

/* Opaque client handle */
typedef struct {
    modbus_t *ctx;
    const char *port;
} GrowattClient;

/*
 * Initialize a Modbus client for the given serial port.
 * Returns NULL on failure.
 *
 * IO function: opens serial port.
 */
GrowattClient *growatt_connect(const char *port);

/*
 * Read inverter status.
 * Returns true on success, false on failure.
 *
 * IO function: reads from Modbus.
 * Output is a pure value type.
 */
bool growatt_read(GrowattClient *client, InverterStatus *status_out);

/*
 * Close the client connection.
 *
 * IO function: closes serial port.
 */
void growatt_close(GrowattClient *client);

/*
 * Print inverter status (for debugging).
 *
 * IO function: writes to stdout.
 */
void growatt_print_status(const InverterStatus *status);

#endif /* GROWATT_H */
