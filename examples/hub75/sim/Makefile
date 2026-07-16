# HUB75 simulation (Icarus Verilog).  Usage:  make        (build + run)
#                                             make wave   (open VCD in gtkwave)
#                                             make clean

TOP := ../src/main.v
TB := tb_hub75.v
IMAGE := image_8x8.hex
OUT := tb_hub75.vvp
VCD := tb_hub75.vcd

# HUB75_SIM_INIT preloads the framebuffer from IMAGE via $readmemh.
DEFS := -DHUB75_SIM_INIT -DHUB75_INIT_FILE='"$(IMAGE)"'

all: run

$(OUT): $(TOP) $(TB) $(IMAGE)
	iverilog -g2012 -Wall $(DEFS) -o $(OUT) $(TOP) $(TB)

run: $(OUT)
	vvp $(OUT)

wave: $(VCD)
	gtkwave $(VCD)

clean:
	rm -f $(OUT) $(VCD)

.PHONY: all run wave clean
