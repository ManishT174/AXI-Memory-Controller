class axi4_master_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_master_monitor)
 
  //===========================================================================
  // Virtual Interface
  //===========================================================================
  virtual axi4_if vif;
 
  //===========================================================================
  // Analysis Ports
  //===========================================================================
  uvm_analysis_port #(axi4_seq_item) write_ap;  // Write transactions
  uvm_analysis_port #(axi4_seq_item) read_ap;   // Read transactions
  uvm_analysis_port #(axi4_seq_item) item_ap;   // All transactions
 
  //===========================================================================
  // Configuration
  //===========================================================================
  bit checks_enable = 1;
  bit coverage_enable = 1;
 
  //===========================================================================
  // Internal Storage for In-flight Transactions
  //===========================================================================
  axi4_seq_item wr_addr_queue[$];
  axi4_seq_item rd_addr_queue[$];
 
  //===========================================================================
  // Coverage Groups
  //===========================================================================
  covergroup axi4_write_cg with function sample(axi4_seq_item item);
    option.per_instance = 1;
    
    burst_type_cp: coverpoint item.burst {
      bins fixed = {axi4_pkg::BURST_FIXED};
      bins incr  = {axi4_pkg::BURST_INCR};
      bins wrap  = {axi4_pkg::BURST_WRAP};
    }
    
    burst_len_cp: coverpoint item.len {
      bins single    = {0};
      bins short_b   = {[1:3]};
      bins medium_b  = {[4:15]};
      bins long_b    = {[16:63]};
      bins max_b     = {[64:255]};
    }
    
    burst_size_cp: coverpoint item.size {
      bins size_1b  = {0};
      bins size_2b  = {1};
      bins size_4b  = {2};
      bins size_8b  = {3};
    }
    
    addr_alignment_cp: coverpoint item.addr[2:0] {
      bins aligned    = {0};
      bins unaligned  = {[1:7]};
    }
    
    response_cp: coverpoint item.bresp {
      bins okay   = {axi4_pkg::RESP_OKAY};
      bins slverr = {axi4_pkg::RESP_SLVERR};
      bins decerr = {axi4_pkg::RESP_DECERR};
    }
    
    // Cross coverage
    burst_type_x_len: cross burst_type_cp, burst_len_cp;
    burst_type_x_size: cross burst_type_cp, burst_size_cp;
  endgroup
 
  covergroup axi4_read_cg with function sample(axi4_seq_item item);
    option.per_instance = 1;
    
    burst_type_cp: coverpoint item.burst {
      bins fixed = {axi4_pkg::BURST_FIXED};
      bins incr  = {axi4_pkg::BURST_INCR};
      bins wrap  = {axi4_pkg::BURST_WRAP};
    }
    
    burst_len_cp: coverpoint item.len {
      bins single    = {0};
      bins short_b   = {[1:3]};
      bins medium_b  = {[4:15]};
      bins long_b    = {[16:63]};
      bins max_b     = {[64:255]};
    }
    
    burst_size_cp: coverpoint item.size {
      bins size_1b  = {0};
      bins size_2b  = {1};
      bins size_4b  = {2};
      bins size_8b  = {3};
    }
    
    addr_alignment_cp: coverpoint item.addr[2:0] {
      bins aligned    = {0};
      bins unaligned  = {[1:7]};
    }
    
    // Cross coverage
    burst_type_x_len: cross burst_type_cp, burst_len_cp;
  endgroup
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_master_monitor", uvm_component parent = null);
    super.new(name, parent);
    write_ap = new("write_ap", this);
    read_ap = new("read_ap", this);
    item_ap = new("item_ap", this);
    
    if (coverage_enable) begin
      axi4_write_cg = new();
      axi4_read_cg = new();
    end
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(virtual axi4_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", "Virtual interface not found for monitor")
    end
  endfunction
 
  //===========================================================================
  // Run Phase
  //===========================================================================
  task run_phase(uvm_phase phase);
    fork
      monitor_write_address_channel();
      monitor_write_data_channel();
      monitor_write_response_channel();
      monitor_read_address_channel();
      monitor_read_data_channel();
    join
  endtask
 
  //===========================================================================
  // Write Address Channel Monitor
  //===========================================================================
  task monitor_write_address_channel();
    axi4_seq_item item;
    
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.awvalid && vif.awready) begin
        item = axi4_seq_item::type_id::create("wr_addr_item");
        item.txn_type = AXI_WRITE;
        item.addr = vif.awaddr;
        item.id = vif.awid;
        item.len = vif.awlen;
        item.size = vif.awsize;
        item.burst = axi4_pkg::axi_burst_e'(vif.awburst);
        item.lock = axi4_pkg::axi_lock_e'(vif.awlock);
        item.cache = vif.awcache;
        item.prot = vif.awprot;
        item.qos = vif.awqos;
        item.region = vif.awregion;
        
        // Initialize data arrays
        item.wdata = new[item.len + 1];
        item.wstrb = new[item.len + 1];
        
        wr_addr_queue.push_back(item);
        
        `uvm_info("MON_WR_ADDR", $sformatf("Captured write address: addr=0x%0h, id=%0d, len=%0d, burst=%s",
          item.addr, item.id, item.len, item.burst.name()), UVM_HIGH)
      end
    end
  endtask
 
  //===========================================================================
  // Write Data Channel Monitor
  //===========================================================================
  task monitor_write_data_channel();
    int beat_count;
    axi4_seq_item item;
    
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.wvalid && vif.wready) begin
        // Get the corresponding address phase item
        if (wr_addr_queue.size() > 0) begin
          item = wr_addr_queue[0];
          
          // Store data and strobe
          if (beat_count <= item.len) begin
            item.wdata[beat_count] = vif.wdata;
            item.wstrb[beat_count] = vif.wstrb;
          end
          
          if (vif.wlast) begin
            beat_count = 0;
          end else begin
            beat_count++;
          end
        end
        
        `uvm_info("MON_WR_DATA", $sformatf("Captured write data: data=0x%0h, strb=0x%0h, last=%0b",
          vif.wdata, vif.wstrb, vif.wlast), UVM_HIGH)
      end
    end
  endtask
 
  //===========================================================================
  // Write Response Channel Monitor
  //===========================================================================
  task monitor_write_response_channel();
    axi4_seq_item item;
    
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.bvalid && vif.bready) begin
        // Find matching address item by ID
        foreach (wr_addr_queue[i]) begin
          if (wr_addr_queue[i].id == vif.bid) begin
            item = wr_addr_queue[i];
            item.bresp = axi4_pkg::axi_resp_e'(vif.bresp);
            item.bid = vif.bid;
            
            // Sample coverage
            if (coverage_enable) begin
              axi4_write_cg.sample(item);
            end
            
            // Protocol checks
            if (checks_enable) begin
              check_write_response(item);
            end
            
            // Broadcast to analysis ports
            write_ap.write(item);
            item_ap.write(item);
            
            // Remove from queue
            wr_addr_queue.delete(i);
            
            `uvm_info("MON_WR_RESP", $sformatf("Captured write response: id=%0d, resp=%s",
              item.bid, item.bresp.name()), UVM_MEDIUM)
            break;
          end
        end
      end
    end
  endtask
 
  //===========================================================================
  // Read Address Channel Monitor
  //===========================================================================
  task monitor_read_address_channel();
    axi4_seq_item item;
    
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.arvalid && vif.arready) begin
        item = axi4_seq_item::type_id::create("rd_addr_item");
        item.txn_type = AXI_READ;
        item.addr = vif.araddr;
        item.id = vif.arid;
        item.len = vif.arlen;
        item.size = vif.arsize;
        item.burst = axi4_pkg::axi_burst_e'(vif.arburst);
        item.lock = axi4_pkg::axi_lock_e'(vif.arlock);
        item.cache = vif.arcache;
        item.prot = vif.arprot;
        item.qos = vif.arqos;
        item.region = vif.arregion;
        
        // Initialize data arrays
        item.rdata = new[item.len + 1];
        item.rresp = new[item.len + 1];
        
        rd_addr_queue.push_back(item);
        
        `uvm_info("MON_RD_ADDR", $sformatf("Captured read address: addr=0x%0h, id=%0d, len=%0d, burst=%s",
          item.addr, item.id, item.len, item.burst.name()), UVM_HIGH)
      end
    end
  endtask
 
  //===========================================================================
  // Read Data Channel Monitor
  //===========================================================================
  task monitor_read_data_channel();
    int beat_count;
    axi4_seq_item item;
    int item_idx;
    
    forever begin
      @(posedge vif.aclk);
      if (vif.aresetn && vif.rvalid && vif.rready) begin
        // Find matching address item by ID
        item_idx = -1;
        foreach (rd_addr_queue[i]) begin
          if (rd_addr_queue[i].id == vif.rid) begin
            item_idx = i;
            break;
          end
        end
        
        if (item_idx >= 0) begin
          item = rd_addr_queue[item_idx];
          
          // Store data and response
          if (beat_count <= item.len) begin
            item.rdata[beat_count] = vif.rdata;
            item.rresp[beat_count] = axi4_pkg::axi_resp_e'(vif.rresp);
          end
          
          `uvm_info("MON_RD_DATA", $sformatf("Captured read data: id=%0d, data=0x%0h, resp=%s, last=%0b",
            vif.rid, vif.rdata, axi4_pkg::axi_resp_e'(vif.rresp).name(), vif.rlast), UVM_HIGH)
          
          if (vif.rlast) begin
            item.rid = vif.rid;
            
            // Sample coverage
            if (coverage_enable) begin
              axi4_read_cg.sample(item);
            end
            
            // Protocol checks
            if (checks_enable) begin
              check_read_response(item);
            end
            
            // Broadcast to analysis ports
            read_ap.write(item);
            item_ap.write(item);
            
            // Remove from queue
            rd_addr_queue.delete(item_idx);
            beat_count = 0;
          end else begin
            beat_count++;
          end
        end
      end
    end
  endtask
 
  //===========================================================================
  // Protocol Checks
  //===========================================================================
  function void check_write_response(axi4_seq_item item);
    // Check ID matches
    if (item.id != item.bid) begin
      `uvm_error("PROT_CHK", $sformatf("Write response ID mismatch: expected=%0d, got=%0d",
        item.id, item.bid))
    end
    
    // Check WRAP burst length validity
    if (item.burst == axi4_pkg::BURST_WRAP) begin
      if (!axi4_pkg::is_valid_wrap_len(item.len)) begin
        `uvm_error("PROT_CHK", $sformatf("Invalid WRAP burst length: %0d (must be 1,3,7,15)",
          item.len))
      end
    end
  endfunction
 
  function void check_read_response(axi4_seq_item item);
    // Check ID matches
    if (item.id != item.rid) begin
      `uvm_error("PROT_CHK", $sformatf("Read response ID mismatch: expected=%0d, got=%0d",
        item.id, item.rid))
    end
    
    // Check WRAP burst length validity
    if (item.burst == axi4_pkg::BURST_WRAP) begin
      if (!axi4_pkg::is_valid_wrap_len(item.len)) begin
        `uvm_error("PROT_CHK", $sformatf("Invalid WRAP burst length: %0d (must be 1,3,7,15)",
          item.len))
      end
    end
    
    // Check for correct number of beats
    if (item.rdata.size() != item.len + 1) begin
      `uvm_warning("PROT_CHK", $sformatf("Read data beat count mismatch: expected=%0d, got=%0d",
        item.len + 1, item.rdata.size()))
    end
  endfunction
 
endclass : axi4_master_monitor