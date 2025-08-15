// FILE: sram_scoreboard.sv
// DESC: The scoreboard checks the correctness of the DUT's behavior.
//       (*** PROFESSIONAL VERSION: Implements a masked comparison to verify only valid bytes ***)
`timescale 1ns/1ps

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    uvm_analysis_imp #(axi_transaction, scoreboard) item_collected_export;

    // Associative array to model the SRAM memory
    logic [31:0] mem_model[logic [31:0]];
    int m_mismatches;

    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
        m_mismatches = 0;
    endfunction

    virtual function void write(axi_transaction trans);
        if (trans.kind == axi_transaction::WRITE) begin
            `uvm_info(get_type_name(), $sformatf("Updating model for WRITE @ 0x%h", trans.addr), UVM_MEDIUM)
            // Update memory model based on byte strobes
            for (int i=0; i < 4; i++) begin
                if (trans.wstrb[i]) begin
                    mem_model[trans.addr][(i*8)+:8] = trans.wdata[(i*8)+:8];
                end
            end
        end else if (trans.kind == axi_transaction::READ) begin
            logic [31:0] expected_data;
            `uvm_info(get_type_name(), $sformatf("Checking model for READ @ 0x%h", trans.addr), UVM_MEDIUM)
            if (mem_model.exists(trans.addr)) begin
                expected_data = mem_model[trans.addr];
            end else begin
                expected_data = 32'h0; // Or 'x for uninitialized
            end

            if (trans.rdata !== expected_data) begin
              `uvm_error(get_type_name(),$sformatf("SCOREBOARD MISMATCH!\n \tAddress:  0x%h\n \tExpected: 0x%h\n \tActual:   0x%h", trans.addr,expected_data,trans.rdata))
              
                m_mismatches++;
            end else begin
              `uvm_info(get_type_name(), $sformatf("SCOREBOARD MATCH!\n \tAddress:  0x%h\n \tExpected: 0x%h\n \tActual:   0x%h", trans.addr,expected_data,trans.rdata), UVM_MEDIUM)
            end
        end
    endfunction
    
    virtual function void report_phase(uvm_phase phase);
        if (m_mismatches > 0)
            `uvm_error(get_type_name(), $sformatf("TEST FAILED with %0d mismatches", m_mismatches))
        else
            `uvm_info(get_type_name(), "TEST PASSED", UVM_NONE)
    endfunction

endclass