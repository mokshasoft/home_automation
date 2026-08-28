/*
 * swrepl.c - Interactive switch control REPL
 *
 * Commands:
 *   en <ch>   - Enable (close) relay channel 0-3
 *   dis <ch>  - Disable (open) relay channel 0-3
 *   status    - Show all switch states
 *   quit      - Exit program
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "switch.h"

int main(void) {
    SwitchHandle switches[NUM_DEFAULT_PINS];
    char line[64];
    char cmd[16];
    int ch;

    printf("Initializing %d switches...\n", NUM_DEFAULT_PINS);
    for (int i = 0; i < NUM_DEFAULT_PINS; i++) {
        switches[i] = switch_init(DEFAULT_PINS[i]);
        if (switches[i].pin < 0) {
            fprintf(stderr, "Failed to init switch %d\n", i);
            return 1;
        }
    }
    printf("Ready. Commands: en <ch>, dis <ch>, status, quit\n");

    while (1) {
        printf("> ");
        fflush(stdout);

        if (fgets(line, sizeof(line), stdin) == NULL)
            break;

        if (sscanf(line, "%15s %d", cmd, &ch) >= 1) {
            if (strcmp(cmd, "quit") == 0 || strcmp(cmd, "q") == 0) {
                break;
            } else if (strcmp(cmd, "status") == 0) {
                switch_print(switches, NUM_DEFAULT_PINS);
            } else if (strcmp(cmd, "en") == 0) {
                if (ch < 0 || ch >= NUM_DEFAULT_PINS) {
                    printf("Invalid channel %d (0-%d)\n", ch, NUM_DEFAULT_PINS - 1);
                } else {
                    switches[ch] = switch_set(switches[ch], true);
                    printf("Channel %d enabled\n", ch);
                }
            } else if (strcmp(cmd, "dis") == 0) {
                if (ch < 0 || ch >= NUM_DEFAULT_PINS) {
                    printf("Invalid channel %d (0-%d)\n", ch, NUM_DEFAULT_PINS - 1);
                } else {
                    switches[ch] = switch_set(switches[ch], false);
                    printf("Channel %d disabled\n", ch);
                }
            } else {
                printf("Unknown command: %s\n", cmd);
            }
        }
    }

    printf("Cleaning up...\n");
    for (int i = 0; i < NUM_DEFAULT_PINS; i++) {
        switch_cleanup(switches[i]);
    }

    return 0;
}
