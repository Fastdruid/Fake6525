`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    
// Design Name: 
// Module Name:    Fake6525
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
// Revision 0.03 - Changed to 6525
// Additional Comments: 
// 
//////////////////////////////////////////////////////////////////////////////////
module Fake6525(
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

reg [7:0] control_register;
reg [7:0] active_interrupt_register;
reg mode; 
    
wire cb = port_c[7];
wire ca = port_c[6];
wire irq_n = port_c[5];
wire [4:0] interrupt_inputs = port_c[4:0];
reg [4:0] interrupt_latches;

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
    .pins(mode ? {port_c[7:5], interrupt_inputs} : port_c)
);
always @(posedge clock or negedge _reset) begin
    if (!_reset) begin
        control_register <= 8'b0;
        active_interrupt_register <= 8'b0;
        mode <= 1'b0;
        interrupt_latches <= 5'b0;
    end else begin
        if (!_write) begin
            case (rs_r)
                3'd6: control_register <= data;
                3'd7: active_interrupt_register <= data;
            endcase
        end
        
        mode <= control_register[0];
        
        if (mode) begin
            // Mode 1 interrupt logic
            interrupt_latches[1:0] <= interrupt_latches[1:0] | ~interrupt_inputs[1:0];
            interrupt_latches[2] <= interrupt_latches[2] | (control_register[2] ? interrupt_inputs[2] : ~interrupt_inputs[2]);
            interrupt_latches[3] <= interrupt_latches[3] | (control_register[3] ? interrupt_inputs[3] : ~interrupt_inputs[3]);
            
            if (rs_r == 3'd7 && !_write) begin
                interrupt_latches <= 5'b0;
            end
        end
    end
end

// Handshake logic for CA and CB
always @(posedge clock) begin
    if (mode) begin
        case (control_register[5:4])
            2'b00: port_c[6] <= (interrupt_inputs[3] & ~data_ddr_c[3]) | (we_port_a ? 1'b0 : port_c[6]);
            2'b01: port_c[6] <= we_port_a ? 1'b0 : 1'b1;
            2'b10: port_c[6] <= 1'b0;
            2'b11: port_c[6] <= 1'b1;
        endcase
        
        case (control_register[7:6])
            2'b00: port_c[7] <= (interrupt_inputs[3] & ~data_ddr_c[3]) | (we_port_b ? 1'b0 : port_c[7]);
            2'b01: port_c[7] <= we_port_b ? 1'b0 : 1'b1;
            2'b10: port_c[7] <= 1'b0;
            2'b11: port_c[7] <= 1'b1;
        endcase
    end
end

// IRQ_n logic
assign port_c[5] = mode ? |(interrupt_latches & ~data_ddr_c[4:0]) : port_c[5];

// Data output logic
always @(posedge clock) begin
    rs_r = rs;
    case(rs_r)
        0: data_out = port_a;
        1: data_out = port_b;
        2: data_out = mode ? {port_c[7:5], interrupt_latches} : port_c;
        3: data_out = data_ddr_a;
        4: data_out = data_ddr_b;
        5: data_out = data_ddr_c;
        6: data_out = control_register;
        7: data_out = active_interrupt_register;
        default: data_out = 8'bz;
    endcase
end

assign data = (!_cs & _write ? data_out : 8'bz);

endmodule
