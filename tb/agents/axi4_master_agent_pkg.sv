package axi4_master_agent_pkg;
 
  import uvm_pkg::*;
  `include "uvm_macros.svh"
 
  import axi4_pkg::*;
 
  // Transaction type enum
  typedef enum {AXI_WRITE, AXI_READ} axi_txn_type_e;
 
  // Include agent components in order
  `include "axi4_seq_item.sv"
  `include "axi4_master_driver.sv"
  `include "axi4_master_monitor.sv"
  `include "axi4_master_sequencer.sv"
  `include "axi4_master_agent.sv"
 
endpackage : axi4_master_agent_pkg