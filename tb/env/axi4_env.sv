class axi4_env extends uvm_env;
  `uvm_component_utils(axi4_env)
 
  //===========================================================================
  // Environment Components
  //===========================================================================
  axi4_master_agent master_agent;
  axi4_scoreboard   scoreboard;
 
  //===========================================================================
  // Configuration
  //===========================================================================
  bit enable_scoreboard = 1;
  bit enable_coverage = 1;
 
  //===========================================================================
  // Virtual Interface
  //===========================================================================
  virtual axi4_if vif;
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
 
    // Get virtual interface
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for environment")
    end
 
    // Pass interface to agent
    uvm_config_db#(virtual axi4_if)::set(this, "master_agent*", "vif", vif);
 
    // Create master agent (active)
    master_agent = axi4_master_agent::type_id::create("master_agent", this);
    master_agent.is_active = UVM_ACTIVE;
 
    // Create scoreboard
    if (enable_scoreboard) begin
      scoreboard = axi4_scoreboard::type_id::create("scoreboard", this);
    end
 
    `uvm_info("BUILD", "Environment build complete", UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // Connect Phase
  //===========================================================================
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
 
    // Connect agent analysis ports to scoreboard
    if (enable_scoreboard) begin
      master_agent.write_ap.connect(scoreboard.write_export);
      master_agent.read_ap.connect(scoreboard.read_export);
    end
 
    `uvm_info("CONNECT", "Environment connections complete", UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // Run Phase
  //===========================================================================
  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask
 
  //===========================================================================
  // Report Phase
  //===========================================================================
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("ENV_REPORT", "Environment report phase", UVM_MEDIUM)
  endfunction
 
endclass : axi4_env