`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2025 14:32:35
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