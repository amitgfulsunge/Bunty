
`timescale 1ns/1ps


import uvm_pkg::*;
`include "uvm_macros.svh"
`include "my_testbench_pkg.sv"
import my_testbench_pkg::*;



//Testbench top 


module tb_top;
    // Parameters
    localparam AXI_ADDR_WIDTH  = 32;
    localparam AXI_DATA_WIDTH  = 32;
  
    localparam SRAM_ADDR_WIDTH = 16;
  
    localparam FIFO_DEPTH_BITS = 4;
  
    localparam ACLK_PERIOD     = 10; // 100 MHz
    localparam SRAM_CLK_PERIOD = 8;  // 125 MHz

    // Clocks and Resets
    logic aclk;
    logic aresetn;
    logic sram_clk;
    logic sram_rst_n;

    // Instantiate the interface
    axi_lite_if #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH)
    ) dut_if (
      .aclk(aclk),
      .aresetn(aresetn),
      .sram_clk(sram_clk), 
      .sram_rst_n(sram_rst_n)
    );

    // Instantiate the DUT
    axi_lite_to_sram_bridge_top #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .SRAM_ADDR_WIDTH(SRAM_ADDR_WIDTH),
        .FIFO_DEPTH_BITS(FIFO_DEPTH_BITS)
    ) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axi_awaddr(dut_if.s_axi_awaddr),
        .s_axi_awvalid(dut_if.s_axi_awvalid),
        .s_axi_awready(dut_if.s_axi_awready),
        .s_axi_wdata(dut_if.s_axi_wdata),
        .s_axi_wstrb(dut_if.s_axi_wstrb),
        .s_axi_wvalid(dut_if.s_axi_wvalid),
        .s_axi_wready(dut_if.s_axi_wready),
        .s_axi_bresp(dut_if.s_axi_bresp),
        .s_axi_bvalid(dut_if.s_axi_bvalid),
        .s_axi_bready(dut_if.s_axi_bready),
        .s_axi_araddr(dut_if.s_axi_araddr),
        .s_axi_arvalid(dut_if.s_axi_arvalid),
        .s_axi_arready(dut_if.s_axi_arready),
        .s_axi_rdata(dut_if.s_axi_rdata),
        .s_axi_rresp(dut_if.s_axi_rresp),
        .s_axi_rvalid(dut_if.s_axi_rvalid),
        .s_axi_rready(dut_if.s_axi_rready),
        .sram_clk(sram_clk),
        .sram_rst_n(sram_rst_n)
    );
    
  
  bind dut_if axi_lite_sva sva_checker (.*);
  
  
    // Instantiate the SRAM model provided in the DUT file
    // Note: The sram_synthesizable module is assumed to be compiled.
    // The bridge top-level connects to it internally.
    // The sram_addr, din, dout etc. signals from the controller inside the bridge
    // are wired to the sram_synthesizable module inside the bridge.

    // Clock Generation
    initial begin
        aclk = 0;
        forever #(ACLK_PERIOD/2) aclk = ~aclk;
    end

    initial begin
        sram_clk = 0;
        forever #(SRAM_CLK_PERIOD/2) sram_clk = ~sram_clk;
    end

    // Reset Generation and Test Execution
    initial begin
        // Set the virtual interface in the config DB
        uvm_config_db#(virtual axi_lite_if)::set(null, "*", "vif", dut_if);

        // Start the UVM test
        run_test("directed_test");
    end

    // Waveform Dumping
    initial begin
      // Drive resets
        aresetn = 1'b0;
        sram_rst_n = 1'b0;
      repeat (10) @(posedge aclk);
        aresetn = 1'b1;
        sram_rst_n = 1'b1;
    end
      
      
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_top);
    end

endmodule