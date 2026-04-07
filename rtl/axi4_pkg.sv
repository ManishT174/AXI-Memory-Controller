package axi4_pkg; 

    // AXI4 Configuration Parameters
    // Data width (configurable)
    parameter int AXI_DATA_WIDTH = 64;

    // Address bus width
    parameter int AXI_ADDR_WIDTH = 32;

    // ID width for transaction tagging
    parameter int AXI_ID_WIDTH = 4;

    // Length width
    parameter int AXI_LEN_WIDTH = 8;

    // User signal widths
    parameter int AXI_AWUSER_WIDTH = 1;
    parameter int AXI_WUSER_WIDTH = 1;
    parameter int AXI_BUSER_WIDTH = 1;
    parameter int AXI_ARUSER_WIDTH = 1;
    parameter int AXI_RUSER_WIDTH = 1;

    // Derived parameters
    parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;
    parameter int AXI_SIZE_WIDTH = 3;

    // Memory size (Bytes)
    parameter int MEM_SIZE = 4096;
    parameter int MEM_ADDR_BITS = $clog2(MEM_SIZE);

    // AXI4 Burst Types
    typedef enum logic[1:0] {
        BURST_FIXED = 2'b00,    // Fixed address burst
        BURST_INCR  = 2'b01,    // Incrementing address burst
        BURST_WRAP  = 2'b10,    // Wrapping burst
        BURST_RSVD  = 2'b11     // Reserved
    } axi_burst_e;

    // AXI4 Response Types
    typedef enum logic [1:0] { 
        RESP_OKAY   = 2'b00,    // Normal access success
        RESP_EXOKAY = 2'b01,    // Exclusive access success
        RESP_SLVERR = 2'b10,    // Slave error
        RESP_DECERR = 2'b11     // Decode error
    } axi_resp_e;

    // AXI4 size encoding
    typedef enum logic [2:0] {
        SIZE_1B   = 3'b000,   // 1 byte
        SIZE_2B   = 3'b001,   // 2 bytes
        SIZE_4B   = 3'b010,   // 4 bytes
        SIZE_8B   = 3'b011,   // 8 bytes
        SIZE_16B  = 3'b100,   // 16 bytes
        SIZE_32B  = 3'b101,   // 32 bytes
        SIZE_64B  = 3'b110,   // 64 bytes
        SIZE_128B = 3'b111    // 128 bytes
    } axi_size_e;

    // AXI4 Lock types
    typedef enum logic {
        LOCK_NORMAL    = 1'b0,  // Normal access
        LOCK_EXCLUSIVE = 1'b1   // Exclusive access
    } axi_lock_e;

    // AXI4 Cache encoding
    // Bit 0: Bufferable
    // Bit 1: Cacheable
    // Bit 2: Read-allocate
    // Bit 3: Write-allocate
    typedef logic [3:0] axi_cache_t;

    // AXI4 Protection encoding
    // Bit 0: Privileged access
    // Bit 1: Non-secure access
    // Bit 2: Instruction access
    typedef logic [2:0] axi_prot_t;

    // AXI4 QoS
    typedef logic[3:0] axi_qos_t;

    // AXI4 Region Identifier
    typedef logic[3:0] axi_region_t;

    // Write address Channel Structure
    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]     awid;
        logic [AXI_ADDR_WIDTH-1:0]   awaddr;
        logic [AXI_LEN_WIDTH-1:0]    awlen;
        logic [AXI_SIZE_WIDTH-1:0]   awsize;
        axi_burst_e                  awburst;
        axi_lock_e                   awlock;
        axi_cache_t                  awcache;
        axi_prot_t                   awprot;
        axi_qos_t                    awqos;
        axi_region_t                 awregion;
        logic [AXI_AWUSER_WIDTH-1:0] awuser;
    } axi_aw_chan_t;

    // Write data channel structure
    typedef struct packed {
        logic [AXI_DATA_WIDTH-1:0]  wdata;
        logic [AXI_STRB_WIDTH-1:0]  wstrb;
        logic                       wlast;
        logic [AXI_WUSER_WIDTH-1:0] wuser;
    } axi_w_chan_t;

    // Write response channel structure
    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]    bid;
        axi_resp_e                  bresp;
        logic [AXI_BUSER_WIDTH-1:0] buser;
    } axi_b_chan_t;

    // Read address channel structure
    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]     arid;
        logic [AXI_ADDR_WIDTH-1:0]   araddr;
        logic [AXI_LEN_WIDTH-1:0]    arlen;
        logic [AXI_SIZE_WIDTH-1:0]   arsize;
        axi_burst_e                  arburst;
        axi_lock_e                   arlock;
        axi_cache_t                  arcache;
        axi_prot_t                   arprot;
        axi_qos_t                    arqos;
        axi_region_t                 arregion;
        logic [AXI_ARUSER_WIDTH-1:0] aruser;
    } axi_ar_chan_t;

    // Read data channel structure
    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]    rid;
        logic [AXI_DATA_WIDTH-1:0]  rdata;
        axi_resp_e                  rresp;
        logic                       rlast;
        logic [AXI_RUSER_WIDTH-1:0] ruser;
    } axi_r_chan_t;

    // Utility Functions
    // Calculate number of bytes per transfer based on AxSIZE
    function automatic int unsigned get_bytes_per_beat(logic [2:0] axsize);
        return (1 << axsize);
    endfunction

    // Calculate wrap boundary for WRAP bursts
    // Wrap boundary = (AxLEN + 1) * number_of_bytes_per_beat
    function automatic logic [AXI_ADDR_WIDTH-1:0] get_wrap_boundary(
        logic [AXI_ADDR_WIDTH-1:0] addr,
        logic [AXI_LEN_WIDTH-1:0]  axlen,
        logic [AXI_SIZE_WIDTH-1:0] axsize
    );
        logic [AXI_ADDR_WIDTH-1:0] wrap_size;
        logic [AXI_ADDR_WIDTH-1:0] wrap_mask;
        
        // WRAP bursts must have length of 2, 4, 8, or 16
        wrap_size = (axlen + 1) * get_bytes_per_beat(axsize);
        wrap_mask = wrap_size - 1;
        
        return (addr & ~wrap_mask);
    endfunction
    
    // Calculate next address for burst
    function automatic logic [AXI_ADDR_WIDTH-1:0] calc_next_addr(
        logic [AXI_ADDR_WIDTH-1:0] current_addr,
        logic [AXI_ADDR_WIDTH-1:0] start_addr,
        logic [AXI_LEN_WIDTH-1:0]  axlen,
        logic [AXI_SIZE_WIDTH-1:0] axsize,
        axi_burst_e                axburst
    );
        logic [AXI_ADDR_WIDTH-1:0] aligned_addr;
        logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
        logic [AXI_ADDR_WIDTH-1:0] upper_wrap_boundary;
        logic [AXI_ADDR_WIDTH-1:0] incr;
        logic [AXI_ADDR_WIDTH-1:0] wrap_mask;
        
        incr = get_bytes_per_beat(axsize);
        
        case (axburst)
        BURST_FIXED: begin
            return start_addr; // Address stays fixed
        end
        
        BURST_INCR: begin
            return current_addr + incr;
        end
        
        BURST_WRAP: begin
            wrap_boundary = get_wrap_boundary(start_addr, axlen, axsize);
            wrap_mask = ((axlen + 1) * incr) - 1;
            upper_wrap_boundary = wrap_boundary + ((axlen + 1) * incr);
            
            // Calculate next address with wrapping
            if ((current_addr + incr) >= upper_wrap_boundary)
            return wrap_boundary;
            else
            return current_addr + incr;
        end
        
        default: begin
            return current_addr + incr; // Default to INCR behavior
        end
        endcase
    endfunction
    
    // Check if address crosses 4KB boundary (AXI4 requirement)
    function automatic logic crosses_4kb_boundary(
        logic [AXI_ADDR_WIDTH-1:0] start_addr,
        logic [AXI_LEN_WIDTH-1:0]  axlen,
        logic [AXI_SIZE_WIDTH-1:0] axsize,
        axi_burst_e                axburst
    );
        logic [AXI_ADDR_WIDTH-1:0] end_addr;
        logic [AXI_ADDR_WIDTH-1:0] incr;
        
        // WRAP and FIXED bursts cannot cross 4KB boundary by definition
        if (axburst != BURST_INCR)
        return 1'b0;
        
        incr = get_bytes_per_beat(axsize);
        end_addr = start_addr + (axlen * incr);
        
        // Check if start and end addresses are in different 4KB pages
        return (start_addr[AXI_ADDR_WIDTH-1:12] != end_addr[AXI_ADDR_WIDTH-1:12]);
    endfunction
    
    // Validate WRAP burst length (must be 2, 4, 8, or 16)
    function automatic logic is_valid_wrap_len(logic [AXI_LEN_WIDTH-1:0] axlen);
        return (axlen == 8'd1 || axlen == 8'd3 || axlen == 8'd7 || axlen == 8'd15);
    endfunction
    
    // Get aligned address based on transfer size
    function automatic logic [AXI_ADDR_WIDTH-1:0] get_aligned_addr(
        logic [AXI_ADDR_WIDTH-1:0] addr,
        logic [AXI_SIZE_WIDTH-1:0] axsize
    );
        logic [AXI_ADDR_WIDTH-1:0] size_mask;
        size_mask = (1 << axsize) - 1;
        return addr & ~size_mask;
    endfunction
    
    // Calculate byte lane strobes based on address and size
    function automatic logic [AXI_STRB_WIDTH-1:0] calc_strobe(
        logic [AXI_ADDR_WIDTH-1:0] addr,
        logic [AXI_SIZE_WIDTH-1:0] axsize
    );
        logic [AXI_STRB_WIDTH-1:0] strobe;
        int unsigned num_bytes;
        int unsigned start_lane;
        
        num_bytes = get_bytes_per_beat(axsize);
        start_lane = addr[$clog2(AXI_STRB_WIDTH)-1:0];
        
        strobe = '0;
        for (int i = 0; i < num_bytes && (start_lane + i) < AXI_STRB_WIDTH; i++) begin
        strobe[start_lane + i] = 1'b1;
        end
        
        return strobe;
    endfunction

endpackage : axi4_pkg