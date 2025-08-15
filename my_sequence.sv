// FILE: sram_sequences.sv
// DESC: Sequences generate streams of transactions to be sent to the driver.
//       (*** UPDATED with a smarter write-then-read sequence ***)
`timescale 1ns/1ps

class base_sequence extends uvm_sequence #(axi_transaction);
    `uvm_object_utils(base_sequence)
  
	axi_transaction req1;
    function new(string name = "base_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "Sequence body started", UVM_MEDIUM)
        // Perform a series of writes then reads
        repeat (10) begin
            req = axi_transaction::type_id::create("req");
            start_item(req);
          assert(req.randomize() with { kind == axi_transaction::WRITE; addr[15:0] < 200; });
            finish_item(req);
            
            // Start a read from the same address
          
          req1 = axi_transaction::type_id::create("req1");
          start_item(req1);
          assert(req1.randomize() with { kind == axi_transaction::READ; addr == req.addr; });
          finish_item(req1);
        end
        `uvm_info(get_type_name(), "Sequence body finished", UVM_MEDIUM)
    endtask
endclass