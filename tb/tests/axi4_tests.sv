`timescale 1ns/1ps

// Base Test
//=============================================================================
class axi4_base_test extends uvm_test;
  `uvm_component_utils(axi4_base_test)
 
  //===========================================================================
  // Test Components
  //===========================================================================
  axi4_env env;
 
  //===========================================================================
  // Virtual Interface
  //===========================================================================
  virtual axi4_if vif;
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
 
    // Get virtual interface from config DB
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for test")
    end
 
    // Pass to environment
    uvm_config_db#(virtual axi4_if)::set(this, "env", "vif", vif);
 
    // Create environment
    env = axi4_env::type_id::create("env", this);
 
    `uvm_info("BUILD", "Base test build complete", UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // End of Elaboration Phase
  //===========================================================================
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
 
  //===========================================================================
  // Run Phase
  //===========================================================================
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    `uvm_info("TEST", "Starting base test", UVM_MEDIUM)
    
    // Wait for reset
    wait_for_reset();
    
    // Run test-specific stimulus
    run_test_sequence();
    
    // Drain time
    #1000ns;
    
    `uvm_info("TEST", "Base test complete", UVM_MEDIUM)
    
    phase.drop_objection(this);
  endtask
 
  //===========================================================================
  // Wait for Reset
  //===========================================================================
  virtual task wait_for_reset();
    @(posedge vif.aresetn);
    repeat(10) @(posedge vif.aclk);
    `uvm_info("TEST", "Reset complete, starting test", UVM_MEDIUM)
  endtask
 
  //===========================================================================
  // Run Test Sequence (Override in derived tests)
  //===========================================================================
  virtual task run_test_sequence();
    `uvm_info("TEST", "No sequence defined in base test", UVM_MEDIUM)
  endtask
 
  //===========================================================================
  // Report Phase
  //===========================================================================
  function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    int err_count;
    
    super.report_phase(phase);
    
    svr = uvm_report_server::get_server();
    err_count = svr.get_severity_count(UVM_ERROR) + svr.get_severity_count(UVM_FATAL);
    
    `uvm_info("TEST_REPORT", "========================================", UVM_NONE)
    if (err_count > 0) begin
      `uvm_info("TEST_REPORT", $sformatf("TEST FAILED: %0d errors", err_count), UVM_NONE)
    end else begin
      `uvm_info("TEST_REPORT", "TEST PASSED", UVM_NONE)
    end
    `uvm_info("TEST_REPORT", "========================================", UVM_NONE)
  endfunction
 
endclass : axi4_base_test
 
//=============================================================================
// Sanity Test - Basic write/read verification
//=============================================================================
class axi4_sanity_test extends axi4_base_test;
  `uvm_component_utils(axi4_sanity_test)
 
  function new(string name = "axi4_sanity_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_write_read_seq wr_rd_seq;
    
    `uvm_info("TEST", "Running sanity test - write/read verification", UVM_MEDIUM)
    
    wr_rd_seq = axi4_write_read_seq::type_id::create("wr_rd_seq");
    wr_rd_seq.num_transactions = 10;
    
    for (int i = 0; i < 10; i++) begin
      if (!wr_rd_seq.randomize()) begin
        `uvm_error("TEST", "Failed to randomize write-read sequence")
      end
      wr_rd_seq.start(env.master_agent.sequencer);
    end
    
    `uvm_info("TEST", "Sanity test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_sanity_test
 
//=============================================================================
// Burst Test - All burst types (FIXED, INCR, WRAP)
//=============================================================================
class axi4_burst_test extends axi4_base_test;
  `uvm_component_utils(axi4_burst_test)
 
  function new(string name = "axi4_burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_fixed_burst_seq fixed_seq;
    axi4_wrap_burst_seq wrap_seq;
    axi4_random_mixed_seq incr_seq;
    
    `uvm_info("TEST", "Running burst test - all burst types", UVM_MEDIUM)
    
    // Test FIXED bursts
    `uvm_info("TEST", "Testing FIXED bursts", UVM_MEDIUM)
    fixed_seq = axi4_fixed_burst_seq::type_id::create("fixed_seq");
    fixed_seq.start(env.master_agent.sequencer);
    
    #500ns;
    
    // Test WRAP bursts
    `uvm_info("TEST", "Testing WRAP bursts", UVM_MEDIUM)
    wrap_seq = axi4_wrap_burst_seq::type_id::create("wrap_seq");
    wrap_seq.start(env.master_agent.sequencer);
    
    #500ns;
    
    // Test INCR bursts (via random mixed)
    `uvm_info("TEST", "Testing INCR bursts", UVM_MEDIUM)
    incr_seq = axi4_random_mixed_seq::type_id::create("incr_seq");
    incr_seq.num_txns = 20;
    incr_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Burst test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_burst_test
 
//=============================================================================
// Boundary Test - 4KB boundary crossing scenarios
//=============================================================================
class axi4_boundary_test extends axi4_base_test;
  `uvm_component_utils(axi4_boundary_test)
 
  function new(string name = "axi4_boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_burst_boundary_seq boundary_seq;
    
    `uvm_info("TEST", "Running 4KB boundary test", UVM_MEDIUM)
    
    boundary_seq = axi4_burst_boundary_seq::type_id::create("boundary_seq");
    boundary_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Boundary test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_boundary_test
 
//=============================================================================
// Unaligned Address Test
//=============================================================================
class axi4_unaligned_test extends axi4_base_test;
  `uvm_component_utils(axi4_unaligned_test)
 
  function new(string name = "axi4_unaligned_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_unaligned_addr_seq unaligned_seq;
    
    `uvm_info("TEST", "Running unaligned address test", UVM_MEDIUM)
    
    unaligned_seq = axi4_unaligned_addr_seq::type_id::create("unaligned_seq");
    unaligned_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Unaligned test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_unaligned_test
 
//=============================================================================
// Strobe Edge Cases Test
//=============================================================================
class axi4_strobe_test extends axi4_base_test;
  `uvm_component_utils(axi4_strobe_test)
 
  function new(string name = "axi4_strobe_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_strobe_edge_cases_seq strobe_seq;
    
    `uvm_info("TEST", "Running strobe edge cases test", UVM_MEDIUM)
    
    strobe_seq = axi4_strobe_edge_cases_seq::type_id::create("strobe_seq");
    strobe_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Strobe test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_strobe_test
 
//=============================================================================
// Error Injection Test
//=============================================================================
class axi4_error_test extends axi4_base_test;
  `uvm_component_utils(axi4_error_test)
 
  function new(string name = "axi4_error_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_error_injection_seq error_seq;
    
    `uvm_info("TEST", "Running error injection test", UVM_MEDIUM)
    
    error_seq = axi4_error_injection_seq::type_id::create("error_seq");
    error_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Error test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_error_test
 
//=============================================================================
// Back-to-Back Transaction Test
//=============================================================================
class axi4_b2b_test extends axi4_base_test;
  `uvm_component_utils(axi4_b2b_test)
 
  function new(string name = "axi4_b2b_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_back_to_back_seq b2b_seq;
    
    `uvm_info("TEST", "Running back-to-back transaction test", UVM_MEDIUM)
    
    b2b_seq = axi4_back_to_back_seq::type_id::create("b2b_seq");
    b2b_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Back-to-back test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_b2b_test
 
//=============================================================================
// Full Random Test - Comprehensive random testing
//=============================================================================
class axi4_random_test extends axi4_base_test;
  `uvm_component_utils(axi4_random_test)
 
  function new(string name = "axi4_random_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_random_mixed_seq random_seq;
    
    `uvm_info("TEST", "Running comprehensive random test", UVM_MEDIUM)
    
    random_seq = axi4_random_mixed_seq::type_id::create("random_seq");
    random_seq.num_txns = 100;
    random_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "Random test sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_random_test
 
//=============================================================================
// Regression Test - Runs all test scenarios
//=============================================================================
class axi4_regression_test extends axi4_base_test;
  `uvm_component_utils(axi4_regression_test)
 
  function new(string name = "axi4_regression_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  virtual task run_test_sequence();
    axi4_write_read_seq wr_rd_seq;
    axi4_burst_boundary_seq boundary_seq;
    axi4_unaligned_addr_seq unaligned_seq;
    axi4_strobe_edge_cases_seq strobe_seq;
    axi4_wrap_burst_seq wrap_seq;
    axi4_fixed_burst_seq fixed_seq;
    axi4_error_injection_seq error_seq;
    axi4_back_to_back_seq b2b_seq;
    axi4_random_mixed_seq random_seq;
    
    `uvm_info("TEST", "========================================", UVM_MEDIUM)
    `uvm_info("TEST", "Starting REGRESSION TEST", UVM_MEDIUM)
    `uvm_info("TEST", "========================================", UVM_MEDIUM)
    
    // Phase 1: Basic sanity
    `uvm_info("TEST", "Phase 1: Basic Write-Read", UVM_MEDIUM)
    wr_rd_seq = axi4_write_read_seq::type_id::create("wr_rd_seq");
    for (int i = 0; i < 5; i++) begin
      wr_rd_seq.randomize();
      wr_rd_seq.start(env.master_agent.sequencer);
    end
    #200ns;
    
    // Phase 2: Boundary tests
    `uvm_info("TEST", "Phase 2: 4KB Boundary", UVM_MEDIUM)
    boundary_seq = axi4_burst_boundary_seq::type_id::create("boundary_seq");
    boundary_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 3: Unaligned address
    `uvm_info("TEST", "Phase 3: Unaligned Addresses", UVM_MEDIUM)
    unaligned_seq = axi4_unaligned_addr_seq::type_id::create("unaligned_seq");
    unaligned_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 4: Strobe patterns
    `uvm_info("TEST", "Phase 4: Strobe Edge Cases", UVM_MEDIUM)
    strobe_seq = axi4_strobe_edge_cases_seq::type_id::create("strobe_seq");
    strobe_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 5: WRAP bursts
    `uvm_info("TEST", "Phase 5: WRAP Bursts", UVM_MEDIUM)
    wrap_seq = axi4_wrap_burst_seq::type_id::create("wrap_seq");
    wrap_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 6: FIXED bursts
    `uvm_info("TEST", "Phase 6: FIXED Bursts", UVM_MEDIUM)
    fixed_seq = axi4_fixed_burst_seq::type_id::create("fixed_seq");
    fixed_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 7: Error injection
    `uvm_info("TEST", "Phase 7: Error Injection", UVM_MEDIUM)
    error_seq = axi4_error_injection_seq::type_id::create("error_seq");
    error_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 8: Back-to-back
    `uvm_info("TEST", "Phase 8: Back-to-Back", UVM_MEDIUM)
    b2b_seq = axi4_back_to_back_seq::type_id::create("b2b_seq");
    b2b_seq.start(env.master_agent.sequencer);
    #200ns;
    
    // Phase 9: Random stress
    `uvm_info("TEST", "Phase 9: Random Stress", UVM_MEDIUM)
    random_seq = axi4_random_mixed_seq::type_id::create("random_seq");
    random_seq.num_txns = 50;
    random_seq.start(env.master_agent.sequencer);
    
    `uvm_info("TEST", "========================================", UVM_MEDIUM)
    `uvm_info("TEST", "REGRESSION TEST COMPLETE", UVM_MEDIUM)
    `uvm_info("TEST", "========================================", UVM_MEDIUM)
  endtask
 
endclass : axi4_regression_test