`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:18:58
// Design Name: 
// Module Name: axi_lite_to_sram_bridge_top
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


module axi_lite_to_sram_bridge_top #(
    // --- Parameters ---
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,
    parameter SRAM_ADDR_WIDTH = 16,
    parameter FIFO_DEPTH_BITS = 2    // FIFO depth will be 2^4 = 16
) (
    // --- AXI Interface (Slave Port) ---
    input  logic                      aclk,
    input  logic                      aresetn,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    // --- SRAM Interface (Master Port) ---
    input  logic                      sram_clk,
    input  logic                      sram_rst_n
    // Note: The actual SRAM pins would be outputs from this top-level module
    // to connect to an off-chip SRAM. For this integrated testbench, the SRAM
    // is instantiated internally.
);

    // --- Internal Wires for FIFO Connections ---
    wire [AXI_ADDR_WIDTH-1:0]  aw_fifo_wdata, aw_fifo_rdata;
    wire                       aw_fifo_wen, aw_fifo_ren, aw_fifo_full, aw_fifo_empty;

    wire [AXI_DATA_WIDTH + AXI_DATA_WIDTH/8 - 1:0] w_fifo_wdata, w_fifo_rdata;
    wire                       w_fifo_wen, w_fifo_ren, w_fifo_full, w_fifo_empty;

    wire [AXI_ADDR_WIDTH-1:0]  ar_fifo_wdata, ar_fifo_rdata;
    wire                       ar_fifo_wen, ar_fifo_ren, ar_fifo_full, ar_fifo_empty;

    wire [AXI_DATA_WIDTH-1:0]  r_fifo_wdata, r_fifo_rdata;
    wire                       r_fifo_wen, r_fifo_ren, r_fifo_full, r_fifo_empty;

    wire [1:0]                 b_fifo_wdata, b_fifo_rdata;
    wire                       b_fifo_wen, b_fifo_ren, b_fifo_full, b_fifo_empty;

    // --- Internal Wires for SRAM Connections ---
    wire [SRAM_ADDR_WIDTH-1:0]   sram_addr_wire;
    wire [AXI_DATA_WIDTH-1:0]    sram_din_wire;
    wire [AXI_DATA_WIDTH-1:0]    sram_dout_wire;
    wire [AXI_DATA_WIDTH/8-1:0]  sram_we_wire;
    wire                         sram_en_wire;

    //
    // --- FIFO Instantiations ---
    //

    // FIFO 1: Write Address (aw_fifo)
    // Direction: AXI clock domain -> SRAM clock domain
    fifo_flat #(
        .DSIZE(AXI_ADDR_WIDTH),
        .ASIZE(FIFO_DEPTH_BITS)
    ) aw_fifo_inst (
        .wclk(aclk), .wrst_n(aresetn), .wdata(aw_fifo_wdata), .winc(aw_fifo_wen), .wfull(aw_fifo_full),
        .rclk(sram_clk), .rrst_n(sram_rst_n), .rdata(aw_fifo_rdata), .rinc(aw_fifo_ren), .rempty(aw_fifo_empty)
    );

    // FIFO 2: Write Data (w_fifo)
    // Direction: AXI clock domain -> SRAM clock domain
    fifo_flat #(
        .DSIZE(AXI_DATA_WIDTH + AXI_DATA_WIDTH/8),
        .ASIZE(FIFO_DEPTH_BITS)
    ) w_fifo_inst (
        .wclk(aclk), .wrst_n(aresetn), .wdata(w_fifo_wdata), .winc(w_fifo_wen), .wfull(w_fifo_full),
        .rclk(sram_clk), .rrst_n(sram_rst_n), .rdata(w_fifo_rdata), .rinc(w_fifo_ren), .rempty(w_fifo_empty)
    );

    // FIFO 3: Read Address (ar_fifo)
    // Direction: AXI clock domain -> SRAM clock domain
    fifo_flat #(
        .DSIZE(AXI_ADDR_WIDTH),
        .ASIZE(FIFO_DEPTH_BITS)
    ) ar_fifo_inst (
        .wclk(aclk), .wrst_n(aresetn), .wdata(ar_fifo_wdata), .winc(ar_fifo_wen), .wfull(ar_fifo_full),
        .rclk(sram_clk), .rrst_n(sram_rst_n), .rdata(ar_fifo_rdata), .rinc(ar_fifo_ren), .rempty(ar_fifo_empty)
    );

    // FIFO 4: Read Data (r_fifo)
    // Direction: SRAM clock domain -> AXI clock domain
    fifo_flat #(
        .DSIZE(AXI_DATA_WIDTH),
        .ASIZE(FIFO_DEPTH_BITS)
    ) r_fifo_inst (
        .wclk(sram_clk), .wrst_n(sram_rst_n), .wdata(r_fifo_wdata), .winc(r_fifo_wen), .wfull(r_fifo_full),
        .rclk(aclk), .rrst_n(aresetn), .rdata(r_fifo_rdata), .rinc(r_fifo_ren), .rempty(r_fifo_empty)
    );

    // FIFO 5: Write Response (b_fifo)
    // Direction: SRAM clock domain -> AXI clock domain
    fifo_flat #(
        .DSIZE(2),
        .ASIZE(FIFO_DEPTH_BITS)
    ) b_fifo_inst (
        .wclk(sram_clk), .wrst_n(sram_rst_n), .wdata(b_fifo_wdata), .winc(b_fifo_wen), .wfull(b_fifo_full),
        .rclk(aclk), .rrst_n(aresetn), .rdata(b_fifo_rdata), .rinc(b_fifo_ren), .rempty(b_fifo_empty)
    );


    //
    // --- Logic and Memory Instantiations ---
    //

    // Instantiate the AXI-facing logic module.
 axi4_lite_slave #(
        .C_S_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) axi_if_inst (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .aw_fifo_wdata(aw_fifo_wdata), .aw_fifo_wen(aw_fifo_wen), .aw_fifo_full(aw_fifo_full),
        .w_fifo_wdata(w_fifo_wdata), .w_fifo_wen(w_fifo_wen), .w_fifo_full(w_fifo_full),
        .ar_fifo_wdata(ar_fifo_wdata), .ar_fifo_wen(ar_fifo_wen), .ar_fifo_full(ar_fifo_full),
        .r_fifo_rdata(r_fifo_rdata), .r_fifo_ren(r_fifo_ren), .r_fifo_empty(r_fifo_empty),
        .b_fifo_rdata(b_fifo_rdata), .b_fifo_ren(b_fifo_ren), .b_fifo_empty(b_fifo_empty)
    );

    // Instantiate the SRAM-facing logic module (the controller).
    sram_controller #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .SRAM_DATA_WIDTH(AXI_DATA_WIDTH)
    ) sram_ctrl_inst (
        .sram_clk(sram_clk), .sram_rst_n(sram_rst_n),
        .sram_addr(sram_addr_wire), .sram_din(sram_din_wire), .sram_dout(sram_dout_wire), .sram_we(sram_we_wire), .sram_en(sram_en_wire),
        .aw_fifo_rdata(aw_fifo_rdata), .aw_fifo_ren(aw_fifo_ren), .aw_fifo_empty(aw_fifo_empty),
        .w_fifo_rdata(w_fifo_rdata), .w_fifo_ren(w_fifo_ren), .w_fifo_empty(w_fifo_empty),
        .ar_fifo_rdata(ar_fifo_rdata), .ar_fifo_ren(ar_fifo_ren), .ar_fifo_empty(ar_fifo_empty),
        .r_fifo_wdata(r_fifo_wdata), .r_fifo_wen(r_fifo_wen), .r_fifo_full(r_fifo_full),
        .b_fifo_wdata(b_fifo_wdata), .b_fifo_wen(b_fifo_wen), .b_fifo_full(b_fifo_full)
    );

    // Instantiate the SRAM memory model itself.
    sram_synthesizable #(
        .DATA_WIDTH(AXI_DATA_WIDTH),
        .ADDR_WIDTH(SRAM_ADDR_WIDTH)
    ) sram_mem_inst (
        .clk(sram_clk), .rst_n(sram_rst_n),
        .en(sram_en_wire), .we(sram_we_wire), .addr(sram_addr_wire),
        .din(sram_din_wire), .dout(sram_dout_wire)
    );




endmodule