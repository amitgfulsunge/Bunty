// FILE: sram_env.sv
// DESC: The environment class is a container for higher-level verification
//       components like agents and scoreboards.
`timescale 1ns/1ps

class axi_lite_env extends uvm_env;
    axi_lite_agent      agent;
   // axi_lite_ref_model  ref_model;
    scoreboard scb;

    `uvm_component_utils(axi_lite_env)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent     = axi_lite_agent::type_id::create("agent", this);
    // ref_model = axi_lite_ref_model::type_id::create("ref_model", this);
      scb       = scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      // Monitor broadcasts to both the scoreboard and the reference model
      agent.mon.item_collected_port.connect(scb.item_collected_export);
     // agent.mon.item_collected_port.connect(ref_model.item_in_imp); // Connect to the ref model's listener port
      
      // Reference model sends its predicted transaction to the scoreboard
   //   ref_model.item_out_port.connect(scb.ref_export);
    endfunction
  endclass