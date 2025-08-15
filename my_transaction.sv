// FILE: sram_transaction.sv
// DESC: Defines the abstract transaction packet for an SRAM operation.
//       This is the fundamental unit of data passed from the sequence to the driver.
`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

class axi_transaction extends uvm_sequence_item;

    // Parameters for address and data widths
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;

    // Defines the type of transaction: READ or WRITE.
    typedef enum { WRITE, READ } kind_e;

    // --- Transaction Fields ---
    rand kind_e kind;                              // Operation type (READ/WRITE)
    rand logic [AXI_ADDR_WIDTH-1:0] addr;         // Address for the operation
    rand logic [AXI_DATA_WIDTH-1:0] wdata;        // Data for a WRITE operation
    rand logic [AXI_DATA_WIDTH/8-1:0] wstrb;      // Write strobe (byte enables)

    // --- Result Fields (captured by monitor) ---
    logic [AXI_DATA_WIDTH-1:0] rdata;             // Data from a READ operation
    logic [1:0] resp;                             // AXI response code (OKAY/SLVERR)

    // --- Constraints ---
    constraint c_valid_wstrb {
        // For a WRITE, at least one byte strobe must be active.
        (kind == WRITE) -> (wstrb != '0);
        // For a READ, the write strobe is unused and should be zero.
        (kind == READ)  -> (wstrb == '0);
    }

    // UVM Factory Registration and Field Macros
    `uvm_object_utils_begin(axi_transaction)
        `uvm_field_enum(kind_e, kind, UVM_ALL_ON)
        `uvm_field_int(addr,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(wstrb, UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(rdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(resp,  UVM_ALL_ON | UVM_HEX)
    `uvm_object_utils_end

    // Constructor
    function new(string name = "axi_transaction");
        super.new(name);
    endfunction

endclass