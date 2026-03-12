CC ?= gcc
CFLAGS = -Wall -Wextra -Werror -O2 -std=c11
LDFLAGS = -lmodbus

SRCS = main.c controller.c growatt.c switch.c
OBJS = $(SRCS:.c=.o)
TARGET = controller

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Dependencies
main.o: main.c types.h controller.h growatt.h switch.h
controller.o: controller.c controller.h types.h
growatt.o: growatt.c growatt.h types.h
switch.o: switch.c switch.h

clean:
	rm -f $(OBJS) $(TARGET)
