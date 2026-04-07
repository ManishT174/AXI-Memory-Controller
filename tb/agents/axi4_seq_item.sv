`timescale 1ns/1ps

class axi4_seq_item extends uvm_sequence_item;
    // Configuration parameters
    static int DATA_WIDTH = 64;
    static int ADDR_WIDTH = 32;
    static int ID_WIDTH = 4;
    static int STRB_WIDTH = DATA_WIDTH / 8;
    static int MEM_SIZE = 4096;

    // Transaction type
    typedef enum {
        AXI_WRITE,
        AXI_READ
    } axi_txn_type_e;
    
    rand axi_txn_type_e txn_type;

    // Address channel fields
    rand bit [31:0]   addr;           // Transaction address
    rand bit [3:0]    id;             // Transaction ID
    rand bit [7:0]    len;            // Burst length (0=1 beat, 255=256 beats)
    rand bit [2:0]    size;           // Transfer size (2^size bytes)
    rand bit [1:0]    burst;          // Burst type: 00=FIXED, 01=INCR, 10=WRAP
    rand bit          lock;           // Lock type (exclusive access)
    rand bit [3:0]    cache;          // Cache type
    rand bit [2:0]    prot;           // Protection type
    rand bit [3:0]    qos;            // Quality of service
    rand bit [3:0]    region;         // Region identifier


    // Write data
    rand bit [63:0]   wdata[];        // Write data array (one per beat)
    rand bit [7:0]    wstrb[];        // Write strobes array (one per beat)

    // Read data
    bit [63:0]        rdata[];        // Read data array
    bit [1:0]         rresp[];        // Read response per beat

    // Response Fields
    bit [1:0]         bresp;          // Write response
    bit [3:0]         bid;            // Write response ID
    bit [3:0]         rid;            // Read response ID
    
    // Timing and Control
    rand int unsigned addr_delay;     // Delay before address phase
    rand int unsigned data_delay[];   // Delay between data beats
    rand int unsigned resp_delay;     // Delay for response ready
    
    // Status Flags (set by monitor/scoreboard)
    bit               completed;      // Transaction completed
    bit               error_occurred; // Error in transaction
    time              start_time;     // Start timestamp
    time              end_time;       // End timestamp
    
    // UVM Factory Registration
    `uvm_object_utils_begin(axi4_seq_item)
        `uvm_field_enum(axi_txn_type_e, txn_type, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(id, UVM_ALL_ON)
        `uvm_field_int(len, UVM_ALL_ON)
        `uvm_field_int(size, UVM_ALL_ON)
        `uvm_field_int(burst, UVM_ALL_ON)
        `uvm_field_int(lock, UVM_ALL_ON)
        `uvm_field_int(cache, UVM_ALL_ON)
        `uvm_field_int(prot, UVM_ALL_ON)
        `uvm_field_int(qos, UVM_ALL_ON)
        `uvm_field_int(region, UVM_ALL_ON)
        `uvm_field_array_int(wdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(wstrb, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(rdata, UVM_ALL_ON | UVM_HEX)
        `uvm_field_array_int(rresp, UVM_ALL_ON)
        `uvm_field_int(bresp, UVM_ALL_ON)
        `uvm_field_int(addr_delay, UVM_ALL_ON)
        `uvm_field_array_int(data_delay, UVM_ALL_ON)
        `uvm_field_int(resp_delay, UVM_ALL_ON)
        `uvm_field_int(completed, UVM_ALL_ON)
        `uvm_field_int(error_occurred, UVM_ALL_ON)
    `uvm_object_utils_end
    
    // Constraints
    // Address constraints
    constraint addr_range_c {
        addr < MEM_SIZE;  // Default: within valid range
    }
    
    // Transfer size must not exceed data bus width
    constraint size_valid_c {
        size <= $clog2(STRB_WIDTH);
    }
    
    // Burst type constraint (no reserved type)
    constraint burst_type_c {
        burst inside {2'b00, 2'b01, 2'b10};  // FIXED, INCR, WRAP
    }
    
    // WRAP burst must have length 2, 4, 8, or 16
    constraint wrap_len_c {
        if (burst == 2'b10) {  // WRAP
        len inside {8'd1, 8'd3, 8'd7, 8'd15};  // 2, 4, 8, 16 beats
        }
    }
    
    // 4KB boundary constraint for INCR bursts
    constraint incr_4kb_boundary_c {
        if (burst == 2'b01) {  // INCR
        // End address should be in same 4KB page (or we're testing boundary crossing)
        // This is soft - can be overridden for error injection
        soft ((addr + (len << size)) & 32'hFFFFF000) == (addr & 32'hFFFFF000);
        }
    }
    
    // Burst length constraint (reasonable for most tests)
    constraint len_reasonable_c {
        soft len <= 8'd15;  // Most tests use shorter bursts
    }
    
    // Lock constraint (no exclusive access by default)
    constraint lock_c {
        soft lock == 1'b0;
    }
    
    // Write data and strobe array sizing
    constraint wdata_size_c {
        wdata.size() == (len + 1);
        wstrb.size() == (len + 1);
        data_delay.size() == (len + 1);
    }
    
    // Strobe constraints - all bytes valid by default
    constraint wstrb_default_c {
        foreach (wstrb[i]) {
        soft wstrb[i] == get_valid_strobe(addr, size, i);
        }
    }
    
    // Timing constraints
    constraint timing_c {
        addr_delay inside {[0:10]};
        foreach (data_delay[i]) {
        data_delay[i] inside {[0:5]};
        }
        resp_delay inside {[0:10]};
    }
    

    // Constructor
    function new(string name = "axi4_seq_item");
        super.new(name);
    endfunction
    

    // Helper Functions
    // Calculate valid strobe based on address, size, and beat number
    function bit [7:0] get_valid_strobe(bit [31:0] addr, bit [2:0] size, int beat);
        bit [7:0] strobe;
        int num_bytes;
        int start_lane;
        bit [31:0] beat_addr;
        
        num_bytes = (1 << size);
        beat_addr = calc_beat_addr(addr, size, burst, beat);
        start_lane = beat_addr[$clog2(STRB_WIDTH)-1:0];
        
        strobe = '0;
        for (int i = 0; i < num_bytes && (start_lane + i) < STRB_WIDTH; i++) begin
        strobe[start_lane + i] = 1'b1;
        end
        
        return strobe;
    endfunction
    
    // Calculate address for a specific beat
    function bit [31:0] calc_beat_addr(bit [31:0] start_addr, bit [2:0] axsize, 
                                        bit [1:0] axburst, int beat);
        bit [31:0] current_addr;
        bit [31:0] incr;
        bit [31:0] wrap_mask;
        bit [31:0] wrap_boundary;
        
        incr = (1 << axsize);
        current_addr = start_addr;
        
        for (int i = 0; i < beat; i++) begin
        case (axburst)
            2'b00: current_addr = start_addr;  // FIXED
            2'b01: current_addr = current_addr + incr;  // INCR
            2'b10: begin  // WRAP
            wrap_mask = ((len + 1) << axsize) - 1;
            wrap_boundary = start_addr & ~wrap_mask;
            if ((current_addr + incr) >= (wrap_boundary + ((len + 1) << axsize)))
                current_addr = wrap_boundary;
            else
                current_addr = current_addr + incr;
            end
            default: current_addr = current_addr + incr;
        endcase
        end
        
        return current_addr;
    endfunction
    
    // Get total transfer size in bytes
    function int get_transfer_size();
        return (len + 1) * (1 << size);
    endfunction
    
    // Check if transaction crosses 4KB boundary
    function bit crosses_4kb_boundary();
        bit [31:0] end_addr;
        if (burst != 2'b01) return 0;  // Only INCR can cross
        end_addr = addr + (len * (1 << size));
        return (addr[31:12] != end_addr[31:12]);
    endfunction
    
    // Check if address is aligned to transfer size
    function bit is_aligned();
        bit [31:0] size_mask;
        size_mask = (1 << size) - 1;
        return ((addr & size_mask) == 0);
    endfunction
    
    // Convert to String for Debug
    function string convert2string();
        string s;
        s = $sformatf("\n========== AXI4 Transaction ==========\n");
        s = {s, $sformatf("  Type      : %s\n", txn_type.name())};
        s = {s, $sformatf("  ID        : 0x%0h\n", id)};
        s = {s, $sformatf("  Address   : 0x%08h\n", addr)};
        s = {s, $sformatf("  Length    : %0d beats\n", len + 1)};
        s = {s, $sformatf("  Size      : %0d bytes/beat\n", (1 << size))};
        s = {s, $sformatf("  Burst     : %s\n", 
            (burst == 2'b00) ? "FIXED" : 
            (burst == 2'b01) ? "INCR" : 
            (burst == 2'b10) ? "WRAP" : "RESERVED")};
        s = {s, $sformatf("  Aligned   : %s\n", is_aligned() ? "Yes" : "No")};
        s = {s, $sformatf("  4KB Cross : %s\n", crosses_4kb_boundary() ? "Yes" : "No")};
        
        if (txn_type == AXI_WRITE) begin
        s = {s, "  Write Data:\n"};
        foreach (wdata[i]) begin
            s = {s, $sformatf("    Beat[%0d]: Data=0x%016h, Strobe=0x%02h\n", 
                i, wdata[i], wstrb[i])};
        end
        s = {s, $sformatf("  Response  : %s\n", 
                (bresp == 2'b00) ? "OKAY" :
                (bresp == 2'b01) ? "EXOKAY" :
                (bresp == 2'b10) ? "SLVERR" : "DECERR")};
        end else begin
        s = {s, "  Read Data:\n"};
        foreach (rdata[i]) begin
            s = {s, $sformatf("    Beat[%0d]: Data=0x%016h, Resp=%s\n", 
                i, rdata[i],
                (rresp[i] == 2'b00) ? "OKAY" :
                (rresp[i] == 2'b01) ? "EXOKAY" :
                (rresp[i] == 2'b10) ? "SLVERR" : "DECERR")};
        end
        end
        
        s = {s, "==========================================\n"};
        return s;
    endfunction
    

    // Deep Copy
    function void do_copy(uvm_object rhs);
        axi4_seq_item rhs_;
        
        if (!$cast(rhs_, rhs)) begin
        `uvm_fatal("COPY", "Cast failed in do_copy")
        end
        
        super.do_copy(rhs);
        
        this.txn_type = rhs_.txn_type;
        this.addr = rhs_.addr;
        this.id = rhs_.id;
        this.len = rhs_.len;
        this.size = rhs_.size;
        this.burst = rhs_.burst;
        this.lock = rhs_.lock;
        this.cache = rhs_.cache;
        this.prot = rhs_.prot;
        this.qos = rhs_.qos;
        this.region = rhs_.region;
        this.bresp = rhs_.bresp;
        this.bid = rhs_.bid;
        this.rid = rhs_.rid;
        this.addr_delay = rhs_.addr_delay;
        this.resp_delay = rhs_.resp_delay;
        this.completed = rhs_.completed;
        this.error_occurred = rhs_.error_occurred;
        this.start_time = rhs_.start_time;
        this.end_time = rhs_.end_time;
        
        this.wdata = new[rhs_.wdata.size()];
        foreach (rhs_.wdata[i]) this.wdata[i] = rhs_.wdata[i];
        
        this.wstrb = new[rhs_.wstrb.size()];
        foreach (rhs_.wstrb[i]) this.wstrb[i] = rhs_.wstrb[i];
        
        this.rdata = new[rhs_.rdata.size()];
        foreach (rhs_.rdata[i]) this.rdata[i] = rhs_.rdata[i];
        
        this.rresp = new[rhs_.rresp.size()];
        foreach (rhs_.rresp[i]) this.rresp[i] = rhs_.rresp[i];
        
        this.data_delay = new[rhs_.data_delay.size()];
        foreach (rhs_.data_delay[i]) this.data_delay[i] = rhs_.data_delay[i];
    endfunction
    

    // Compare
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        axi4_seq_item rhs_;
        bit result;
        
        if (!$cast(rhs_, rhs)) begin
        `uvm_error("COMPARE", "Cast failed in do_compare")
        return 0;
        end
        
        result = super.do_compare(rhs, comparer);
        result &= (this.txn_type == rhs_.txn_type);
        result &= (this.addr == rhs_.addr);
        result &= (this.id == rhs_.id);
        result &= (this.len == rhs_.len);
        result &= (this.size == rhs_.size);
        result &= (this.burst == rhs_.burst);
        
        if (txn_type == AXI_WRITE) begin
        result &= (this.bresp == rhs_.bresp);
        foreach (this.wdata[i]) begin
            // Compare only the bytes that were actually written
            for (int j = 0; j < 8; j++) begin
            if (this.wstrb[i][j]) begin
                result &= (this.wdata[i][j*8 +: 8] == rhs_.wdata[i][j*8 +: 8]);
            end
            end
        end
        end else begin
        foreach (this.rdata[i]) begin
            result &= (this.rdata[i] == rhs_.rdata[i]);
            result &= (this.rresp[i] == rhs_.rresp[i]);
        end
        end
        
        return result;
    endfunction
    
endclass : axi4_seq_item
