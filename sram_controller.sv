`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:18:19
// Design Name: 
// Module Name: sram_controller
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


module sram_controller #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter SRAM_ADDR_WIDTH = 16,
    parameter SRAM_DATA_WIDTH = 32
) (
    // --- SRAM Interface (sram_clk domain) ---
    input wire  sram_clk,
    input wire  sram_rst_n,
    output reg [SRAM_ADDR_WIDTH-1:0]   sram_addr,
    output reg [SRAM_DATA_WIDTH-1:0]   sram_din,
    input wire [SRAM_DATA_WIDTH-1:0]   sram_dout,
    output reg [SRAM_DATA_WIDTH/8-1:0] sram_we,
    output reg                         sram_en,

    // --- FIFO Interface (sram_clk domain) ---
    // From Read-side of request FIFOs
    input wire [AXI_ADDR_WIDTH-1:0]   aw_fifo_rdata,
    output reg                        aw_fifo_ren,
    input wire                        aw_fifo_empty,
    input wire [SRAM_DATA_WIDTH + SRAM_DATA_WIDTH/8 - 1:0] w_fifo_rdata,
    output reg                        w_fifo_ren,
    input wire                        w_fifo_empty,
    input wire [AXI_ADDR_WIDTH-1:0]   ar_fifo_rdata,
    output reg                        ar_fifo_ren,
    input wire                        ar_fifo_empty,
    // To Write-side of response FIFOs
    output wire [SRAM_DATA_WIDTH-1:0] r_fifo_wdata,
    output reg                        r_fifo_wen,
    input wire                        r_fifo_full,
    output wire [1:0]                 b_fifo_wdata,
    output reg                        b_fifo_wen,
    input wire                        b_fifo_full
);

    // --- State Machine Definition (CORRECTED) ---
    // Added SRAM_READ_WAIT state and increased state vector width to 3 bits.
    typedef enum logic [2:0] {
        IDLE,
        SRAM_READ_DRIVE,
        SRAM_READ_WAIT,
        SRAM_WRITE,
        SRAM_RESP
    } state_e;
    state_e current_state, next_state;

    // --- Internal Registers to hold transaction data ---
    reg [AXI_ADDR_WIDTH-1:0]    axi_addr_reg;
    reg [SRAM_DATA_WIDTH-1:0]   axi_wdata_reg;
    reg [SRAM_DATA_WIDTH/8-1:0] axi_wstrb_reg;

    // --- State Machine Combinational Logic (CORRECTED) ---
    always_comb begin
        // Default assignments for all control signals
        next_state  = current_state;
        sram_addr   = axi_addr_reg[SRAM_ADDR_WIDTH-1:0];
        sram_din    = axi_wdata_reg;
        sram_we     = 4'b0000; // Default to no write
        sram_en     = 1'b0;
        aw_fifo_ren = 1'b0;
        w_fifo_ren  = 1'b0;
        ar_fifo_ren = 1'b0;
        r_fifo_wen  = 1'b0;
        b_fifo_wen  = 1'b0;

        case (current_state)
            IDLE: begin
                // Priority to reads. If a read request is waiting, service it.
                if (!ar_fifo_empty) begin
                    next_state  = SRAM_READ_DRIVE;
                    ar_fifo_ren = 1'b1; // Pop the read address from its FIFO
                // If no read, check for a complete write request (address and data).
                end else if (!aw_fifo_empty && !w_fifo_empty) begin
                    next_state  = SRAM_WRITE;
                    aw_fifo_ren = 1'b1; // Pop the write address
                    w_fifo_ren  = 1'b1; // Pop the write data
                end
            end

            // *** NEW STATE LOGIC ***
            SRAM_READ_DRIVE: begin
                // In this state, just drive the address and enable to the SRAM.
                // The valid data will appear on sram_dout on the next cycle.
                sram_en    = 1'b1;
                sram_we    = 4'b0000;
                next_state = SRAM_READ_WAIT; // Move to wait state
            end

            // *** NEW STATE LOGIC ***
            SRAM_READ_WAIT: begin
                // The data from SRAM is now valid on sram_dout.
                sram_en = 1'b1; // Keep SRAM enabled
                // If the read data FIFO has space, push the data into it.
                if (!r_fifo_full) begin
                    r_fifo_wen = 1'b1;
                    next_state = IDLE; // Transaction complete, return to idle
                end
                // else, stall in this state until the FIFO has space.
            end

            SRAM_WRITE: begin
                sram_en = 1'b1;
                sram_we = axi_wstrb_reg; // Drive byte enables from stored strobe
                next_state = SRAM_RESP; // Move to response state
            end

            SRAM_RESP: begin
                // After writing to SRAM, generate a write response.
                // If the response FIFO has space, push the response.
                if (!b_fifo_full) begin
                    b_fifo_wen = 1'b1;
                    next_state = IDLE; // Transaction complete, return to idle
                end
                // else, stall in this state until the FIFO has space.
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // --- State Machine Sequential Logic ---
    always @(posedge sram_clk or negedge sram_rst_n) begin
        if (!sram_rst_n) begin
            current_state <= IDLE;
            axi_addr_reg  <= '0;
            axi_wdata_reg <= '0;
            axi_wstrb_reg <= '0;
        end else begin
            current_state <= next_state;
            // Latch transaction data when popping from FIFOs
            if (ar_fifo_ren) begin
                axi_addr_reg <= ar_fifo_rdata;
            end
            if (aw_fifo_ren) begin
                axi_addr_reg <= aw_fifo_rdata;
            end
            if (w_fifo_ren) begin
                // De-concatenate the data and strobes from the w_fifo
                axi_wstrb_reg <= w_fifo_rdata[SRAM_DATA_WIDTH+SRAM_DATA_WIDTH/8-1 -: SRAM_DATA_WIDTH/8];
                axi_wdata_reg <= w_fifo_rdata[SRAM_DATA_WIDTH-1:0];
            end
        end
    end

    // Connect SRAM output directly to the read data FIFO input
    assign r_fifo_wdata = sram_dout;
    // The write response is always OKAY (2'b00)
    assign b_fifo_wdata = 2'b00;

endmodule

