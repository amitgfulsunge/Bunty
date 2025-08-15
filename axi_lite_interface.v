`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:30:02
// Design Name: 
// Module Name: axi_lite_interface
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


module axi_lite_interface #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
) (
    // --- AXI Slave Interface (aclk domain) ---
    input  logic                      aclk,
    input  logic                      aresetn,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output reg   [1:0]                s_axi_bresp,
    output reg                        s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output reg                        s_axi_rvalid,
    input  logic                      s_axi_rready,

    // --- FIFO Interface (aclk domain) ---
    // To Write-side of request FIFOs
    output logic [AXI_ADDR_WIDTH-1:0] aw_fifo_wdata,
    output logic                      aw_fifo_wen,
    input  logic                      aw_fifo_full,
    output logic [AXI_DATA_WIDTH + AXI_DATA_WIDTH/8 - 1:0] w_fifo_wdata,
    output logic                      w_fifo_wen,
    input  logic                      w_fifo_full,
    output logic [AXI_ADDR_WIDTH-1:0] ar_fifo_wdata,
    output logic                      ar_fifo_wen,
    input  logic                      ar_fifo_full,
    // From Read-side of response FIFOs
    input  logic [AXI_DATA_WIDTH-1:0] r_fifo_rdata,
    output logic                      r_fifo_ren,
    input  logic                      r_fifo_empty,
    input  logic [1:0]                b_fifo_rdata,
    output logic                      b_fifo_ren,
    input  logic                      b_fifo_empty
);

    // --- AXI Write Channel Logic ---
    // The bridge is ready to accept a write address if the corresponding FIFO is not full.
    assign s_axi_awready = !aw_fifo_full;
    // The bridge is ready to accept write data if the corresponding FIFO is not full.
    assign s_axi_wready  = !w_fifo_full;

    // AXI handshake for write address: generate a write enable pulse for the FIFO.
    assign aw_fifo_wen = s_axi_awvalid && s_axi_awready;
    // The data written to the AW FIFO is the address from the AXI bus.
    assign aw_fifo_wdata = s_axi_awaddr;

    // AXI handshake for write data: generate a write enable pulse for the FIFO.
    assign w_fifo_wen = s_axi_wvalid && s_axi_wready;
    // The data written to the W FIFO is a concatenation of the write strobes and the write data.
    assign w_fifo_wdata = {s_axi_wstrb, s_axi_wdata};

    // --- AXI Read Channel Logic ---
    // The bridge is ready to accept a read address if the corresponding FIFO is not full.
    assign s_axi_arready = !ar_fifo_full;

    // AXI handshake for read address: generate a write enable for the AR FIFO.
    assign ar_fifo_wen = s_axi_arvalid && s_axi_arready;
    // The data written to the AR FIFO is the read address from the AXI bus.
    assign ar_fifo_wdata = s_axi_araddr;

    // --- AXI Write Response Channel Logic ---
    // AXI handshake for write response: generate a read enable for the B FIFO.
    assign b_fifo_ren = s_axi_bvalid && s_axi_bready;

    // This block manages the write response channel state (BVALID, BRESP).
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            // If the handshake completes (master accepts the response), de-assert BVALID.
            if (b_fifo_ren) begin
                s_axi_bvalid <= 1'b0;
            // If there is a response in the B FIFO and we are not already sending one, start.
            end else if (!b_fifo_empty && !s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= b_fifo_rdata; // Drive response from FIFO to AXI bus.
            end
        end
    end

    // --- AXI Read Data Channel Logic ---
    // The read response is always OKAY (2'b00) in this simple bridge.
    assign s_axi_rresp = 2'b00;

    // AXI handshake for read data: generate a read enable for the R FIFO.
    assign r_fifo_ren = s_axi_rvalid && s_axi_rready;
    // The read data sent to the master comes directly from the R FIFO.
    assign s_axi_rdata = r_fifo_rdata;

    // This block manages the read data channel state (RVALID).
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_rvalid <= 1'b0;
        end else begin
            // If the handshake completes (master accepts the data), de-assert RVALID.
            if (r_fifo_ren) begin
                s_axi_rvalid <= 1'b0;
            // If there is data in the R FIFO and we are not already sending any, start.
            end else if (!r_fifo_empty && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
            end
        end
    end
endmodule
