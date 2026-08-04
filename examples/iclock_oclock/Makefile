IVERILOG  ?= iverilog
VVP       ?= vvp
VERILATOR ?= verilator

TOP       := iclock_oclock_tb
RTL       := ffpga/src/iclock_oclock.v
TESTBENCH := ffpga/sim/iclock_oclock_tb.v
BUILD_DIR := build
SIMULATOR := $(BUILD_DIR)/$(TOP)

.DEFAULT_GOAL := test

.PHONY: test icarus verilator clean help

# Run every available RTL check.
test: icarus verilator

# Compile and execute the self-checking testbench with Icarus Verilog.
icarus: $(SIMULATOR)
	$(VVP) $(SIMULATOR)

$(SIMULATOR): $(RTL) $(TESTBENCH) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s $(TOP) -o $@ $(RTL) $(TESTBENCH)

$(BUILD_DIR):
	mkdir -p $@

# Elaborate and lint the design and testbench with Verilator.
verilator:
	$(VERILATOR) --lint-only --timing -Wall \
		-Wno-BLKSEQ -Wno-PROCASSINIT $(RTL) $(TESTBENCH)

clean:
	$(RM) -r $(BUILD_DIR)

help:
	@echo "make test       Run Icarus simulation and Verilator lint (default)"
	@echo "make icarus    Compile and run the self-checking Icarus simulation"
	@echo "make verilator Run Verilator elaboration and lint"
	@echo "make clean      Remove generated simulation files"
