# Define variables
TESTS_DIR := src
BIN_DIR := lua_bin
SCRIPT := ./elf2lua.py

# Get the list of subdirectories in the tests directory
SUBDIRS := $(wildcard $(TESTS_DIR)/*)

# Define the target files in the bin directory
OUT_FILES := $(patsubst $(TESTS_DIR)/%, $(BIN_DIR)/%, $(SUBDIRS))

# Default target
all: $(BIN_DIR) $(OUT_FILES)

# Rule to run make in each subdirectory, pipe the binary to the python script, and save the output
$(BIN_DIR)/%: $(TESTS_DIR)/%
	$(MAKE) -C $< 
	dir_name=$(shell basename $<); \
	cat $</out | python3 $(SCRIPT) $$dir_name > $@.lua
	cp $</verify.lua $@_verify.lua
	
# Ensure the bin directory exists
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Clean up all generated files
clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	rm -rf $(BIN_DIR)

.PHONY: all clean
