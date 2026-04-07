class axi4_master_driver extends uvm_driver #(axi4_seq_item);
 
  `uvm_component_utils(axi4_master_driver)
 
  //===========================================================================
  // Virtual Interface
  //===========================================================================
  virtual axi4_if vif;
 
  //===========================================================================
  // Configuration
  //===========================================================================
  int DATA_WIDTH = 64;
  int STRB_WIDTH = 8;
 
  //===========================================================================
  // Internal State
  //===========================================================================
  semaphore aw_sem, w_sem, ar_sem;  // Channel semaphores
  mailbox #(axi4_seq_item) wr_resp_mbx;  // For write response tracking
  
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_master_driver", uvm_component parent = null);
    super.new(name, parent);
    aw_sem = new(1);
    w_sem = new(1);
    ar_sem = new(1);
    wr_resp_mbx = new();
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for driver")
    end
  endfunction
 
  //===========================================================================
  // Run Phase
  //===========================================================================
  task run_phase(uvm_phase phase);
    // Initialize interface signals
    reset_signals();
    
    // Wait for reset deassertion
    @(posedge vif.aresetn);
    @(posedge vif.aclk);
    
    forever begin
      axi4_seq_item req;
      
      // Get next transaction from sequencer
      seq_item_port.get_next_item(req);
      
      `uvm_info("DRIVER", $sformatf("Driving transaction:\n%s", req.convert2string()), UVM_MEDIUM)
      
      req.start_time = $time;
      
      // Drive based on transaction type
      if (req.txn_type == axi4_seq_item::AXI_WRITE) begin
        drive_write(req);
      end else begin
        drive_read(req);
      end
      
      req.end_time = $time;
      req.completed = 1;
      
      seq_item_port.item_done();
    end
  endtask
 
  //===========================================================================
  // Reset Interface Signals
  //===========================================================================
  task reset_signals();
    // Write Address Channel
    vif.awid    <= '0;
    vif.awaddr  <= '0;
    vif.awlen   <= '0;
    vif.awsize  <= '0;
    vif.awburst <= '0;
    vif.awlock  <= '0;
    vif.awcache <= '0;
    vif.awprot  <= '0;
    vif.awqos   <= '0;
    vif.awregion <= '0;
    vif.awuser  <= '0;
    vif.awvalid <= 1'b0;
    
    // Write Data Channel
    vif.wdata   <= '0;
    vif.wstrb   <= '0;
    vif.wlast   <= 1'b0;
    vif.wuser   <= '0;
    vif.wvalid  <= 1'b0;
    
    // Write Response Channel
    vif.bready  <= 1'b0;
    
    // Read Address Channel
    vif.arid    <= '0;
    vif.araddr  <= '0;
    vif.arlen   <= '0;
    vif.arsize  <= '0;
    vif.arburst <= '0;
    vif.arlock  <= '0;
    vif.arcache <= '0;
    vif.arprot  <= '0;
    vif.arqos   <= '0;
    vif.arregion <= '0;
    vif.aruser  <= '0;
    vif.arvalid <= 1'b0;
    
    // Read Data Channel
    vif.rready  <= 1'b0;
  endtask
 
  //===========================================================================
  // Drive Write Transaction
  //===========================================================================
  task drive_write(axi4_seq_item txn);
    // Fork write address, write data, and wait for response
    fork
      drive_aw_channel(txn);
      drive_w_channel(txn);
      collect_b_response(txn);
    join
  endtask
 
  //===========================================================================
  // Drive Write Address Channel
  //===========================================================================
  task drive_aw_channel(axi4_seq_item txn);
    aw_sem.get(1);
    
    // Apply address delay
    repeat (txn.addr_delay) @(posedge vif.aclk);
    
    // Drive address phase
    @(posedge vif.aclk);
    vif.awid     <= txn.id;
    vif.awaddr   <= txn.addr;
    vif.awlen    <= txn.len;
    vif.awsize   <= txn.size;
    vif.awburst  <= txn.burst;
    vif.awlock   <= txn.lock;
    vif.awcache  <= txn.cache;
    vif.awprot   <= txn.prot;
    vif.awqos    <= txn.qos;
    vif.awregion <= txn.region;
    vif.awvalid  <= 1'b1;
    
    // Wait for AWREADY
    do begin
      @(posedge vif.aclk);
    end while (!vif.awready);
    
    // Deassert valid
    vif.awvalid <= 1'b0;
    
    aw_sem.put(1);
  endtask
 
  //===========================================================================
  // Drive Write Data Channel
  //===========================================================================
  task drive_w_channel(axi4_seq_item txn);
    w_sem.get(1);
    
    for (int beat = 0; beat <= txn.len; beat++) begin
      // Apply per-beat delay
      if (beat < txn.data_delay.size()) begin
        repeat (txn.data_delay[beat]) @(posedge vif.aclk);
      end
      
      @(posedge vif.aclk);
      vif.wdata  <= txn.wdata[beat];
      vif.wstrb  <= txn.wstrb[beat];
      vif.wlast  <= (beat == txn.len);
      vif.wvalid <= 1'b1;
      
      // Wait for WREADY
      do begin
        @(posedge vif.aclk);
      end while (!vif.wready);
    end
    
    // Deassert valid
    vif.wvalid <= 1'b0;
    vif.wlast  <= 1'b0;
    
    w_sem.put(1);
  endtask
 
  //===========================================================================
  // Collect Write Response
  //===========================================================================
  task collect_b_response(axi4_seq_item txn);
    // Wait a cycle then assert BREADY
    @(posedge vif.aclk);
    vif.bready <= 1'b1;
    
    // Wait for BVALID
    do begin
      @(posedge vif.aclk);
    end while (!vif.bvalid);
    
    // Capture response
    txn.bresp = vif.bresp;
    txn.bid = vif.bid;
    
    // Check ID matches
    if (txn.bid != txn.id) begin
      `uvm_error("DRIVER", $sformatf("Write response ID mismatch: expected %0h, got %0h", 
                 txn.id, txn.bid))
    end
    
    // Apply response delay before deasserting ready
    repeat (txn.resp_delay) @(posedge vif.aclk);
    
    @(posedge vif.aclk);
    vif.bready <= 1'b0;
  endtask
 
  //===========================================================================
  // Drive Read Transaction
  //===========================================================================
  task drive_read(axi4_seq_item txn);
    // Allocate space for read data
    txn.rdata = new[txn.len + 1];
    txn.rresp = new[txn.len + 1];
    
    // Fork read address and read data collection
    fork
      drive_ar_channel(txn);
      collect_r_data(txn);
    join
  endtask
 
  //===========================================================================
  // Drive Read Address Channel
  //===========================================================================
  task drive_ar_channel(axi4_seq_item txn);
    ar_sem.get(1);
    
    // Apply address delay
    repeat (txn.addr_delay) @(posedge vif.aclk);
    
    // Drive address phase
    @(posedge vif.aclk);
    vif.arid     <= txn.id;
    vif.araddr   <= txn.addr;
    vif.arlen    <= txn.len;
    vif.arsize   <= txn.size;
    vif.arburst  <= txn.burst;
    vif.arlock   <= txn.lock;
    vif.arcache  <= txn.cache;
    vif.arprot   <= txn.prot;
    vif.arqos    <= txn.qos;
    vif.arregion <= txn.region;
    vif.arvalid  <= 1'b1;
    
    // Wait for ARREADY
    do begin
      @(posedge vif.aclk);
    end while (!vif.arready);
    
    // Deassert valid
    vif.arvalid <= 1'b0;
    
    ar_sem.put(1);
  endtask
 
  //===========================================================================
  // Collect Read Data
  //===========================================================================
  task collect_r_data(axi4_seq_item txn);
    int beat = 0;
    
    // Assert RREADY
    @(posedge vif.aclk);
    vif.rready <= 1'b1;
    
    while (beat <= txn.len) begin
      @(posedge vif.aclk);
      
      if (vif.rvalid) begin
        // Capture read data
        txn.rdata[beat] = vif.rdata;
        txn.rresp[beat] = vif.rresp;
        txn.rid = vif.rid;
        
        // Check ID matches
        if (vif.rid != txn.id) begin
          `uvm_error("DRIVER", $sformatf("Read data ID mismatch: expected %0h, got %0h", 
                     txn.id, vif.rid))
        end
        
        // Check RLAST on final beat
        if (beat == txn.len && !vif.rlast) begin
          `uvm_error("DRIVER", "RLAST not asserted on final beat")
        end else if (beat < txn.len && vif.rlast) begin
          `uvm_error("DRIVER", $sformatf("RLAST asserted early at beat %0d", beat))
        end
        
        beat++;
        
        // Optionally deassert RREADY between beats for backpressure testing
        if (beat <= txn.len && beat < txn.data_delay.size() && txn.data_delay[beat] > 0) begin
          vif.rready <= 1'b0;
          repeat (txn.data_delay[beat]) @(posedge vif.aclk);
          vif.rready <= 1'b1;
        end
      end
    end
    
    // Deassert ready
    vif.rready <= 1'b0;
  endtask
 
endclass : axi4_master_driver