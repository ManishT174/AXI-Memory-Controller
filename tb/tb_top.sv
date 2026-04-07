`timescale 1ns/1ps
 
module tb_top;
 
  import uvm_pkg::*;
  `include "uvm_macros.svh"
 
  import axi4_pkg::*;
  import axi4_master_agent_pkg::*;
 
  //===========================================================================
  // Clock and Reset
  //===========================================================================
  logic aclk;
  logic aresetn;
 
  // Clock generation - 100MHz
  initial begin
    aclk = 0;
    forever #5ns aclk = ~aclk;
  end
 
  // Reset generation
  initial begin
    aresetn = 0;
    repeat(20) @(posedge aclk);
    aresetn = 1;
    `uvm_info("TB_TOP", "Reset deasserted", UVM_MEDIUM)
  end
 
  //===========================================================================
  // AXI4 Interface Instance
  //===========================================================================
  axi4_if axi_if(
    .aclk(aclk),
    .aresetn(aresetn)
  );
 
  //===========================================================================
  // DUT Instantiation
  //===========================================================================
  axi4_slave_mem_ctrl #(
    .DATA_WIDTH(axi4_pkg::AXI_DATA_WIDTH),
    .ADDR_WIDTH(axi4_pkg::AXI_ADDR_WIDTH),
    .ID_WIDTH(axi4_pkg::AXI_ID_WIDTH),
    .MEM_SIZE(axi4_pkg::MEM_SIZE)
  ) dut (
    // Clock and Reset
    .aclk(aclk),
    .aresetn(aresetn),
    
    // Write Address Channel
    .awid(axi_if.awid),
    .awaddr(axi_if.awaddr),
    .awlen(axi_if.awlen),
    .awsize(axi_if.awsize),
    .awburst(axi_if.awburst),
    .awlock(axi_if.awlock),
    .awcache(axi_if.awcache),
    .awprot(axi_if.awprot),
    .awqos(axi_if.awqos),
    .awregion(axi_if.awregion),
    .awvalid(axi_if.awvalid),
    .awready(axi_if.awready),
    
    // Write Data Channel
    .wdata(axi_if.wdata),
    .wstrb(axi_if.wstrb),
    .wlast(axi_if.wlast),
    .wvalid(axi_if.wvalid),
    .wready(axi_if.wready),
    
    // Write Response Channel
    .bid(axi_if.bid),
    .bresp(axi_if.bresp),
    .bvalid(axi_if.bvalid),
    .bready(axi_if.bready),
    
    // Read Address Channel
    .arid(axi_if.arid),
    .araddr(axi_if.araddr),
    .arlen(axi_if.arlen),
    .arsize(axi_if.arsize),
    .arburst(axi_if.arburst),
    .arlock(axi_if.arlock),
    .arcache(axi_if.arcache),
    .arprot(axi_if.arprot),
    .arqos(axi_if.arqos),
    .arregion(axi_if.arregion),
    .arvalid(axi_if.arvalid),
    .arready(axi_if.arready),
    
    // Read Data Channel
    .rid(axi_if.rid),
    .rdata(axi_if.rdata),
    .rresp(axi_if.rresp),
    .rlast(axi_if.rlast),
    .rvalid(axi_if.rvalid),
    .rready(axi_if.rready)
  );
 
  //===========================================================================
  // UVM Configuration and Test Start
  //===========================================================================
  initial begin
    // Set virtual interface in config DB
    uvm_config_db#(virtual axi4_if)::set(null, "*", "vif", axi_if);
    
    // Run UVM test
    run_test();
  end
 
  //===========================================================================
  // Waveform Dump (for debugging)
  //===========================================================================
  initial begin
    // Check for dump enable from command line
    if ($test$plusargs("DUMP_VCD")) begin
      $dumpfile("axi4_slave_tb.vcd");
      $dumpvars(0, tb_top);
      `uvm_info("TB_TOP", "VCD dump enabled", UVM_MEDIUM)
    end
    
    if ($test$plusargs("DUMP_FSDB")) begin
      // For Xcelium/Cadence
      `ifdef XCELIUM
        $fsdbDumpfile("axi4_slave_tb.fsdb");
        $fsdbDumpvars(0, tb_top, "+all");
        `uvm_info("TB_TOP", "FSDB dump enabled", UVM_MEDIUM)
      `endif
    end
  end
 
  //===========================================================================
  // Timeout Watchdog
  //===========================================================================
  initial begin
    #10ms;
    `uvm_fatal("TB_TOP", "Simulation timeout - test did not complete within 10ms")
  end
 
  //===========================================================================
  // Assertions - Global Protocol Checks
  //===========================================================================
  // Check reset behavior
  property p_reset_awvalid;
    @(posedge aclk) !aresetn |-> !axi_if.awvalid;
  endproperty
  
  property p_reset_wvalid;
    @(posedge aclk) !aresetn |-> !axi_if.wvalid;
  endproperty
  
  property p_reset_arvalid;
    @(posedge aclk) !aresetn |-> !axi_if.arvalid;
  endproperty
  
  property p_reset_bvalid;
    @(posedge aclk) !aresetn |-> !axi_if.bvalid;
  endproperty
  
  property p_reset_rvalid;
    @(posedge aclk) !aresetn |-> !axi_if.rvalid;
  endproperty
 
  // Enable assertions with +define+ENABLE_GLOBAL_ASSERTIONS
  `ifdef ENABLE_GLOBAL_ASSERTIONS
    assert property (p_reset_awvalid)
      else `uvm_error("ASSERT", "AWVALID should be low during reset")
    assert property (p_reset_wvalid)
      else `uvm_error("ASSERT", "WVALID should be low during reset")
    assert property (p_reset_arvalid)
      else `uvm_error("ASSERT", "ARVALID should be low during reset")
    assert property (p_reset_bvalid)
      else `uvm_error("ASSERT", "BVALID should be low during reset")
    assert property (p_reset_rvalid)
      else `uvm_error("ASSERT", "RVALID should be low during reset")
  `endif
 
endmodule : tb_top