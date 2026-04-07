// Base Sequence
//=============================================================================
class axi4_base_sequence extends uvm_sequence #(axi4_seq_item);
  `uvm_object_utils(axi4_base_sequence)
 
  // Sequence configuration
  int unsigned num_transactions = 10;
  bit enable_response_check = 1;
 
  function new(string name = "axi4_base_sequence");
    super.new(name);
  endfunction
 
  virtual task pre_body();
    if (starting_phase != null)
      starting_phase.raise_objection(this);
  endtask
 
  virtual task post_body();
    if (starting_phase != null)
      starting_phase.drop_objection(this);
  endtask
 
endclass : axi4_base_sequence
 
//=============================================================================
// Single Write Sequence
//=============================================================================
class axi4_single_write_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_single_write_seq)
 
  rand logic [31:0] start_addr;
  rand logic [63:0] write_data;
  rand logic [7:0]  write_strb;
 
  constraint addr_c {
    start_addr inside {[0:axi4_pkg::MEM_SIZE-8]};
    start_addr[2:0] == 0; // Aligned
  }
 
  function new(string name = "axi4_single_write_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    item = axi4_seq_item::type_id::create("single_wr_item");
    start_item(item);
    
    if (!item.randomize() with {
      txn_type == AXI_WRITE;
      addr == local::start_addr;
      len == 0;
      size == 3; // 8 bytes
      burst == axi4_pkg::BURST_INCR;
      wdata.size() == 1;
      wstrb.size() == 1;
    }) begin
      `uvm_error("SEQ", "Randomization failed for single write")
    end
    
    item.wdata[0] = write_data;
    item.wstrb[0] = write_strb;
    
    finish_item(item);
    
    `uvm_info("SEQ", $sformatf("Single write: addr=0x%0h, data=0x%0h, strb=0x%0h",
      start_addr, write_data, write_strb), UVM_MEDIUM)
  endtask
 
endclass : axi4_single_write_seq
 
//=============================================================================
// Single Read Sequence
//=============================================================================
class axi4_single_read_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_single_read_seq)
 
  rand logic [31:0] start_addr;
 
  constraint addr_c {
    start_addr inside {[0:axi4_pkg::MEM_SIZE-8]};
    start_addr[2:0] == 0; // Aligned
  }
 
  function new(string name = "axi4_single_read_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    item = axi4_seq_item::type_id::create("single_rd_item");
    start_item(item);
    
    if (!item.randomize() with {
      txn_type == AXI_READ;
      addr == local::start_addr;
      len == 0;
      size == 3; // 8 bytes
      burst == axi4_pkg::BURST_INCR;
    }) begin
      `uvm_error("SEQ", "Randomization failed for single read")
    end
    
    finish_item(item);
    
    `uvm_info("SEQ", $sformatf("Single read: addr=0x%0h", start_addr), UVM_MEDIUM)
  endtask
 
endclass : axi4_single_read_seq
 
//=============================================================================
// Write-Read Back Sequence
//=============================================================================
class axi4_write_read_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_write_read_seq)
 
  rand logic [31:0] test_addr;
  rand logic [63:0] test_data;
 
  constraint addr_c {
    test_addr inside {[0:axi4_pkg::MEM_SIZE-64]};
    test_addr[2:0] == 0;
  }
 
  function new(string name = "axi4_write_read_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item wr_item, rd_item;
    
    // Write
    wr_item = axi4_seq_item::type_id::create("wr_item");
    start_item(wr_item);
    
    if (!wr_item.randomize() with {
      txn_type == AXI_WRITE;
      addr == local::test_addr;
      len == 0;
      size == 3;
      burst == axi4_pkg::BURST_INCR;
      wdata.size() == 1;
      wstrb.size() == 1;
    }) begin
      `uvm_error("SEQ", "Randomization failed for write")
    end
    wr_item.wdata[0] = test_data;
    wr_item.wstrb[0] = 8'hFF;
    
    finish_item(wr_item);
    
    // Small delay between write and read
    #10ns;
    
    // Read back
    rd_item = axi4_seq_item::type_id::create("rd_item");
    start_item(rd_item);
    
    if (!rd_item.randomize() with {
      txn_type == AXI_READ;
      addr == local::test_addr;
      len == 0;
      size == 3;
      burst == axi4_pkg::BURST_INCR;
    }) begin
      `uvm_error("SEQ", "Randomization failed for read")
    end
    
    finish_item(rd_item);
    
    `uvm_info("SEQ", $sformatf("Write-Read: addr=0x%0h, wrote=0x%0h", 
      test_addr, test_data), UVM_MEDIUM)
  endtask
 
