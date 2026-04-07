class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)
 
  //===========================================================================
  // Analysis Exports
  //===========================================================================
  uvm_analysis_imp_write #(axi4_seq_item, axi4_scoreboard) write_export;
  uvm_analysis_imp_read #(axi4_seq_item, axi4_scoreboard) read_export;
 
  //===========================================================================
  // Reference Memory Model
  //===========================================================================
  logic [7:0] ref_mem[int];  // Associative array for sparse memory
 
  //===========================================================================
  // Statistics
  //===========================================================================
  int unsigned write_count;
  int unsigned read_count;
  int unsigned match_count;
  int unsigned mismatch_count;
  int unsigned error_response_count;
 
  //===========================================================================
  // Configuration
  //===========================================================================
  bit enable_data_checking = 1;
  bit enable_response_checking = 1;
 
  //===========================================================================
  // Constructor
  //===========================================================================
  function new(string name = "axi4_scoreboard", uvm_component parent = null);
    super.new(name, parent);
  endfunction
 
  //===========================================================================
  // Build Phase
  //===========================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    write_export = new("write_export", this);
    read_export = new("read_export", this);
    
    // Initialize statistics
    write_count = 0;
    read_count = 0;
    match_count = 0;
    mismatch_count = 0;
    error_response_count = 0;
  endfunction
 
  //===========================================================================
  // Write Transaction Handler
  //===========================================================================
  function void write_write(axi4_seq_item item);
    logic [31:0] addr;
    logic [31:0] beat_addr;
    int num_bytes;
    
    write_count++;
    
    `uvm_info("SCB_WR", $sformatf("Processing write: addr=0x%0h, len=%0d, burst=%s, resp=%s",
      item.addr, item.len, item.burst.name(), item.bresp.name()), UVM_HIGH)
    
    // Check for error response
    if (item.bresp != axi4_pkg::RESP_OKAY) begin
      error_response_count++;
      check_error_response(item);
      return;  // Don't update reference memory on error
    end
    
    // Update reference memory for each beat
    addr = item.addr;
    num_bytes = 1 << item.size;
    
    for (int beat = 0; beat <= item.len; beat++) begin
      beat_addr = calc_beat_address(item.addr, beat, item.len, item.size, item.burst);
      
      // Apply strobe and update memory
      for (int byte_idx = 0; byte_idx < 8; byte_idx++) begin
        if (item.wstrb[beat][byte_idx]) begin
          ref_mem[beat_addr + byte_idx] = item.wdata[beat][byte_idx*8 +: 8];
          
          `uvm_info("SCB_WR", $sformatf("  Beat %0d: mem[0x%0h] = 0x%02h",
            beat, beat_addr + byte_idx, item.wdata[beat][byte_idx*8 +: 8]), UVM_FULL)
        end
      end
    end
    
    `uvm_info("SCB_WR", $sformatf("Write complete: %0d beats written", item.len + 1), UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // Read Transaction Handler
  //===========================================================================
  function void write_read(axi4_seq_item item);
    logic [31:0] beat_addr;
    logic [63:0] expected_data;
    logic [63:0] actual_data;
    bit data_match;
    int num_bytes;
    
    read_count++;
    
    `uvm_info("SCB_RD", $sformatf("Processing read: addr=0x%0h, len=%0d, burst=%s",
      item.addr, item.len, item.burst.name()), UVM_HIGH)
    
    // Check each beat's response
    for (int beat = 0; beat <= item.len; beat++) begin
      if (item.rresp[beat] != axi4_pkg::RESP_OKAY) begin
        error_response_count++;
        `uvm_info("SCB_RD", $sformatf("  Beat %0d: Error response %s",
          beat, item.rresp[beat].name()), UVM_MEDIUM)
        continue;
      end
      
      if (!enable_data_checking) continue;
      
      beat_addr = calc_beat_address(item.addr, beat, item.len, item.size, item.burst);
      
      // Build expected data from reference memory
      expected_data = 0;
      num_bytes = 1 << item.size;
      
      for (int byte_idx = 0; byte_idx < 8; byte_idx++) begin
        if (ref_mem.exists(beat_addr + byte_idx)) begin
          expected_data[byte_idx*8 +: 8] = ref_mem[beat_addr + byte_idx];
        end else begin
          expected_data[byte_idx*8 +: 8] = 8'h00;  // Uninitialized reads as 0
        end
      end
      
      actual_data = item.rdata[beat];
      
      // Compare based on transfer size
      data_match = compare_data_with_size(expected_data, actual_data, item.size, beat_addr);
      
      if (data_match) begin
        match_count++;
        `uvm_info("SCB_RD", $sformatf("  Beat %0d MATCH: addr=0x%0h, data=0x%0h",
          beat, beat_addr, actual_data), UVM_HIGH)
      end else begin
        mismatch_count++;
        `uvm_error("SCB_RD", $sformatf("  Beat %0d MISMATCH: addr=0x%0h, expected=0x%0h, actual=0x%0h",
          beat, beat_addr, expected_data, actual_data))
      end
    end
    
    `uvm_info("SCB_RD", $sformatf("Read complete: %0d beats checked", item.len + 1), UVM_MEDIUM)
  endfunction
 
  //===========================================================================
  // Calculate Beat Address
  //===========================================================================
  function logic [31:0] calc_beat_address(
    logic [31:0] start_addr,
    int beat_num,
    logic [7:0] axlen,
    logic [2:0] axsize,
    axi4_pkg::axi_burst_e axburst
  );
    logic [31:0] addr;
    logic [31:0] wrap_boundary;
    logic [31:0] wrap_mask;
    int num_bytes;
    
    num_bytes = 1 << axsize;
    addr = start_addr;
    
    case (axburst)
      axi4_pkg::BURST_FIXED: begin
        // Address stays fixed
        return start_addr;
      end
      
      axi4_pkg::BURST_INCR: begin
        // Increment address for each beat
        return start_addr + (beat_num * num_bytes);
      end
      
      axi4_pkg::BURST_WRAP: begin
        // Calculate wrap boundary and mask
        wrap_mask = ((axlen + 1) * num_bytes) - 1;
        wrap_boundary = start_addr & ~wrap_mask;
        
        addr = start_addr + (beat_num * num_bytes);
        
        // Check for wrap
        if ((addr & ~wrap_mask) != wrap_boundary) begin
          addr = wrap_boundary + (addr & wrap_mask);
        end
        
        return addr;
      end
      
      default: begin
        return start_addr + (beat_num * num_bytes);
      end
    endcase
  endfunction
 
  //===========================================================================
  // Compare Data with Size Consideration
  //===========================================================================
  function bit compare_data_with_size(
    logic [63:0] expected,
    logic [63:0] actual,
    logic [2:0] size,
    logic [31:0] addr
  );
    int num_bytes;
    int start_byte;
    logic [63:0] mask;
    
    num_bytes = 1 << size;
    start_byte = addr[2:0];  // Byte offset within 8-byte word
    
    // Create mask for valid bytes
    mask = 0;
    for (int i = 0; i < num_bytes && (start_byte + i) < 8; i++) begin
      mask[(start_byte + i)*8 +: 8] = 8'hFF;
    end
    
    return ((expected & mask) == (actual & mask));
  endfunction
 
  //===========================================================================
  // Check Error Response Validity
  //===========================================================================
  function void check_error_response(axi4_seq_item item);
    bit expected_error = 0;
    axi4_pkg::axi_resp_e expected_resp;
    
    // Check for expected error conditions
    
    // Out of range
    if (item.addr >= axi4_pkg::MEM_SIZE) begin
      expected_error = 1;
      expected_resp = axi4_pkg::RESP_SLVERR;
      `uvm_info("SCB_ERR", $sformatf("Expected SLVERR for out-of-range: addr=0x%0h",
        item.addr), UVM_MEDIUM)
    end
    
    // Exclusive access (not supported)
    if (item.lock == axi4_pkg::LOCK_EXCLUSIVE) begin
      expected_error = 1;
      expected_resp = axi4_pkg::RESP_SLVERR;
      `uvm_info("SCB_ERR", "Expected SLVERR for unsupported exclusive access", UVM_MEDIUM)
    end
    
    // Invalid WRAP length
    if (item.burst == axi4_pkg::BURST_WRAP) begin
      if (!axi4_pkg::is_valid_wrap_len(item.len)) begin
        expected_error = 1;
        expected_resp = axi4_pkg::RESP_SLVERR;
        `uvm_info("SCB_ERR", $sformatf("Expected SLVERR for invalid WRAP len: %0d",
          item.len), UVM_MEDIUM)
      end
    end
    
    // 4KB boundary crossing (INCR burst)
    if (item.burst == axi4_pkg::BURST_INCR) begin
      if (axi4_pkg::crosses_4kb_boundary(item.addr, item.len, item.size, item.burst)) begin
        expected_error = 1;
        expected_resp = axi4_pkg::RESP_DECERR;
        `uvm_info("SCB_ERR", "Expected DECERR for 4KB boundary crossing", UVM_MEDIUM)
      end
    end
    
    // Validate error response
    if (expected_error) begin
      if (enable_response_checking) begin
        if (item.bresp == expected_resp || 
            (item.txn_type == AXI_READ && item.rresp[0] == expected_resp)) begin
          `uvm_info("SCB_ERR", $sformatf("Correct error response: %s",
            item.bresp.name()), UVM_MEDIUM)
        end else begin
          `uvm_warning("SCB_ERR", $sformatf("Unexpected error response: got %s, expected %s",
            item.bresp.name(), expected_resp.name()))
        end
      end
    end else begin
      `uvm_warning("SCB_ERR", $sformatf("Unexpected error response: %s (no error expected)",
        item.bresp.name()))
    end
  endfunction
 
  //===========================================================================
  // Report Phase
  //===========================================================================
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    
    `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
    `uvm_info("SCB_REPORT", "       SCOREBOARD SUMMARY REPORT        ", UVM_NONE)
    `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("Total Write Transactions: %0d", write_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("Total Read Transactions:  %0d", read_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("Data Matches:             %0d", match_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("Data Mismatches:          %0d", mismatch_count), UVM_NONE)
    `uvm_info("SCB_REPORT", $sformatf("Error Responses:          %0d", error_response_count), UVM_NONE)
    `uvm_info("SCB_REPORT", "========================================", UVM_NONE)
    
    if (mismatch_count > 0) begin
      `uvm_error("SCB_REPORT", $sformatf("TEST FAILED: %0d data mismatches detected", mismatch_count))
    end else begin
      `uvm_info("SCB_REPORT", "TEST PASSED: All data comparisons matched", UVM_NONE)
    end
  endfunction
 
  //===========================================================================
  // Reset Reference Memory
  //===========================================================================
  function void reset_memory();
    ref_mem.delete();
    write_count = 0;
    read_count = 0;
    match_count = 0;
    mismatch_count = 0;
    error_response_count = 0;
    `uvm_info("SCB", "Reference memory reset", UVM_MEDIUM)
  endfunction
 
endclass : axi4_scoreboard
 
//=============================================================================
// Analysis Import Declarations
//=============================================================================
`uvm_analysis_imp_decl(_write)
`uvm_analysis_imp_decl(_read)