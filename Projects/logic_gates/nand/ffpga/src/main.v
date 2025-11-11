//-----------------------------------------------------------------------------
// Company:         Vicharak Computers PVT LTD
// Engineer:        Shashank Bhosagi <shashankbhosagi0121@gmail.com>
// 
// Create Date:     NOV 11, 2025
// Design Name:     Basic Logic Gates
// Module Name:     nand_gate
// Project:         Shrike-Lite Examples
// Target Device:   Shrike-Lite (RP2040 + Renesas FPGA (SLG47910V))
// Tool Versions:   Go Configure Software Hub v.6.48
// 
// Description: 
//    Simple 2-input NAND gate implementation for beginners exploring
//    FPGA design using Verilog on the Shrike-Lite.
// Dependencies: 
// None
//
// Version:
//    1.0 - 11/11/2025 - Initial release
// 
// Additional Comments: 
//    This project is part of https://github.com/vicharak-in/shrike-lite.
//    All logic gate examples (AND, OR, NOT, NAND, NOR, XOR) are
//    available under the same structure. 
// License: 
//    Open Source — MIT License
//    Copyright © 2025 Vicharak Computers Pvt. Ltd
//-----------------------------------------------------------------------------


(* top *) module nand_gate(
  (* iopad_external_pin *) output LED,
  (* iopad_external_pin *) output LED_en,
  (* iopad_external_pin *) input a,  
  (* iopad_external_pin *) input b,
  );
  
  assign LED_en = 1'b1;
  wire and_output;
  
  assign and_output = a & b;
  assign LED = ~(and_output);
  
endmodule
