/*
 * growatt.c - Modbus communication implementation
 *
 * IO boundary: reads hardware, produces pure values.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include "growatt.h"

#define NUM_REGISTERS 125

GrowattClient *growatt_connect(const char *port) {
    modbus_t *ctx = modbus_new_rtu(port, 9600, 'N', 8, 1);
    if (ctx == NULL) {
        fprintf(stderr, "Failed to create Modbus context for %s\n", port);
        return NULL;
    }

    if (modbus_set_slave(ctx, 0) == -1) {
        fprintf(stderr, "Failed to set slave address: %s\n", modbus_strerror(errno));
        modbus_free(ctx);
        return NULL;
    }

    if (modbus_connect(ctx) == -1) {
        fprintf(stderr, "Modbus connection failed for %s: %s\n",
                port, modbus_strerror(errno));
        modbus_free(ctx);
        return NULL;
    }

    GrowattClient *client = malloc(sizeof(GrowattClient));
    if (client == NULL) {
        modbus_close(ctx);
        modbus_free(ctx);
        return NULL;
    }

    client->ctx = ctx;
    client->port = port;
    return client;
}

/* Helper: read double register (high/low word) */
static double read_double_reg(const uint16_t *regs, int idx, double scale) {
    double high = regs[idx];
    double low = regs[idx + 1];
    return (high * 65536.0 + low) * scale;
}

/* Helper: read single register */
static double read_single_reg(const uint16_t *regs, int idx, double scale) {
    return (double)regs[idx] * scale;
}

bool growatt_read(GrowattClient *client, InverterStatus *status_out) {
    uint16_t regs[NUM_REGISTERS];

    int rc = modbus_read_input_registers(client->ctx, 0, NUM_REGISTERS, regs);
    if (rc == -1) {
        fprintf(stderr, "Modbus read failed for %s: %s\n",
                client->port, modbus_strerror(errno));
        return false;
    }

    /* Parse registers into pure value type */
    *status_out = (InverterStatus){
        .pv_voltage = read_single_reg(regs, 1, 0.1),
        .pv_watts = read_double_reg(regs, 3, 0.1),
        .battery_voltage = read_single_reg(regs, 17, 0.01),
        .battery_percentage = (int)regs[18],
        .output_watts = read_single_reg(regs, 70, 0.1),
        .utility_watts = read_double_reg(regs, 21, 0.1)
    };

    return true;
}

void growatt_close(GrowattClient *client) {
    if (client != NULL) {
        if (client->ctx != NULL) {
            modbus_close(client->ctx);
            modbus_free(client->ctx);
        }
        free(client);
    }
}

void growatt_print_status(const InverterStatus *status) {
    printf("PV voltage     : %.1f V\n", status->pv_voltage);
    printf("PV watts       : %.1f W\n", status->pv_watts);
    printf("Battery voltage: %.2f V\n", status->battery_voltage);
    printf("Battery percent: %d%%\n", status->battery_percentage);
    printf("Output watts   : %.1f W\n", status->output_watts);
    printf("Utility watts  : %.1f W\n", status->utility_watts);
}
