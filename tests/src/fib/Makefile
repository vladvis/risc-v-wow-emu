# Makefile for Fibonacci program

# Compiler to use
CC = /opt/toolchains/riscv32/bin/riscv32-unknown-elf-gcc

# Compiler flags
CFLAGS = -Wall -O0 -nostdlib -no-pie

# Target executable name
TARGET = out

# Source file
SRC = fib.c

# Default target
all: $(TARGET)

# Rule to build the target
$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

# Clean rule to remove the generated files
clean:
	rm -f $(TARGET)

# Phony targets
.PHONY: all clean