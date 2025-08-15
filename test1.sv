// FILE: test1.sv
// DESC: This file contains the definition for our UVM test.

`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

class base_test extends uvm_test;
  
    axi_lite_env env;
    virtual axi_lite_if vif;

    `uvm_component_utils(base_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = axi_lite_env::type_id::create("env", this);
      if(!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
        `uvm_fatal("NOVIF", "Virtual interface must be set for test")
    endfunction
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #100ns;
        phase.drop_objection(this);
    endtask
  endclass

 class directed_test extends base_test;
    `uvm_component_utils(directed_test)
    function new(string name="directed_test", uvm_component parent);
      super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
      base_sequence seq = base_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.sqr);
      #20ns;
      phase.drop_objection(this);
    endtask
 endclass
  
      /*
  class random_test extends base_test;
    `uvm_component_utils(random_test)
    function new(string name="random_test", uvm_component parent);
      super.new(name, parent);
    endfunction
    
    task run_phase(uvm_phase phase);
      random_stress_sequence seq = random_stress_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.start(env.agent.sqr);
      #20ns;
      phase.drop_objection(this);
    endtask
  endclass
*/

