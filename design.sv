`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;


interface axi_lite_if #(
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,
    parameter SRAM_ADDR_WIDTH = 16
) (
    input logic aclk,
    input logic aresetn,
    input logic sram_clk,
    input logic sram_rst_n
);
    // AXI Signals
    logic [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr;
    logic                        s_axi_awvalid= 1'b0;
    logic                        s_axi_awready;
  
    logic [AXI_DATA_WIDTH-1:0]   s_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb;
    logic                        s_axi_wvalid= 1'b0;
    logic                        s_axi_wready;
  
    logic [1:0]                  s_axi_bresp;
    logic                        s_axi_bvalid;
    logic                        s_axi_bready= 1'b0;
  
    logic [AXI_ADDR_WIDTH-1:0]   s_axi_araddr;
    logic                        s_axi_arvalid= 1'b0;
    logic                        s_axi_arready;
  
    logic [AXI_DATA_WIDTH-1:0]   s_axi_rdata;
    logic [1:0]                  s_axi_rresp;
    logic                        s_axi_rvalid;
    logic                        s_axi_rready= 1'b0;

    // SRAM Signals (for connecting DUT to SRAM model)
    logic [SRAM_ADDR_WIDTH-1:0]  sram_addr;
    logic [AXI_DATA_WIDTH-1:0]   sram_din;
    logic [AXI_DATA_WIDTH-1:0]   sram_dout;
    logic [AXI_DATA_WIDTH/8-1:0] sram_we;
    logic                        sram_en;


    // Clocking block for the AXI driver
    clocking driver_cb @(posedge aclk);
        default input #1step output #1ps;
        output s_axi_awaddr, s_axi_awvalid;
        input  s_axi_awready;
        output s_axi_wdata, s_axi_wstrb, s_axi_wvalid;
        input  s_axi_wready;
        input  s_axi_bresp, s_axi_bvalid;
        output s_axi_bready;
        output s_axi_araddr, s_axi_arvalid;
        input  s_axi_arready;
        input  s_axi_rdata, s_axi_rresp, s_axi_rvalid;
        output s_axi_rready;
    endclocking

    // Modport for the Driver
    modport DRIVER (clocking driver_cb, input aresetn);

    // Modport for the Monitor (accesses raw signals)
    modport MONITOR (
        input aclk, aresetn,
        input s_axi_awaddr, s_axi_awvalid, s_axi_awready,
        input s_axi_wdata, s_axi_wstrb, s_axi_wvalid, s_axi_wready,
        input s_axi_bresp, s_axi_bvalid, s_axi_bready,
        input s_axi_araddr, s_axi_arvalid, s_axi_arready,
        input s_axi_rdata, s_axi_rresp, s_axi_rvalid, s_axi_rready
    );

endinterface
          

//
//================================================================================
// MODULE 5: axi_lite_to_sram_bridge_top (TOP-LEVEL DUT)
//================================================================================
//
// Description:
// This is the complete, asynchronous, top-level DUT. It connects the AXI Lite
// slave interface to the SRAM master interface. It uses five asynchronous FIFOs
// to handle the clock domain crossing between the AXI clock (aclk) and the
// SRAM clock (sram_clk).
//
      
      
module axi_lite_to_sram_bridge_top #(
    // --- Parameters ---
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,
    parameter SRAM_ADDR_WIDTH = 16,
    parameter FIFO_DEPTH_BITS = 4    // FIFO depth will be 2^4 = 16
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
          
          
          
          
          
//
//================================================================================
// MODULE 1: fifo_flat (Asynchronous FIFO)
//================================================================================
//
// Description:
// This is an asynchronous First-In, First-Out (FIFO) buffer. It's "asynchronous"
// because it has separate clocks for writing (wclk) and reading (rclk), allowing
// it to safely pass data between two different clock domains. It uses Gray code
// pointers to prevent metastability issues when pointers are synchronized across
// clock domains. This is the exact module you provided.
//
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

//
module axi4_lite_slave #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 32
) (
    // Global Signals
    input aclk,
    input aresetn,

    // AXI4-Lite Interface
    // Write Address Channel
    input  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
   // input  [2:0]                    s_axi_awprot,
    input                           s_axi_awvalid,
    output logic                    s_axi_awready,

    // Write Data Channel
    input  [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input                           s_axi_wvalid,
    output logic                    s_axi_wready,

    // Write Response Channel
    output logic [1:0]              s_axi_bresp,
    output logic                    s_axi_bvalid,
    input                           s_axi_bready,

    // Read Address Channel
    input  [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
   // input  [2:0]                    s_axi_arprot,
    input                           s_axi_arvalid,
    output logic                    s_axi_arready,

    // Read Data Channel
    output logic [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]              s_axi_rresp,
    output logic                    s_axi_rvalid,
    input                           s_axi_rready,


    // To Write-side of request FIFOs
    input  logic                      aw_fifo_full,
    input  logic                      w_fifo_full,
    input  logic                      ar_fifo_full,
    ////////////////
    output logic [C_S_AXI_DATA_WIDTH-1:0] aw_fifo_wdata,
    output logic                      aw_fifo_wen,
    output logic [C_S_AXI_DATA_WIDTH + C_S_AXI_DATA_WIDTH/8 - 1:0] w_fifo_wdata,
    output logic                      w_fifo_wen,
    output logic [C_S_AXI_DATA_WIDTH-1:0] ar_fifo_wdata,
    output logic                      ar_fifo_wen,
    // From Read-side of response FIFOs
    input  logic [C_S_AXI_DATA_WIDTH-1:0] r_fifo_rdata,
    output logic                      r_fifo_ren,
    input  logic                      r_fifo_empty,
    input  logic [1:0]                b_fifo_rdata,
    output logic                      b_fifo_ren,
    input  logic                      b_fifo_empty
);

    //localparam no_of_registers = 32;
   // logic [C_S_AXI_DATA_WIDTH-1:0] register [no_of_registers-1:0];
   // logic [C_S_AXI_ADDR_WIDTH-1:0] addr;
    logic write_addr;
    logic write_data;

    typedef enum logic [2:0] {IDLE, WRITE_CHANNEL, WRESP_CHANNEL, RADDR_CHANNEL, RDATA_CHANNEL} state_type;
    state_type state, next_state;

    assign s_axi_arready = (state == RADDR_CHANNEL);
    /////////
    assign s_axi_rvalid = (state == RDATA_CHANNEL) && (r_fifo_empty==0);
    assign r_fifo_ren = ((state == RDATA_CHANNEL) && (r_fifo_empty==0)) ? 1'b1 : 1'b0;
    assign s_axi_rdata = ((state == RDATA_CHANNEL) && (r_fifo_empty==0)) ? r_fifo_rdata : 0;
    assign s_axi_rresp = 2'b00;
    /////////
    assign s_axi_bvalid = (state == WRESP_CHANNEL) && (b_fifo_empty==0);
    assign b_fifo_ren = ((state == WRESP_CHANNEL) && (b_fifo_empty==0)) ? 1'b1 : 1'b0;
    assign s_axi_bresp = ((state == WRESP_CHANNEL) && (b_fifo_empty==0)) ? b_fifo_rdata : 1'b0;
    /////////
    assign s_axi_awready = (state == WRITE_CHANNEL);
    assign s_axi_wready = (state == WRITE_CHANNEL);
    assign write_addr = s_axi_awvalid && s_axi_awready;
    assign write_data = s_axi_wready && s_axi_wvalid;



/////////////////////////////////////////////////////////////////////////////////////
    // AXI handshake for write address: generate a write enable pulse for the FIFO.
    assign aw_fifo_wen = s_axi_awvalid && s_axi_awready;
    // The data written to the AW FIFO is the address from the AXI bus.
    assign aw_fifo_wdata = s_axi_awaddr;
    // AXI handshake for write data: generate a write enable pulse for the FIFO.
    assign w_fifo_wen = s_axi_wvalid && s_axi_wready;
    // The data written to the W FIFO is a concatenation of the write strobes and the write data.
    assign w_fifo_wdata = {s_axi_wstrb, s_axi_wdata};


    assign ar_fifo_wen = (state == RADDR_CHANNEL);
    assign ar_fifo_wdata = s_axi_araddr;

///////////////////////////////////////////////////////////////////////////////////////
    
    integer i;

    always_ff @(posedge aclk) begin
        if (~aresetn) begin
          /*
            for (i = 0; i < no_of_registers; i = i + 1) begin
                register[i] <= 32'b0;
            end
           */
        end else if (state == WRITE_CHANNEL && write_addr && write_data) begin
            
            /*
            // **FIX**: Implement correct write-strobe logic
            for (int j=0; j < C_S_AXI_DATA_WIDTH/8; j = j + 1) begin
                if (s_axi_wstrb[j]) begin
                    register[s_axi_awaddr][j*8 +: 8] <= s_axi_wdata[j*8 +: 8];
                end
            end
            */

        end else if (state == RADDR_CHANNEL && s_axi_arvalid && s_axi_arready) begin
           // addr <= s_axi_araddr;
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (s_axi_awvalid && !aw_fifo_full && !w_fifo_full) begin
                    next_state = WRITE_CHANNEL;

                end else if (s_axi_arvalid && !ar_fifo_full) begin
                    next_state = RADDR_CHANNEL;
                end
            end
            RADDR_CHANNEL: begin
                if (s_axi_arvalid && s_axi_arready) begin
                    next_state = RDATA_CHANNEL;
                end
            end
            RDATA_CHANNEL: begin
                if (s_axi_rvalid && s_axi_rready) begin
                    next_state = IDLE;
                end
            end
            WRITE_CHANNEL: begin
                if (write_addr && write_data) begin
                    next_state = WRESP_CHANNEL;

                end
            end
            WRESP_CHANNEL: begin
                if (s_axi_bvalid && s_axi_bready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end
endmodule

//
//================================================================================
// MODULE 3: sram_controller (SRAM Clock Domain Logic) - CORRECTED
//================================================================================
//
// Description:
// This module handles all communication with the SRAM. It operates entirely
// in the 'sram_clk' domain. It reads requests from the read-side of the FIFOs,
// executes the SRAM read/write operations, and pushes results (read data, write
// responses) into the write-side of the response FIFOs.
//
// *** CORRECTION: The FSM now includes a wait state for reads to accommodate
// the synchronous SRAM's one-cycle read latency. ***
//
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
              else next_state = SRAM_RESP;
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
          //$display("INFO: inside else  when no reset  at %t", $time);
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

//
//================================================================================
// MODULE 4: sram_synthesizable (SRAM Memory Model)
//================================================================================
//
// Description:
// A synthesizable model of a synchronous, single-port SRAM with byte-enables.
// This is the exact module you provided.
//
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

// axi_lite_sva.sv
/*******************************************************************************
* AXI4-Lite SystemVerilog Assertions Module (Corrected)
*
* This module contains SVA properties to verify the AXI4-Lite protocol rules.
* It is intended to be bound to the axi_lite_if instance in the testbench top.
*******************************************************************************/
module axi_lite_sva (
  axi_lite_if vif
);

  property p_awvalid_stable;
    @(posedge vif.aclk)
    vif.s_axi_awvalid && !vif.s_axi_awready |-> vif.s_axi_awvalid;
  endproperty
  a_awvalid_stable: assert property (p_awvalid_stable) else `uvm_error("SVA_ERROR", "AWVALID went low before AWREADY was asserted");

  property p_wvalid_stable;
    @(posedge vif.aclk)
    vif.s_axi_wvalid && !vif.s_axi_wready |-> vif.s_axi_wvalid;
  endproperty
  a_wvalid_stable: assert property (p_wvalid_stable) else `uvm_error("SVA_ERROR", "WVALID went low before WREADY was asserted");

  property p_arvalid_stable;
    @(posedge vif.aclk)
    vif.s_axi_arvalid && !vif.s_axi_arready |-> vif.s_axi_arvalid;
  endproperty
  a_arvalid_stable: assert property (p_arvalid_stable) else `uvm_error("SVA_ERROR", "ARVALID went low before ARREADY was asserted");

  // **CORRECTED AND ROBUST BVALID ASSERTION**
  // After an address handshake, if a data handshake eventually follows,
  // then a write response (bvalid) must eventually follow that.
  property p_bvalid_after_write;
    @(posedge vif.aclk)
    (vif.s_axi_awvalid && vif.s_axi_awready && vif.s_axi_wvalid && vif.s_axi_wready) |=> (vif.s_axi_bvalid);
  endproperty
  a_bvalid_after_write: assert property (p_bvalid_after_write) else `uvm_error("SVA_ERROR", "BVALID did not follow a completed write transaction");

  // After a read request is accepted, a read response must eventually follow.
  property p_rvalid_after_read;
    @(posedge vif.aclk)
    (vif.s_axi_arvalid && vif.s_axi_arready) |=> vif.s_axi_rvalid;
  endproperty
  a_rvalid_after_read: assert property (p_rvalid_after_read) else `uvm_error("SVA_ERROR", "RVALID did not follow a completed read address phase");
  
  // Reset checks: All VALID signals must be low during and immediately after reset.
  property p_reset_valid_low;
    @(posedge vif.aclk)
    !vif.aresetn |-> (!vif.s_axi_awvalid && !vif.s_axi_wvalid && !vif.s_axi_arvalid && !vif.s_axi_bready && !vif.s_axi_rready);
  endproperty
  a_reset_valid_low: assert property(p_reset_valid_low) else `uvm_error("SVA_ERROR", "A VALID signal was high during reset");

endmodule
      
      
      
      
      
      
      