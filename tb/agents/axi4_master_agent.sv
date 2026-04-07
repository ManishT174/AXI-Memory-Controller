class axi4_master_agent extends uvm_agent;
  `uvm_component_utils(axi4_master_agent)
 
  //===========================================================================
  // Agent Components
  //===========================================================================
  axi4_master_driver    driver;
  axi4_master_monitor   monitor;
  axi4_master_sequencer sequencer;
 
  //===========================================================================
  // Configuration
  //===========================================================================
  uvm_active_passive_enum is_active = UVM_ACTIVE;
 
  //===========================================================================
  // Analysis Ports (pass-through from monitor)
  //===========================================================================
  uvm_analysis_port #(axi4_seq_item) write_ap;
  uvm_analysis_port #(axi4_seq_item) read_ap;
  uvm_analysis_port #(axi4_seq_item) item_ap;
 
  //===========================================================================
  // Virtual Interface
  //===========================================================================
  virtual axi4_if vif;
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
 
    // Get virtual interface
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for agent")
    end
 
    // Create analysis ports
    write_ap = new("write_ap", this);
    read_ap = new("read_ap", this);
    item_ap = new("item_ap", this);
 
    // Always create monitor
    monitor = axi4_master_monitor::type_id::create("monitor", this);
 
    // Create driver and sequencer only if active
    if (is_active == UVM_ACTIVE) begin
      driver = axi4_master_driver::type_id::create("driver", this);
      sequencer = axi4_master_sequencer::type_id::create("sequencer", this);
    end
 
    `uvm_info("BUILD", $sformatf("Agent built in %s mode", 
      (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"), UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // Connect Phase
  //===========================================================================
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
 
    // Connect monitor analysis ports
    monitor.write_ap.connect(write_ap);
    monitor.read_ap.connect(read_ap);
    monitor.item_ap.connect(item_ap);
 
    // Connect driver to sequencer if active
    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
 
    `uvm_info("CONNECT", "Agent connections complete", UVM_HIGH)
  endfunction
 
endclass : axi4_master_agent