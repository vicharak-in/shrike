// =============================================================================
// serv_rf_ram_shrike.v
// Board    : Shrike-lite  (SLG47910 Forge FPGA)
// License  : GPL-2.0
//
// Drop-in replacement for serv_rf_ram.v — FF-based register file.
//
// WHY THIS FILE EXISTS
//   serv_rf_ram.v uses a Verilog reg array which Yosys infers as a $mem cell
//   and maps to RAMSRL (shift-register LUT RAM) primitives.  The Forge PNR
//   accepts the RAMSRL cells in the netlist but silently fails to route them
//   inside serv_rf_top.  The register file outputs are unconnected.  The CPU
//   can fetch instructions but every register read returns 0, leaving SERV
//   frozen at PC=0x00000000 indefinitely.  No error is reported.
//
// THE FIX
//   (* ram_style = "registers" *) forces Yosys to implement the memory as
//   individual CLB flip-flops instead of RAMSRL cells.  The Forge PNR routes
//   standard DFFs without any issues.
//
// REGISTER ALIASING
//   DEPTH=16 stores x0–x15 physically.  x16–x31 alias to x0–x15 (the MSB of
//   any 5-bit register address is discarded).  This is safe for any program
//   that only uses x0–x15 — which includes the 1+2=3 program in nuclear_rom.v.
//
// FF BUDGET
//   DEPTH=16, RF_W=2:
//     16 × (32÷2) = 256 entries × 2 bits = 512 FFs (register file)
//     SERV CPU core state machine          ≈ 164 FFs
//     Reset counter + GPIO latch           ≈  20 FFs
//     ───────────────────────────────────────────────
//     Total                                ≈ 696 FFs  (≤ 1120 available)
//
// USAGE
//   In serv_rf_top.v, find the serv_rf_ram instantiation and change:
//     serv_rf_ram     #(.DEPTH(32), .RF_W(RF_W))  →
//     serv_rf_ram_shrike #(.DEPTH(16), .RF_W(RF_W))
//   Port names are identical — this is a true drop-in replacement.
//   Do NOT include serv_rf_ram.v in the Go Configure project.
// =============================================================================

module serv_rf_ram_shrike
  #(parameter DEPTH = 16,
    parameter RF_W  = 2)
(
   input  wire                                  i_clk,

   input  wire [RF_W-1:0]                       i_wdata,
   input  wire [$clog2(DEPTH*32/RF_W)-1:0]      i_waddr,
   input  wire                                  i_wen,

   output wire [RF_W-1:0]                       o_rdata0,
   input  wire [$clog2(DEPTH*32/RF_W)-1:0]      i_raddr0,
   input  wire                                  i_ren0,

   output wire [RF_W-1:0]                       o_rdata1,
   input  wire [$clog2(DEPTH*32/RF_W)-1:0]      i_raddr1,
   input  wire                                  i_ren1
);

  localparam MEM_DEPTH = DEPTH * 32 / RF_W;

  // Critical attribute: forces individual flip-flops, avoids RAMSRL.
  (* ram_style = "registers" *) reg [RF_W-1:0] mem [0:MEM_DEPTH-1];

  always @(posedge i_clk) begin
    if (i_wen) mem[i_waddr] <= i_wdata;
  end

  assign o_rdata0 = mem[i_raddr0];
  assign o_rdata1 = mem[i_raddr1];

endmodule
