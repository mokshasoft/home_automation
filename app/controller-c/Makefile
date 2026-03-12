CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -O2 -std=c11
LDFLAGS = -lmodbus

# Controller (full application)
CONTROLLER_SRCS = main.c controller.c growatt.c switch.c
CONTROLLER_OBJS = $(CONTROLLER_SRCS:.c=.o)
CONTROLLER = controller

# Monitor (simple status reader)
MONITOR_SRCS = monitor.c growatt.c
MONITOR_OBJS = monitor.o growatt.o
MONITOR = monitor

.PHONY: all clean

all: $(CONTROLLER) $(MONITOR)

$(CONTROLLER): $(CONTROLLER_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(MONITOR): $(MONITOR_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Dependencies
main.o: main.c types.h controller.h growatt.h switch.h
controller.o: controller.c controller.h types.h
growatt.o: growatt.c growatt.h types.h
switch.o: switch.c switch.h
monitor.o: monitor.c growatt.h types.h

clean:
	rm -f $(CONTROLLER_OBJS) $(CONTROLLER) monitor.o $(MONITOR)