endclass : axi4_write_read_seq
 
//=============================================================================
// Burst Boundary Crossing Sequence (4KB)
// Targets INCR bursts that approach or cross 4KB boundaries
//=============================================================================
class axi4_burst_boundary_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_burst_boundary_seq)
 
  function new(string name = "axi4_burst_boundary_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    logic [31:0] boundary_addrs[];
    
    // Test addresses near 4KB boundary (0x1000, 0x2000, etc.)
    boundary_addrs = '{
      32'h0FF0,  // 16 bytes before boundary
      32'h0FF8,  // 8 bytes before boundary
      32'h0FE0,  // 32 bytes before boundary
      32'h1FF0,  // Near second boundary
      32'h0FC0   // 64 bytes before boundary
    };
    
    foreach (boundary_addrs[i]) begin
      // Write burst that approaches boundary
      item = axi4_seq_item::type_id::create($sformatf("boundary_wr_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr == boundary_addrs[i];
        len inside {[1:7]};  // Short burst to test boundary
        size == 3;           // 8 bytes per beat
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for boundary test")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("Boundary test: addr=0x%0h, len=%0d, crosses=%0b",
        boundary_addrs[i], item.len, 
        axi4_pkg::crosses_4kb_boundary(item.addr, item.len, item.size, item.burst)),
        UVM_MEDIUM)
      
      #20ns;
    end
  endtask
 
endclass : axi4_burst_boundary_seq
 
//=============================================================================
// Unaligned Address Sequence
// Tests transfers with various address alignments
//=============================================================================
class axi4_unaligned_addr_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_unaligned_addr_seq)
 
  function new(string name = "axi4_unaligned_addr_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    // Test various unaligned addresses
    for (int offset = 0; offset < 8; offset++) begin
      // Write with unaligned address
      item = axi4_seq_item::type_id::create($sformatf("unaligned_wr_%0d", offset));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr[2:0] == offset;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        len inside {[0:3]};
        size inside {[0:3]};
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for unaligned write")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("Unaligned write: addr=0x%0h (offset=%0d), size=%0d",
        item.addr, offset, item.size), UVM_MEDIUM)
      
      #10ns;
      
      // Read back
      item = axi4_seq_item::type_id::create($sformatf("unaligned_rd_%0d", offset));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_READ;
        addr[2:0] == offset;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        len inside {[0:3]};
        size inside {[0:3]};
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for unaligned read")
      end
      
      finish_item(item);
      
      #10ns;
    end
  endtask
 
endclass : axi4_unaligned_addr_seq
 
