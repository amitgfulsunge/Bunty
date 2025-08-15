// FILE: sram_agent.sv
// DESC: The agent encapsulates the driver, sequencer, and monitor for a specific
//       interface. It acts as a reusable block for driving and monitoring.
`timescale 1ns/1ps

class axi_lite_agent extends uvm_agent;
    
    `uvm_component_utils(axi_lite_agent)

    uvm_sequencer#(axi_transaction) sqr;
    axi_driver                drv;
    axi_monitor               mon;
  
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      mon = axi_monitor::type_id::create("mon", this);
      if (is_active == UVM_ACTIVE) begin
        sqr = uvm_sequencer#(axi_transaction)::type_id::create("sqr", this);
        drv = axi_driver::type_id::create("drv", this);
      end
    endfunction

    function void connect_phase(uvm_phase phase);
      if (is_active == UVM_ACTIVE) begin
        drv.seq_item_port.connect(sqr.seq_item_export);
      end
    endfunction
  endclass