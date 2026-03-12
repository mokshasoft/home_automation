/*
 * monitor.c - Simple inverter monitoring tool
 *
 * Loops and prints inverter data every 5 seconds.
 * Useful for testing Modbus connection and debugging.
 */

#define _DEFAULT_SOURCE  /* for usleep */

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <unistd.h>
#include <string.h>

#include "growatt.h"

#define DEFAULT_PORT "/dev/ttyUSB0"
#define INTERVAL_US 5000000  /* 5 seconds */

static volatile sig_atomic_t running = 1;

static void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

static void print_usage(const char *prog) {
    fprintf(stderr, "Usage: %s [serial_port]\n", prog);
    fprintf(stderr, "  Default port: %s\n", DEFAULT_PORT);
}

int main(int argc, char *argv[]) {
    const char *port = DEFAULT_PORT;

    if (argc > 2) {
        print_usage(argv[0]);
        return 1;
    }
    if (argc == 2) {
        if (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        }
        port = argv[1];
    }

    printf("Connecting to inverter on %s...\n", port);

    /* Setup signal handlers */
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    GrowattClient *client = growatt_connect(port);
    if (client == NULL) {
        fprintf(stderr, "Failed to connect to inverter\n");
        return 1;
    }

    printf("Connected. Reading every 5 seconds (Ctrl-C to stop)\n\n");

    while (running) {
        InverterStatus status;

        if (growatt_read(client, &status)) {
            printf("----------------------------------------\n");
            growatt_print_status(&status);
            printf("\n");
        } else {
            fprintf(stderr, "Read failed, retrying...\n");
        }

        usleep(INTERVAL_US);
    }

    printf("\nDisconnecting...\n");
    growatt_close(client);

    return 0;
}
