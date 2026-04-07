class axi4_master_sequencer extends uvm_sequencer #(axi4_seq_item);
  `uvm_component_utils(axi4_master_sequencer)
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_master_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
 
endclass : axi4_master_sequencer