//=============================================================================
// Narrow/Wide Strobe Edge Cases Sequence
// Tests various write strobe patterns including narrow transfers
//=============================================================================
class axi4_strobe_edge_cases_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_strobe_edge_cases_seq)
 
  function new(string name = "axi4_strobe_edge_cases_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    logic [7:0] strobe_patterns[];
    
    // Various strobe patterns to test
    strobe_patterns = '{
      8'b0000_0001,  // Single byte, lane 0
      8'b0000_0010,  // Single byte, lane 1
      8'b1000_0000,  // Single byte, lane 7
      8'b0000_1111,  // Lower 4 bytes
      8'b1111_0000,  // Upper 4 bytes
      8'b0000_0011,  // 2 bytes, lanes 0-1
      8'b0011_0000,  // 2 bytes, lanes 4-5
      8'b0101_0101,  // Alternating bytes
      8'b1010_1010,  // Alternating bytes (inverse)
      8'b1111_1111,  // All bytes
      8'b0000_0000,  // No bytes (edge case)
      8'b0011_1100,  // Middle 4 bytes
      8'b0001_1000   // Bytes 3-4
    };
    
    foreach (strobe_patterns[i]) begin
      item = axi4_seq_item::type_id::create($sformatf("strobe_wr_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        addr[2:0] == 0;  // Aligned for clarity
        len == 0;        // Single beat
        size == 3;       // Full 8-byte width
        burst == axi4_pkg::BURST_INCR;
        wdata.size() == 1;
        wstrb.size() == 1;
      }) begin
        `uvm_error("SEQ", "Randomization failed for strobe test")
      end
      
      item.wstrb[0] = strobe_patterns[i];
      item.wdata[0] = 64'hDEAD_BEEF_CAFE_BABE;  // Known pattern
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("Strobe test: addr=0x%0h, strb=0x%02h (0b%08b)",
        item.addr, strobe_patterns[i], strobe_patterns[i]), UVM_MEDIUM)
      
      #10ns;
    end
    
    // Narrow transfer test (smaller size with corresponding strobes)
    for (int sz = 0; sz <= 3; sz++) begin
      item = axi4_seq_item::type_id::create($sformatf("narrow_wr_sz%0d", sz));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        len inside {[0:3]};
        size == sz;
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for narrow transfer")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("Narrow transfer: size=%0d (%0d bytes), len=%0d",
        sz, 1 << sz, item.len), UVM_MEDIUM)
      
      #10ns;
    end
  endtask
 
endclass : axi4_strobe_edge_cases_seq
 
//=============================================================================
// WRAP Burst Sequence
// Tests WRAP burst with valid lengths (2, 4, 8, 16)
//=============================================================================
class axi4_wrap_burst_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_wrap_burst_seq)
 
  function new(string name = "axi4_wrap_burst_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    int valid_lens[] = '{1, 3, 7, 15};  // Corresponding to 2, 4, 8, 16 beats
    
    foreach (valid_lens[i]) begin
      // WRAP write
      item = axi4_seq_item::type_id::create($sformatf("wrap_wr_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr inside {[0:axi4_pkg::MEM_SIZE-256]};
        len == valid_lens[i];
        size == 3;  // 8 bytes
        burst == axi4_pkg::BURST_WRAP;
      }) begin
        `uvm_error("SEQ", "Randomization failed for WRAP write")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("WRAP write: addr=0x%0h, len=%0d (%0d beats)",
        item.addr, valid_lens[i], valid_lens[i] + 1), UVM_MEDIUM)
      
      #20ns;
      
      // WRAP read
      item = axi4_seq_item::type_id::create($sformatf("wrap_rd_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_READ;
        addr inside {[0:axi4_pkg::MEM_SIZE-256]};
        len == valid_lens[i];
        size == 3;
        burst == axi4_pkg::BURST_WRAP;
      }) begin
        `uvm_error("SEQ", "Randomization failed for WRAP read")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("WRAP read: addr=0x%0h, len=%0d (%0d beats)",
        item.addr, valid_lens[i], valid_lens[i] + 1), UVM_MEDIUM)
      
      #20ns;
    end
  endtask
 
endclass : axi4_wrap_burst_seq
 
//=============================================================================
// FIXED Burst Sequence
// Tests FIXED burst (FIFO-like access)
//=============================================================================
class axi4_fixed_burst_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_fixed_burst_seq)
 
  function new(string name = "axi4_fixed_burst_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    for (int i = 0; i < 5; i++) begin
      // FIXED write
      item = axi4_seq_item::type_id::create($sformatf("fixed_wr_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_WRITE;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        addr[2:0] == 0;
        len inside {[0:15]};  // FIXED bursts typically shorter
        size == 3;
        burst == axi4_pkg::BURST_FIXED;
      }) begin
        `uvm_error("SEQ", "Randomization failed for FIXED write")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("FIXED write: addr=0x%0h (constant), len=%0d",
        item.addr, item.len), UVM_MEDIUM)
      
      #20ns;
      
      // FIXED read from same address
      item = axi4_seq_item::type_id::create($sformatf("fixed_rd_%0d", i));
      start_item(item);
      
      if (!item.randomize() with {
        txn_type == AXI_READ;
        addr inside {[0:axi4_pkg::MEM_SIZE-64]};
        addr[2:0] == 0;
        len inside {[0:15]};
        size == 3;
        burst == axi4_pkg::BURST_FIXED;
      }) begin
        `uvm_error("SEQ", "Randomization failed for FIXED read")
      end
      
      finish_item(item);
      
      #20ns;
    end
  endtask
 
endclass : axi4_fixed_burst_seq
 
//=============================================================================
// Error Injection Sequence
// Tests error conditions: out-of-range, exclusive access, invalid WRAP
//=============================================================================
class axi4_error_injection_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_error_injection_seq)
 
  function new(string name = "axi4_error_injection_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    // Test 1: Out-of-range address (should get SLVERR)
    item = axi4_seq_item::type_id::create("out_of_range_wr");
    start_item(item);
    
    if (!item.randomize() with {
      txn_type == AXI_WRITE;
      addr >= axi4_pkg::MEM_SIZE;  // Beyond memory
      len == 0;
      size == 3;
      burst == axi4_pkg::BURST_INCR;
    }) begin
      `uvm_error("SEQ", "Randomization failed for out-of-range test")
    end
    
    finish_item(item);
    
    `uvm_info("SEQ", $sformatf("Out-of-range write: addr=0x%0h (MEM_SIZE=0x%0h)",
      item.addr, axi4_pkg::MEM_SIZE), UVM_MEDIUM)
    
    #20ns;
    
    // Test 2: Exclusive access (should get SLVERR - not supported)
    item = axi4_seq_item::type_id::create("exclusive_wr");
    start_item(item);
    
    if (!item.randomize() with {
      txn_type == AXI_WRITE;
      addr inside {[0:axi4_pkg::MEM_SIZE-64]};
      len == 0;
      size == 3;
      burst == axi4_pkg::BURST_INCR;
      lock == axi4_pkg::LOCK_EXCLUSIVE;
    }) begin
      `uvm_error("SEQ", "Randomization failed for exclusive test")
    end
    
    finish_item(item);
    
    `uvm_info("SEQ", $sformatf("Exclusive write: addr=0x%0h (unsupported)",
      item.addr), UVM_MEDIUM)
    
    #20ns;
    
    // Test 3: Invalid WRAP length
    // Note: This tests the DUT's error handling for protocol violations
    item = axi4_seq_item::type_id::create("invalid_wrap_wr");
    start_item(item);
    
    // Manually set invalid WRAP length (bypassing normal constraints)
    item.txn_type = AXI_WRITE;
    item.addr = 32'h100;
    item.len = 5;  // Invalid: not 1,3,7,15
    item.size = 3;
    item.burst = axi4_pkg::BURST_WRAP;
    item.lock = axi4_pkg::LOCK_NORMAL;
    item.wdata = new[6];
    item.wstrb = new[6];
    foreach (item.wdata[i]) begin
      item.wdata[i] = $urandom();
      item.wstrb[i] = 8'hFF;
    end
    
    finish_item(item);
    
    `uvm_info("SEQ", $sformatf("Invalid WRAP length: len=%0d (should be 1,3,7,15)",
      item.len), UVM_MEDIUM)
    
    #20ns;
  endtask
 
