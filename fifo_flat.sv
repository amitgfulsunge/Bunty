`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:24:28
// Design Name: 
// Module Name: fifo_flat
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


module fifo_flat #(
    // --- Parameters ---
    parameter DSIZE = 8,   // Defines the width of the data bus.
    parameter ASIZE = 4    // Defines the address width. The depth will be 2^ASIZE.
) (
    // --- Outputs ---
    output [DSIZE-1:0] rdata,   // Data read from the FIFO.
    output reg         wfull,   // Write Full Flag.
    output reg         rempty,  // Read Empty Flag.

    // --- Inputs ---
    input [DSIZE-1:0]  wdata,   // Data to be written into the FIFO.
    input              winc,    // Write Increment (Enable).
    input              wclk,    // Write Clock.
    input              wrst_n,  // Write Reset (Active Low).
    input              rinc,    // Read Increment (Enable).
    input              rclk,    // Read Clock.
    input              rrst_n   // Read Reset (Active Low).
);

    // --- Internal Signals Declaration ---
    localparam DEPTH = 1 << ASIZE;
    reg [DSIZE-1:0] mem [0:DEPTH-1];

    // Write-side signals (controlled by wclk)
    reg  [ASIZE:0]  wptr;
    reg  [ASIZE:0]  wbin;
    wire [ASIZE-1:0] waddr;
    wire [ASIZE:0]  wgray_next;
    wire           wfull_val;

    // Read-side signals (controlled by rclk)
    reg  [ASIZE:0]  rptr;
    reg  [ASIZE:0]  rbin;
    wire [ASIZE-1:0] raddr;
    wire [ASIZE:0]  rgray_next;
    wire           rempty_val;

    // Pointer Synchronization Registers
    reg [ASIZE:0] wq1_rptr, wq2_rptr;
    reg [ASIZE:0] rq1_wptr, rq2_wptr;

    // --- Write Pointer and Full Status Logic (Write Clock Domain) ---
    assign waddr = wbin[ASIZE-1:0];
    assign wgray_next = ((wbin + (winc & ~wfull)) >> 1) ^ (wbin + (winc & ~wfull));
    assign wfull_val = (wgray_next == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= 0;
            wptr  <= 0;
            wfull <= 1'b0;
        end else begin
            wbin <= wbin + (winc & ~wfull);
            wptr <= wgray_next;
            wfull <= wfull_val;
        end
    end

    // --- Read Pointer and Empty Status Logic (Read Clock Domain) ---
    assign raddr = rbin[ASIZE-1:0];
    assign rgray_next = ((rbin + (rinc & ~rempty)) >> 1) ^ (rbin + (rinc & ~rempty));
    assign rempty_val = (rgray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= 0;
            rptr   <= 0;
            rempty <= 1'b1;
        end else begin
            rbin <= rbin + (rinc & ~rempty);
            rptr <= rgray_next;
            rempty <= rempty_val;
        end
    end

    // --- Pointer Synchronization Logic ---
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wq1_rptr <= 0;
            wq2_rptr <= 0;
        end else begin
            wq1_rptr <= rptr;
            wq2_rptr <= wq1_rptr;
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr <= 0;
            rq2_wptr <= 0;
        end else begin
            rq1_wptr <= wptr;
            rq2_wptr <= rq1_wptr;
        end
    end

    // --- Dual-Port Memory Logic ---
    always @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[waddr] <= wdata;
        end
    end
    assign rdata = mem[raddr];

endmodule
