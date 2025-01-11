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
    input _reset,
    input _cs,
    input [2:0]rs,
    input _write,
    inout [7:0]data,
    inout [7:0]port_a,
    inout [7:0]port_b,
    inout [7:0]port_c
);

reg [7:0]data_out;
reg [2:0] rs_r;
wire clock = !_cs;
wire [7:0] data_ddr_a, data_ddr_b, data_ddr_c;
reg [7:0] control_register;
reg [7:0] active_interrupt_register;
reg [4:0] interrupt_latches;
reg irq_n;
reg ca, cb;

reg [4:0] interrupt_stack[3:0];  // Stack to hold interrupt priorities
reg [1:0] stack_pointer;

wire we_ddr_a, we_ddr_b, we_ddr_c, we_port_a, we_port_b, we_port_c, we_cr, we_air;

assign we_ddr_a = !_write & (rs_r == 3'd3);
assign we_ddr_b = !_write & (rs_r == 3'd4);
assign we_ddr_c = !_write & (rs_r == 3'd5);
assign we_port_a = !_write & (rs_r == 3'd0);
assign we_port_b = !_write & (rs_r == 3'd1);
assign we_port_c = !_write & (rs_r == 3'd2);
assign we_cr = !_write & (rs_r == 3'd6);
assign we_air = !_write & (rs_r == 3'd7);

ioport ioport_a(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_a), 
    .data_ddr(data_ddr_a), 
    .we_port(we_port_a), 
    .pins(port_a)
);

ioport ioport_b(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_b), 
    .data_ddr(data_ddr_b), 
    .we_port(we_port_b), 
    .pins(port_b)
);

ioport ioport_c(
    .clock(clock), 
    .reset(!_reset), 
    .data_in(data), 
    .we_ddr(we_ddr_c), 
    .data_ddr(data_ddr_c), 
    .we_port(we_port_c), 
    .pins(port_c)
);

assign data = (!_cs & _write ? data_out : 8'bz);

always @(posedge clock or negedge _reset) begin
    if (!_reset) begin
        control_register <= 8'b0;
        active_interrupt_register <= 8'b0;
        interrupt_latches <= 5'b0;
        irq_n <= 1'b1;
        ca <= 1'b1;
        cb <= 1'b1;
        stack_pointer <= 2'b0;
    end else begin
        if (!_write) begin
            case(rs)
                3'd6: control_register <= data;
                3'd7: begin
                    // Writing to AIR pops the interrupt stack
                    if (stack_pointer > 0) begin
                        stack_pointer <= stack_pointer - 1;
                        active_interrupt_register <= {3'b0, interrupt_stack[stack_pointer-1]};
                    end else begin
                        active_interrupt_register <= 8'b0;
                    end
                end
                default: ; // Other registers handled by ioport modules
            endcase
        end
        
        // Handle interrupts in Mode 1
        if (control_register[0]) begin
            // Check for new interrupts
            for (int i = 4; i >= 0; i--) begin
                if (port_c[i] & !data_ddr_c[i] & !interrupt_latches[i]) begin
                    interrupt_latches[i] <= 1'b1;
                    if (control_register[1]) begin // Priority mode
                        if (i > active_interrupt_register[4:0]) begin
                            // Higher priority interrupt
                            interrupt_stack[stack_pointer] <= active_interrupt_register[4:0];
                            stack_pointer <= stack_pointer + 1;
                            active_interrupt_register <= {3'b0, 5'b00001 << i};
                            irq_n <= 1'b0;
                        end
                    end else begin
                        // No priority mode
                        active_interrupt_register[i] <= 1'b1;
                        irq_n <= 1'b0;
                    end
                end
            end
        end
        
        // Handle CA and CB outputs
        case (control_register[5:4])
            2'b00: ca <= (port_c[3] & !data_ddr_c[3]) | (rs_r == 3'd0 & !_write);
            2'b01: ca <= (rs_r == 3'd0 & !_write) ? 1'b0 : 1'b1; // Pulse LOW for at least 500ns
            2'b10: ca <= 1'b0;
            2'b11: ca <= 1'b1;
        endcase
        
        case (control_register[7:6])
            2'b00: cb <= (port_c[3] & !data_ddr_c[3]) | (rs_r == 3'd1 & !_write);
            2'b01: cb <= (rs_r == 3'd1 & !_write) ? 1'b0 : 1'b1; // Pulse LOW for at least 500ns
            2'b10: cb <= 1'b0;
            2'b11: cb <= 1'b1;
        endcase
    end
end

always @(posedge clock) begin
    rs_r = rs;
    case(rs_r)
        3'd0: data_out = port_a;
        3'd1: data_out = port_b;
        3'd2: data_out = control_register[0] ? {cb, ca, irq_n, interrupt_latches} : port_c;
        3'd3: data_out = data_ddr_a;
        3'd4: data_out = data_ddr_b;
        3'd5: data_out = data_ddr_c;
        3'd6: data_out = control_register;
        3'd7: begin
            data_out = active_interrupt_register;
            if (control_register[1]) begin // Priority mode
                interrupt_latches[active_interrupt_register[4:0]] <= 1'b0;
                if (stack_pointer > 0) begin
                    stack_pointer <= stack_pointer - 1;
                    active_interrupt_register <= {3'b0, interrupt_stack[stack_pointer-1]};
                end else begin
                    active_interrupt_register <= 8'b0;
                end
            end else begin
                // No priority mode
                interrupt_latches <= 5'b0;
                active_interrupt_register <= 8'b0;
            end
            irq_n <= 1'b1; // Reset IRQ_n
        end
        default: data_out = 8'bz;
    endcase
end

endmodule
