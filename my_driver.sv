// FILE: sram_driver.sv
// DESC: The driver's job is to translate an abstract transaction into
//       physical signal activity on the interface. It communicates with the DUT.
//       (*** UPDATED with parallel write and random backpressure ***)
`timescale 1ns/1ps

class axi_driver extends uvm_driver #(axi_transaction);
    `uvm_component_utils(axi_driver)

    virtual axi_lite_if vif;

    function new(string name = "axi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Virtual interface not found for axi_driver")
    endfunction

    virtual task run_phase(uvm_phase phase);
      
       @(posedge vif.aclk);
      while (!vif.aresetn) begin
        @(posedge vif.aclk);          `uvm_info("rest while in driver","1", UVM_NONE) 
      end
      
        forever begin
            seq_item_port.get_next_item(req);
          `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", req.sprint()), UVM_LOW)
            if (req.kind == axi_transaction::WRITE)
                drive_write(req);
            else
                drive_read(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_write(axi_transaction trans);
      
      
      // Drive Address Channel
      fork
        begin
        vif.driver_cb.s_axi_awvalid <= 1;
        vif.driver_cb.s_axi_awaddr  <= trans.addr;
        @(vif.driver_cb);
        while (!vif.driver_cb.s_axi_awready) begin @(vif.driver_cb);            `uvm_info("W1","1", UVM_NONE) end
        vif.driver_cb.s_axi_awvalid <= 0;
        end
      
      	begin
        // Drive Write Data Channel
        vif.driver_cb.s_axi_wvalid <= 1;
        vif.driver_cb.s_axi_wdata  <= trans.wdata;
        vif.driver_cb.s_axi_wstrb  <= trans.wstrb;
        @(vif.driver_cb);
        while (!vif.driver_cb.s_axi_wready) begin @(vif.driver_cb);            `uvm_info("W2","2", UVM_NONE) end
        vif.driver_cb.s_axi_wvalid <= 0;
        end
      join
        // Wait for Write Response Channel
        vif.driver_cb.s_axi_bready <= 1;
        @(vif.driver_cb);
      while (!vif.driver_cb.s_axi_bvalid) begin @(vif.driver_cb);            `uvm_info("W3","3", UVM_NONE) end
        trans.resp = vif.driver_cb.s_axi_bresp;
        vif.driver_cb.s_axi_bready <= 0;
    endtask

    virtual task drive_read(axi_transaction trans);
        // Drive Read Address Channel
        vif.driver_cb.s_axi_arvalid <= 1;
        vif.driver_cb.s_axi_araddr  <= trans.addr;
        @(vif.driver_cb);
        while (!vif.driver_cb.s_axi_arready) @(vif.driver_cb);
        vif.driver_cb.s_axi_arvalid <= 0;

        // Wait for Read Data Channel
        vif.driver_cb.s_axi_rready <= 1;
        @(vif.driver_cb);
        while (!vif.driver_cb.s_axi_rvalid) @(vif.driver_cb);
        trans.rdata = vif.driver_cb.s_axi_rdata;
        trans.resp  = vif.driver_cb.s_axi_rresp;
        vif.driver_cb.s_axi_rready <= 0;
    endtask

endclass