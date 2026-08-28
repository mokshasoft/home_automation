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

# Switch REPL (interactive switch control)
SWREPL_SRCS = swrepl.c switch.c
SWREPL_OBJS = swrepl.o switch.o
SWREPL = swrepl

.PHONY: all clean

all: $(CONTROLLER) $(MONITOR) $(SWREPL)

$(CONTROLLER): $(CONTROLLER_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(MONITOR): $(MONITOR_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(SWREPL): $(SWREPL_OBJS)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Dependencies
main.o: main.c types.h controller.h growatt.h switch.h
controller.o: controller.c controller.h types.h
growatt.o: growatt.c growatt.h types.h
switch.o: switch.c switch.h
monitor.o: monitor.c growatt.h types.h
swrepl.o: swrepl.c switch.h

clean:
	rm -f $(CONTROLLER_OBJS) $(CONTROLLER) monitor.o $(MONITOR) swrepl.o $(SWREPL)
