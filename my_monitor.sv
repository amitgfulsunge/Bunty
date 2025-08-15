// FILE: sram_monitor.sv
// DESC: The monitor passively observes interface signals, reconstructs transactions,
//       and sends them out via an analysis port for other components to use.
//       (*** UPDATED to use direct signal access instead of a clocking block ***)
`timescale 1ns/1ps

class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
	bit success;
    virtual axi_lite_if vif;
    uvm_analysis_port #(axi_transaction) item_collected_port;

    function new(string name = "axi_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      
        	 success = uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif);
			if (!success)
  			`uvm_error("VIF", "Monitor could not get the virtual interface")
			else
  			`uvm_info("VIF", "Monitor successfully bound to virtual interface", UVM_MEDIUM)

    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            monitor_write();
            monitor_read();
        join
    endtask

    virtual task monitor_write();
        forever begin
            axi_transaction trans;
            @(posedge vif.aclk);
            if (vif.s_axi_awvalid && vif.s_axi_awready) begin
                trans = axi_transaction::type_id::create("write_trans");
                trans.kind = axi_transaction::WRITE;
                trans.addr = vif.s_axi_awaddr;

                // Wait for corresponding write data
               // @(posedge vif.aclk);
                while (!(vif.s_axi_wvalid && vif.s_axi_wready)) @(posedge vif.aclk);
                trans.wdata = vif.s_axi_wdata;
                trans.wstrb = vif.s_axi_wstrb;

                // Wait for write response
                @(posedge vif.aclk);
                while (!(vif.s_axi_bvalid && vif.s_axi_bready)) @(posedge vif.aclk);
                trans.resp = vif.s_axi_bresp;

                `uvm_info(get_type_name(), $sformatf("Monitor collected: %s", trans.sprint()), UVM_LOW)
                item_collected_port.write(trans);
            end
        end
    endtask

    virtual task monitor_read();
        forever begin
            axi_transaction trans;
            @(posedge vif.aclk);
            if (vif.s_axi_arvalid && vif.s_axi_arready) begin
                trans = axi_transaction::type_id::create("read_trans");
                trans.kind = axi_transaction::READ;
                trans.addr = vif.s_axi_araddr;

                // Wait for read data
                @(posedge vif.aclk);
                while (!(vif.s_axi_rvalid && vif.s_axi_rready)) @(posedge vif.aclk);
                trans.rdata = vif.s_axi_rdata;
                trans.resp  = vif.s_axi_rresp;

                `uvm_info(get_type_name(), $sformatf("Monitor collected: %s, RDATA=0x%h", trans.sprint(), trans.rdata), UVM_LOW)
                item_collected_port.write(trans);
            end
        end
    endtask

endclass