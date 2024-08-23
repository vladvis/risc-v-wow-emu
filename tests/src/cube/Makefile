# Define the cross-compiler and flags
CC = /opt/toolchains/riscv32/bin/riscv32-unknown-elf-gcc
CFLAGS = -Wall -O1 -no-pie
LDFLAGS = -lm -static

# Define the source and output files
ASM_SRC = test.c
OUTPUT = out 

# Define the simulator
SIMULATOR = /opt/toolchains/riscv32/bin/spike  --isa=RV32I

# Default target to build the program
all: $(OUTPUT)

# Rule to compile and link the assembly code
$(OUTPUT): $(ASM_SRC)
	$(CC) $(CFLAGS) $(ASM_SRC) $(LDFLAGS) -o $(OUTPUT)

# Test target to run the program and inspect memory with Spike in debug mode
test: $(OUTPUT)
	$(SIMULATOR) -d $(OUTPUT) | tee spike_output.log

# Rule to clean the build directory
clean:
	rm -f $(OUTPUT) 
