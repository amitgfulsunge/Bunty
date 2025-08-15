`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:22:04
// Design Name: 
// Module Name: sram_synthesizable
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sram_synthesizable #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10
) (
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       en,
    input  wire [DATA_WIDTH/8-1:0]    we,
    input  wire [ADDR_WIDTH-1:0]      addr,
    input  wire [DATA_WIDTH-1:0]      din,
    output wire [DATA_WIDTH-1:0]      dout
);
    localparam NUM_BYTES = DATA_WIDTH / 8;
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] dout_reg;
    integer i;

    always @(posedge clk) begin
        if (en) begin
            // Write Logic with byte-enables
            if (|we) begin
                for (i = 0; i < NUM_BYTES; i = i + 1) begin
                    if (we[i]) begin
                        mem[addr][(i*8) +: 8] <= din[(i*8) +: 8];
                    end
                end
            end
            // Synchronous Read Logic
            dout_reg <= mem[addr];
        end
    end
    assign dout = dout_reg;
endmodule