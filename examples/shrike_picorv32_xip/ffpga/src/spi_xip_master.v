// SPI master bridging the picorv32 native memory handshake to the RP2040
// SPI-RAM emulator. The CPU executes in place from the
// external 64 KB RAM through this module.
//
// Wire protocol (matches MichaelBell/spi-ram-emu):
//   read  = 0x03 + addr[15:0] + 32 data bits in   (full word, ascending bytes)
//   write = 0x02 + addr[15:0] + 8/16/32 data bits out
// SPI mode 0: MOSI changes while SCK is low, both sides sample on the rising
// edge. SCK = clk/4 (12.5 MHz at the 50 MHz fabric clock; emulator limit at a
// stock 125 MHz RP2040 is 12.5 MHz for reads).
//
// Byte order: the emulator RAM is byte-addressed, the CPU is little-endian.
// Byte at address A+k travels as the k-th byte on the wire (MSB first within
// each byte); mem_rdata lanes are byte-reversed from the shift register.
//
// SHRIKE PATCH (P18) bus contract: the core sends BYTE addresses (mem_addr[1:0] = the
// sub-word offset), raw unreplicated store data (bytes ascend from lane 0),
// and size-only strobes (0001/0011/1111). Alignment costs SHIFT TIME, not
// logic: writes start at the exact byte address; reads clock 8*offset extra
// bits so the addressed byte finishes in the low lane of the shift register.
//
// CS gap: the emulator needs CS high >= ~50 of its SYS clocks (0.4 us) between
// transactions. GAP_CLKS counts fabric clocks after each transaction; the gap
// overlaps the CPU's own execute cycles, so it is usually free.
//
// SHRIKE PATCH (P21): MOSI is a LOOKUP of the transaction bit index into
// mem_addr/mem_wdata (held stable by picorv32 while mem_valid is up), not a
// shift register. Command bits 0x02/0x03 differ in one place, the address is
// wired straight from mem_addr, and write bytes are selected lane-by-lane.
// The 32-bit shift register survives only as a shift-IN path for read data,
// so its per-bit input muxing (3-way load/shift) and the 7-case write-data
// packing mux are gone.

module spi_xip_master #(
	parameter GAP_CLKS = 21              // >= 0.4 us at 50 MHz (20 clocks)
)(
	input  wire        clk,
	input  wire        resetn,

	// picorv32 native memory interface (slave side; top routes ext-RAM only)
	input  wire        mem_valid,
	output reg         mem_ready,
	input  wire [31:0] mem_addr,         // [15:0] used; [1:0] always 00
	input  wire [31:0] mem_wdata,
	input  wire [ 1:0] mem_wstrb,        // 00 = read; else size
	output wire [31:0] mem_rdata,

	// SPI pads (output enables handled at the top level)
	output reg         spi_sck,
	output reg         spi_cs_n,
	output reg         spi_mosi,
	input  wire        spi_miso
);
	localparam [1:0] ST_IDLE = 2'd0, ST_XFER = 2'd1, ST_FIN = 2'd2;

	reg [1:0]  state;
	reg [1:0]  ph;            // 4 clk per SCK cycle
	reg [6:0]  bit_idx;       // 0..79: 8 cmd + 16 addr + up to 56 data bits
	reg [31:0] sh;            // read-data shift register (shift-in only)
	reg [4:0]  gap_cnt;

	// SHRIKE PATCH (P22): no latched transaction state -- mem_wstrb/mem_addr/mem_wdata are
	// held stable by picorv32 for the whole transaction, so the write flag,
	// the final-bit index, and MISO sampling all work combinationally.

	wire wr = |mem_wstrb;

	// final bit index: 24 header + (writes: 8/16/32 by size) or
	// (reads: 32 + 8*offset so the addressed byte ends aligned), minus one
	reg [6:0] txn_last;
	always @* begin
		if (!wr)
			txn_last = 7'd55 + {2'b0, mem_addr[1:0], 3'b000};
		else case (mem_wstrb)
			2'b01:   txn_last = 7'd31;   // 1 data byte
			2'b10:   txn_last = 7'd39;   // 2 data bytes
			default: txn_last = 7'd55;   // word
		endcase
	end

	// ---- MOSI lookup by bit index ----
	// bits 0..7   command, MSB first: 0x03 read / 0x02 write -> only bits 6,7 set
	// bits 8..23  the byte address: mem_addr[15:2] then (writes) mem_addr[1:0]
	//             (reads start at the word base; the offset extends the burst)
	// bits 24..   write data: byte k = lane k of mem_wdata, MSB first per byte
	wire [4:0] k = bit_idx[4:0] - 5'd24;                 // 5-bit wrap covers 24..55
	reg mosi_bit;
	always @* begin
		if (bit_idx[6:3] == 4'd0)                        // 0..7
			mosi_bit = (bit_idx[2:0] == 3'd6) || (bit_idx[2:0] == 3'd7 && !wr);
		else if (bit_idx < 7'd22)                        // 8..21
			mosi_bit = mem_addr[5'd23 - bit_idx[4:0]];
		else if (bit_idx < 7'd24)                        // 22..23
			mosi_bit = wr && mem_addr[~bit_idx[0]];
		else                                             // 24..55
			mosi_bit = mem_wdata[{k[4:3], ~k[2:0]}];
	end

	// after 32 read shifts, byte at addr A sits in sh[31:24] -> rdata[7:0]
	assign mem_rdata = {sh[7:0], sh[15:8], sh[23:16], sh[31:24]};

	always @(posedge clk) begin
		mem_ready <= 1'b0;
		if (!resetn) begin
			state    <= ST_IDLE;
			spi_cs_n <= 1'b1;
			spi_sck  <= 1'b0;
			spi_mosi <= 1'b0;
			gap_cnt  <= 5'd0;
			ph       <= 2'd0;
		end else begin
			if (gap_cnt != 0)
				gap_cnt <= gap_cnt - 1'b1;

			case (state)
				ST_IDLE: begin
					spi_sck <= 1'b0;
					if (mem_valid && !mem_ready && gap_cnt == 0) begin
						bit_idx  <= 7'd0;
						spi_cs_n <= 1'b0;
						ph       <= 2'd0;
						state    <= ST_XFER;
					end
				end

				ST_XFER: begin
					ph <= ph + 1'b1;
					case (ph)
						2'd0: begin spi_sck <= 1'b0; spi_mosi <= mosi_bit; end
						2'd1: ;
						2'd2: begin
							spi_sck <= 1'b1;
							if (!wr && bit_idx >= 7'd24)       // data bits of a read
								sh <= {sh[30:0], spi_miso};
						end
						2'd3: begin
							if (bit_idx == txn_last)
								state <= ST_FIN;
							else
								bit_idx <= bit_idx + 1'b1;
						end
					endcase
				end

				ST_FIN: begin
					spi_sck   <= 1'b0;
					spi_cs_n  <= 1'b1;
					mem_ready <= 1'b1;
					gap_cnt   <= GAP_CLKS[4:0];
					state     <= ST_IDLE;
				end
			endcase
		end
	end
endmodule
