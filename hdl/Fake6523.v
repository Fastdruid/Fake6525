`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    Fake6523 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.02 - Fixed for 1551
// Revision 0.02a - Added comments only. 
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Fake6523(
    input _reset,     // Active-low reset signal
    input _cs,        // Active-low chip select signal
    input [2:0]rs,    // 3-bit register select
    input _write,     // Active-low write signal
    inout [7:0]data,  // 8-bit bidirectional data bus
    inout [7:0]port_a, // 8-bit bidirectional port A
    inout [7:0]port_b, // 8-bit bidirectional port B
    inout [7:0]port_c  // 8-bit bidirectional port C
);

reg [7:0]data_out;    // 8-bit register to hold output data
reg [2:0] rs_r;       // Register to store the current register select value
wire clock = !_cs;    // Clock signal derived from inverted chip select

wire [7:0] data_ddr_a; // Data Direction Register for port A
wire [7:0] data_ddr_b; // Data Direction Register for port B
wire [7:0] data_ddr_c; // Data Direction Register for port C

// Write enable signals for DDRs and ports, active when write is low and corresponding register is selected
wire we_ddr_a = !_write & (rs_r == 3'd3);
wire we_ddr_b = !_write & (rs_r == 3'd4);
wire we_ddr_c = !_write & (rs_r == 3'd5);
wire we_port_a = !_write & (rs_r == 3'd0);
wire we_port_b = !_write & (rs_r == 3'd1);
wire we_port_c = !_write & (rs_r == 3'd2);

// Instantiate ioport module for port A
ioport ioport_a(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_a), 
    .data_ddr(data_ddr_a), 
    .we_port(we_port_a), 
    .pins(port_a)
);

// Instantiate ioport module for port B
ioport ioport_b(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_b), 
    .data_ddr(data_ddr_b), 
    .we_port(we_port_b), 
    .pins(port_b)
);

// Instantiate ioport module for port C
ioport ioport_c(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_c), 
    .data_ddr(data_ddr_c), 
    .we_port(we_port_c), 
    .pins(port_c)
);

// Control the bidirectional data bus
assign data = (!_cs & _write ? data_out : 8'bz);  // Output data when chip select is active and write is inactive, otherwise high impedance

// Always block triggered on the positive edge of the clock
always @(posedge clock)
begin
   rs_r = rs;  // Update rs_r with current rs value
   case(rs_r)  // Set data_out based on the rs_r value
      0: data_out = port_a;     // Read port A
      1: data_out = port_b;     // Read port B
      2: data_out = port_c;     // Read port C
      3: data_out = data_ddr_a; // Read DDR A
      4: data_out = data_ddr_b; // Read DDR B
      5: data_out = data_ddr_c; // Read DDR C
      default: data_out = 8'bz; // Default to high impedance
   endcase
end

endmodule