endclass : axi4_error_injection_seq
 
//=============================================================================
// Random Mixed Sequence
// Generates random mix of all transaction types
//=============================================================================
class axi4_random_mixed_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_random_mixed_seq)
 
  int unsigned num_txns = 50;
 
  function new(string name = "axi4_random_mixed_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item item;
    
    for (int i = 0; i < num_txns; i++) begin
      item = axi4_seq_item::type_id::create($sformatf("random_item_%0d", i));
      start_item(item);
      
      if (!item.randomize()) begin
        `uvm_error("SEQ", "Randomization failed for random mixed")
      end
      
      finish_item(item);
      
      `uvm_info("SEQ", $sformatf("Random txn %0d: type=%s, addr=0x%0h, len=%0d, burst=%s",
        i, item.txn_type.name(), item.addr, item.len, item.burst.name()), UVM_HIGH)
      
      // Random delay between transactions
      #($urandom_range(5, 20) * 1ns);
    end
  endtask
 
endclass : axi4_random_mixed_seq
 
//=============================================================================
// Back-to-Back Transaction Sequence
// Tests rapid successive transactions without delays
//=============================================================================
class axi4_back_to_back_seq extends axi4_base_sequence;
  `uvm_object_utils(axi4_back_to_back_seq)
 
  function new(string name = "axi4_back_to_back_seq");
    super.new(name);
  endfunction
 
  virtual task body();
    axi4_seq_item items[];
    
    items = new[20];
    
    // Fire multiple writes back-to-back
    for (int i = 0; i < 10; i++) begin
      items[i] = axi4_seq_item::type_id::create($sformatf("b2b_wr_%0d", i));
      start_item(items[i]);
      
      if (!items[i].randomize() with {
        txn_type == AXI_WRITE;
        addr inside {[i*64 : (i+1)*64-1]};
        addr[2:0] == 0;
        len inside {[0:3]};
        size == 3;
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for back-to-back write")
      end
      
      finish_item(items[i]);
      // No delay - back to back
    end
    
    // Fire multiple reads back-to-back
    for (int i = 10; i < 20; i++) begin
      items[i] = axi4_seq_item::type_id::create($sformatf("b2b_rd_%0d", i));
      start_item(items[i]);
      
      if (!items[i].randomize() with {
        txn_type == AXI_READ;
        addr inside {[(i-10)*64 : (i-9)*64-1]};
        addr[2:0] == 0;
        len inside {[0:3]};
        size == 3;
        burst == axi4_pkg::BURST_INCR;
      }) begin
        `uvm_error("SEQ", "Randomization failed for back-to-back read")
      end
      
      finish_item(items[i]);
    end
    
    `uvm_info("SEQ", "Back-to-back sequence complete", UVM_MEDIUM)
  endtask
 
endclass : axi4_back_to_back_seq