// FILE: my_testbench_pkg.sv
// DESC: This package includes all the UVM classes related to our testbench,
//       making them easy to import into the top-level test module.

package my_testbench_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Include all the component files in the correct order of dependency.
    // Transaction is first as many components refer to it.
    `include "my_transaction.sv"
    
    // Sequences define the stimulus.
    `include "my_sequence.sv"

    // Low-level components
    `include "my_monitor.sv"
    `include "my_driver.sv"
    
    // Mid-level components
    `include "my_agent.sv"
    `include "my_scoreboard.sv"
    
    // High-level components
    `include "my_env.sv"
    `include "test1.sv" // This file contains the base test class

endpackage