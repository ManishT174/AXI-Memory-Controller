module axi4_slave_mem_ctrl #(
  parameter int DATA_WIDTH     = 64,
  parameter int ADDR_WIDTH     = 32,
  parameter int ID_WIDTH       = 4,
  parameter int MEM_SIZE       = 4096,          // Memory size in bytes
  parameter int MAX_OUTSTANDING_WR = 4,         // Max outstanding write transactions
  parameter int MAX_OUTSTANDING_RD = 4,         // Max outstanding read transactions
  parameter int AWUSER_WIDTH   = 1,
  parameter int WUSER_WIDTH    = 1,
  parameter int BUSER_WIDTH    = 1,
  parameter int ARUSER_WIDTH   = 1,
  parameter int RUSER_WIDTH    = 1
)(
  // Clock and Reset
  input  logic                    aclk,
  input  logic                    aresetn,
  
  
  // Write Address Channel
  input  logic [ID_WIDTH-1:0]     awid,
  input  logic [ADDR_WIDTH-1:0]   awaddr,
  input  logic [7:0]              awlen,
  input  logic [2:0]              awsize,
  input  logic [1:0]              awburst,
  input  logic                    awlock,
  input  logic [3:0]              awcache,
  input  logic [2:0]              awprot,
  input  logic [3:0]              awqos,
  input  logic [3:0]              awregion,
  input  logic [AWUSER_WIDTH-1:0] awuser,
  input  logic                    awvalid,
  output logic                    awready,
 
  
  // Write Data Channel
  input  logic [DATA_WIDTH-1:0]   wdata,
  input  logic [DATA_WIDTH/8-1:0] wstrb,
  input  logic                    wlast,
  input  logic [WUSER_WIDTH-1:0]  wuser,
  input  logic                    wvalid,
  output logic                    wready,
 
  
  // Write Response Channel
  output logic [ID_WIDTH-1:0]     bid,
  output logic [1:0]              bresp,
  output logic [BUSER_WIDTH-1:0]  buser,
  output logic                    bvalid,
  input  logic                    bready,
 
  
  // Read Address Channel
  input  logic [ID_WIDTH-1:0]     arid,
  input  logic [ADDR_WIDTH-1:0]   araddr,
  input  logic [7:0]              arlen,
  input  logic [2:0]              arsize,
  input  logic [1:0]              arburst,
  input  logic                    arlock,
  input  logic [3:0]              arcache,
  input  logic [2:0]              arprot,
  input  logic [3:0]              arqos,
  input  logic [3:0]              arregion,
  input  logic [ARUSER_WIDTH-1:0] aruser,
  input  logic                    arvalid,
  output logic                    arready,
 
  
  // Read Data Channel
  output logic [ID_WIDTH-1:0]     rid,
  output logic [DATA_WIDTH-1:0]   rdata,
  output logic [1:0]              rresp,
  output logic                    rlast,
  output logic [RUSER_WIDTH-1:0]  ruser,
  output logic                    rvalid,
  input  logic                    rready
);
 
  
  // Local Parameters
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int MEM_DEPTH = MEM_SIZE / STRB_WIDTH;
  localparam int MEM_ADDR_BITS = $clog2(MEM_SIZE);
  localparam int WORD_ADDR_BITS = $clog2(STRB_WIDTH);
  
  // Burst types
  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam logic [1:0] BURST_WRAP  = 2'b10;
  
  // Response types
  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_EXOKAY = 2'b01;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam logic [1:0] RESP_DECERR = 2'b11;
 
  
  // Memory Array
  logic [7:0] mem [0:MEM_SIZE-1];  // Byte-addressable memory
  
  
  // Write Transaction Tracking Structures
  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [ADDR_WIDTH-1:0] start_addr;
    logic [7:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
    logic                  lock;
    logic [7:0]            beat_cnt;
    logic                  error;
    logic                  valid;
  } wr_txn_t;
 
  wr_txn_t wr_txn_queue [0:MAX_OUTSTANDING_WR-1];
  logic [$clog2(MAX_OUTSTANDING_WR)-1:0] wr_head, wr_tail;
  logic [MAX_OUTSTANDING_WR-1:0] wr_queue_valid;
  logic wr_queue_full, wr_queue_empty;
  
  // Write FSM states
  typedef enum logic [2:0] {
    WR_IDLE,
    WR_ADDR_RECV,
    WR_DATA_RECV,
    WR_WAIT_LAST,
    WR_RESP
  } wr_state_e;
  
  wr_state_e wr_state, wr_state_next;
 
  
  // Read Transaction Tracking Structures
  typedef struct packed {
    logic [ID_WIDTH-1:0]   id;
    logic [ADDR_WIDTH-1:0] addr;
    logic [ADDR_WIDTH-1:0] start_addr;
    logic [7:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
    logic                  lock;
    logic [7:0]            beat_cnt;
    logic                  error;
    logic                  valid;
  } rd_txn_t;
 
  rd_txn_t rd_txn_queue [0:MAX_OUTSTANDING_RD-1];
  logic [$clog2(MAX_OUTSTANDING_RD)-1:0] rd_head, rd_tail;
  logic [MAX_OUTSTANDING_RD-1:0] rd_queue_valid;
  logic rd_queue_full, rd_queue_empty;
 
  // Read FSM states
  typedef enum logic [2:0] {
    RD_IDLE,
    RD_ADDR_RECV,
    RD_DATA_SEND,
    RD_WAIT_READY
  } rd_state_e;
  
  rd_state_e rd_state, rd_state_next;
 
  
  // Internal Signals
  // Write path
  logic [ADDR_WIDTH-1:0] wr_addr_current;
  logic [7:0]            wr_beat_cnt;
  logic [ID_WIDTH-1:0]   wr_current_id;
  logic [7:0]            wr_current_len;
  logic [2:0]            wr_current_size;
  logic [1:0]            wr_current_burst;
  logic                  wr_current_lock;
  logic [ADDR_WIDTH-1:0] wr_start_addr;
  logic                  wr_error_flag;
  logic                  wr_handshake_aw;
  logic                  wr_handshake_w;
  logic                  wr_handshake_b;
 
  // Read path
  logic [ADDR_WIDTH-1:0] rd_addr_current;
  logic [7:0]            rd_beat_cnt;
  logic [ID_WIDTH-1:0]   rd_current_id;
  logic [7:0]            rd_current_len;
  logic [2:0]            rd_current_size;
  logic [1:0]            rd_current_burst;
  logic                  rd_current_lock;
  logic [ADDR_WIDTH-1:0] rd_start_addr;
  logic                  rd_error_flag;
  logic                  rd_handshake_ar;
  logic                  rd_handshake_r;
 
  // Address calculation
  logic [ADDR_WIDTH-1:0] wr_next_addr;
  logic [ADDR_WIDTH-1:0] rd_next_addr;
 
  
  // Handshake Detection
  assign wr_handshake_aw = awvalid && awready;
  assign wr_handshake_w  = wvalid && wready;
  assign wr_handshake_b  = bvalid && bready;
  assign rd_handshake_ar = arvalid && arready;
  assign rd_handshake_r  = rvalid && rready;
 
  
  // Queue Management
  assign wr_queue_full  = &wr_queue_valid;
  assign wr_queue_empty = ~|wr_queue_valid;
  assign rd_queue_full  = &rd_queue_valid;
  assign rd_queue_empty = ~|rd_queue_valid;
 
  
  // Address Calculation Functions
  function automatic logic [ADDR_WIDTH-1:0] calc_next_addr(
    input logic [ADDR_WIDTH-1:0] current_addr,
    input logic [ADDR_WIDTH-1:0] start_addr,
    input logic [7:0]            axlen,
    input logic [2:0]            axsize,
    input logic [1:0]            axburst
  );
    logic [ADDR_WIDTH-1:0] incr;
    logic [ADDR_WIDTH-1:0] wrap_mask;
    logic [ADDR_WIDTH-1:0] wrap_boundary;
    logic [ADDR_WIDTH-1:0] upper_wrap;
    
    incr = (1 << axsize);
    
    case (axburst)
      BURST_FIXED: begin
        return start_addr;
      end
      
      BURST_INCR: begin
        return current_addr + incr;
      end
      
      BURST_WRAP: begin
        // Calculate wrap boundary
        wrap_mask = ((axlen + 1) << axsize) - 1;
        wrap_boundary = start_addr & ~wrap_mask;
        upper_wrap = wrap_boundary + ((axlen + 1) << axsize);
        
        if ((current_addr + incr) >= upper_wrap)
          return wrap_boundary;
        else
          return current_addr + incr;
      end
      
      default: begin
        return current_addr + incr;
      end
    endcase
  endfunction
 
  // Check for errors
  function automatic logic check_transaction_error(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [7:0]            axlen,
    input logic [2:0]            axsize,
    input logic [1:0]            axburst,
    input logic                  axlock
  );
    logic [ADDR_WIDTH-1:0] end_addr;
    logic [ADDR_WIDTH-1:0] incr;
    
    // Check address range
    if (addr >= MEM_SIZE)
      return 1'b1;
    
    // Check for exclusive access (not supported)
    if (axlock)
      return 1'b1;
    
    // Check WRAP burst has valid length (2, 4, 8, or 16)
    if (axburst == BURST_WRAP) begin
      if (!(axlen == 8'd1 || axlen == 8'd3 || axlen == 8'd7 || axlen == 8'd15))
        return 1'b1;
    end
    
    // Check 4KB boundary crossing for INCR bursts
    if (axburst == BURST_INCR) begin
      incr = (1 << axsize);
      end_addr = addr + (axlen * incr);
      if (addr[ADDR_WIDTH-1:12] != end_addr[ADDR_WIDTH-1:12])
        return 1'b1;
    end
    
    // Check transfer size doesn't exceed data width
    if ((1 << axsize) > STRB_WIDTH)
      return 1'b1;
    
    return 1'b0;
  endfunction
 
  
  // Write State Machine
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      wr_state <= WR_IDLE;
    end else begin
      wr_state <= wr_state_next;
    end
  end
 
  always_comb begin
    wr_state_next = wr_state;
    
    case (wr_state)
      WR_IDLE: begin
        if (awvalid && !wr_queue_full)
          wr_state_next = WR_ADDR_RECV;
      end
      
      WR_ADDR_RECV: begin
        if (wr_handshake_aw)
          wr_state_next = WR_DATA_RECV;
      end
      
      WR_DATA_RECV: begin
        if (wr_handshake_w && wlast)
          wr_state_next = WR_RESP;
        else if (wr_handshake_w)
          wr_state_next = WR_DATA_RECV;
      end
      
      WR_RESP: begin
        if (wr_handshake_b) begin
          if (awvalid && !wr_queue_full)
            wr_state_next = WR_ADDR_RECV;
          else
            wr_state_next = WR_IDLE;
        end
      end
      
      default: wr_state_next = WR_IDLE;
    endcase
  end
 
  
  // Write Channel Control
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      awready <= 1'b0;
      wready  <= 1'b0;
      bvalid  <= 1'b0;
      bid     <= '0;
      bresp   <= RESP_OKAY;
      buser   <= '0;
      
      wr_addr_current  <= '0;
      wr_beat_cnt      <= '0;
      wr_current_id    <= '0;
      wr_current_len   <= '0;
      wr_current_size  <= '0;
      wr_current_burst <= '0;
      wr_current_lock  <= '0;
      wr_start_addr    <= '0;
      wr_error_flag    <= 1'b0;
      
    end else begin
      // Default values
      awready <= 1'b0;
      wready  <= 1'b0;
      
      case (wr_state)
        WR_IDLE: begin
          if (awvalid && !wr_queue_full) begin
            awready <= 1'b1;
          end
          bvalid <= 1'b0;
        end
        
        WR_ADDR_RECV: begin
          awready <= 1'b1;
          if (wr_handshake_aw) begin
            awready          <= 1'b0;
            wready           <= 1'b1;
            wr_current_id    <= awid;
            wr_current_len   <= awlen;
            wr_current_size  <= awsize;
            wr_current_burst <= awburst;
            wr_current_lock  <= awlock;
            wr_start_addr    <= awaddr;
            wr_addr_current  <= awaddr;
            wr_beat_cnt      <= '0;
            wr_error_flag    <= check_transaction_error(awaddr, awlen, awsize, awburst, awlock);
          end
        end
        
        WR_DATA_RECV: begin
          wready <= 1'b1;
          if (wr_handshake_w) begin
            wr_beat_cnt <= wr_beat_cnt + 1;
            wr_addr_current <= calc_next_addr(
              wr_addr_current, wr_start_addr, 
              wr_current_len, wr_current_size, wr_current_burst
            );
            
            // Check if current address is out of range
            if (wr_addr_current >= MEM_SIZE)
              wr_error_flag <= 1'b1;
            
            if (wlast) begin
              wready <= 1'b0;
            end
          end
        end
        
        WR_RESP: begin
          bvalid <= 1'b1;
          bid    <= wr_current_id;
          bresp  <= wr_error_flag ? RESP_SLVERR : RESP_OKAY;
          
          if (wr_handshake_b) begin
            bvalid <= 1'b0;
            wr_error_flag <= 1'b0;
            if (awvalid && !wr_queue_full) begin
              awready <= 1'b1;
            end
          end
        end
      endcase
    end
  end
 
  
  // Memory Write Logic with Strobe Handling
  always_ff @(posedge aclk) begin
    if (wr_state == WR_DATA_RECV && wr_handshake_w && !wr_error_flag) begin
      // Only write if address is within range
      if (wr_addr_current < MEM_SIZE) begin
        // Handle byte strobes
        for (int i = 0; i < STRB_WIDTH; i++) begin
          if (wstrb[i]) begin
            // Calculate actual byte address
            logic [ADDR_WIDTH-1:0] byte_addr;
            byte_addr = (wr_addr_current & ~(STRB_WIDTH-1)) + i;
            if (byte_addr < MEM_SIZE) begin
              mem[byte_addr] <= wdata[i*8 +: 8];
            end
          end
        end
      end
    end
  end
 
  
  // Read State Machine
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      rd_state <= RD_IDLE;
    end else begin
      rd_state <= rd_state_next;
    end
  end
 
  always_comb begin
    rd_state_next = rd_state;
    
    case (rd_state)
      RD_IDLE: begin
        if (arvalid && !rd_queue_full)
          rd_state_next = RD_ADDR_RECV;
      end
      
      RD_ADDR_RECV: begin
        if (rd_handshake_ar)
          rd_state_next = RD_DATA_SEND;
      end
      
      RD_DATA_SEND: begin
        if (rd_handshake_r && rlast) begin
          if (arvalid && !rd_queue_full)
            rd_state_next = RD_ADDR_RECV;
          else
            rd_state_next = RD_IDLE;
        end else if (rd_handshake_r) begin
          rd_state_next = RD_DATA_SEND;
        end else if (rvalid && !rready) begin
          rd_state_next = RD_WAIT_READY;
        end
      end
      
      RD_WAIT_READY: begin
        if (rd_handshake_r) begin
          if (rlast) begin
            if (arvalid && !rd_queue_full)
              rd_state_next = RD_ADDR_RECV;
            else
              rd_state_next = RD_IDLE;
          end else begin
            rd_state_next = RD_DATA_SEND;
          end
        end
      end
      
      default: rd_state_next = RD_IDLE;
    endcase
  end
 
  
  // Read Channel Control
  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      arready <= 1'b0;
      rvalid  <= 1'b0;
      rid     <= '0;
      rdata   <= '0;
      rresp   <= RESP_OKAY;
      rlast   <= 1'b0;
      ruser   <= '0;
      
      rd_addr_current  <= '0;
      rd_beat_cnt      <= '0;
      rd_current_id    <= '0;
      rd_current_len   <= '0;
      rd_current_size  <= '0;
      rd_current_burst <= '0;
      rd_current_lock  <= '0;
      rd_start_addr    <= '0;
      rd_error_flag    <= 1'b0;
      
    end else begin
      // Default values
      arready <= 1'b0;
      
      case (rd_state)
        RD_IDLE: begin
          if (arvalid && !rd_queue_full) begin
            arready <= 1'b1;
          end
          rvalid <= 1'b0;
          rlast  <= 1'b0;
        end
        
        RD_ADDR_RECV: begin
          arready <= 1'b1;
          if (rd_handshake_ar) begin
            arready          <= 1'b0;
            rd_current_id    <= arid;
            rd_current_len   <= arlen;
            rd_current_size  <= arsize;
            rd_current_burst <= arburst;
            rd_current_lock  <= arlock;
            rd_start_addr    <= araddr;
            rd_addr_current  <= araddr;
            rd_beat_cnt      <= '0;
            rd_error_flag    <= check_transaction_error(araddr, arlen, arsize, arburst, arlock);
            
            // Prepare first read data
            rvalid <= 1'b1;
            rid    <= arid;
            rlast  <= (arlen == 0);
            rresp  <= check_transaction_error(araddr, arlen, arsize, arburst, arlock) ? 
                      RESP_SLVERR : RESP_OKAY;
          end
        end
        
        RD_DATA_SEND: begin
          rvalid <= 1'b1;
          rid    <= rd_current_id;
          rresp  <= rd_error_flag ? RESP_SLVERR : RESP_OKAY;
          rlast  <= (rd_beat_cnt == rd_current_len);
          
          if (rd_handshake_r) begin
            rd_beat_cnt <= rd_beat_cnt + 1;
            rd_addr_current <= calc_next_addr(
              rd_addr_current, rd_start_addr,
              rd_current_len, rd_current_size, rd_current_burst
            );
            
            // Check if current address is out of range
            if (rd_addr_current >= MEM_SIZE)
              rd_error_flag <= 1'b1;
            
            if (rlast) begin
              rvalid <= 1'b0;
              rlast  <= 1'b0;
              rd_error_flag <= 1'b0;
              if (arvalid && !rd_queue_full)
                arready <= 1'b1;
            end else begin
              rlast <= ((rd_beat_cnt + 1) == rd_current_len);
            end
          end
        end
        
        RD_WAIT_READY: begin
          // Maintain current outputs while waiting for RREADY
          rvalid <= 1'b1;
          
          if (rd_handshake_r) begin
            rd_beat_cnt <= rd_beat_cnt + 1;
            rd_addr_current <= calc_next_addr(
              rd_addr_current, rd_start_addr,
              rd_current_len, rd_current_size, rd_current_burst
            );
            
            if (rlast) begin
              rvalid <= 1'b0;
              rlast  <= 1'b0;
              rd_error_flag <= 1'b0;
              if (arvalid && !rd_queue_full)
                arready <= 1'b1;
            end else begin
              rlast <= ((rd_beat_cnt + 1) == rd_current_len);
            end
          end
        end
      endcase
    end
  end
 
  
  // Memory Read Logic
  always_ff @(posedge aclk) begin
    if (rd_state == RD_ADDR_RECV && rd_handshake_ar) begin
      // Load first data beat
      for (int i = 0; i < STRB_WIDTH; i++) begin
        logic [ADDR_WIDTH-1:0] byte_addr;
        byte_addr = (araddr & ~(STRB_WIDTH-1)) + i;
        if (byte_addr < MEM_SIZE)
          rdata[i*8 +: 8] <= mem[byte_addr];
        else
          rdata[i*8 +: 8] <= '0;
      end
    end else if ((rd_state == RD_DATA_SEND || rd_state == RD_WAIT_READY) && rd_handshake_r && !rlast) begin
      // Load next data beat
      logic [ADDR_WIDTH-1:0] next_addr;
      next_addr = calc_next_addr(rd_addr_current, rd_start_addr,
                                  rd_current_len, rd_current_size, rd_current_burst);
      for (int i = 0; i < STRB_WIDTH; i++) begin
        logic [ADDR_WIDTH-1:0] byte_addr;
        byte_addr = (next_addr & ~(STRB_WIDTH-1)) + i;
        if (byte_addr < MEM_SIZE)
          rdata[i*8 +: 8] <= mem[byte_addr];
        else
          rdata[i*8 +: 8] <= '0;
      end
    end
  end
 
  
  // Assertions for Protocol Compliance
  `ifdef ASSERTIONS_ON
  
  // Write response must come after all write data
  property bresp_after_wlast;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && wready && wlast) |-> ##[1:$] (bvalid && bready);
  endproperty
  BRESP_AFTER_WLAST: assert property (bresp_after_wlast);
 
  // Read data beats must equal ARLEN + 1
  sequence rd_transaction;
    (arvalid && arready);
  endsequence
 
  // RLAST must be high on final beat
  property rlast_on_final_beat;
    @(posedge aclk) disable iff (!aresetn)
    (rvalid && rready && rlast) |-> (rd_beat_cnt == rd_current_len);
  endproperty
  RLAST_FINAL: assert property (rlast_on_final_beat);
 
  `endif
 
endmodule : axi4_slave_mem_ctrl