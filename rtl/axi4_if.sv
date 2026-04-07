interface axi4_if #(
  parameter int DATA_WIDTH   = 64,
  parameter int ADDR_WIDTH   = 32,
  parameter int ID_WIDTH     = 4,
  parameter int AWUSER_WIDTH = 1,
  parameter int WUSER_WIDTH  = 1,
  parameter int BUSER_WIDTH  = 1,
  parameter int ARUSER_WIDTH = 1,
  parameter int RUSER_WIDTH  = 1
)(
  input logic aclk,
  input logic aresetn
);
 
  // Derived parameters
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
 

  // Write Address Channel (AW)
  logic [ID_WIDTH-1:0]     awid;
  logic [ADDR_WIDTH-1:0]   awaddr;
  logic [7:0]              awlen;      // Burst length (0 = 1 beat, 255 = 256 beats)
  logic [2:0]              awsize;     // Bytes per transfer (2^awsize)
  logic [1:0]              awburst;    // Burst type
  logic                    awlock;     // Lock type (exclusive access)
  logic [3:0]              awcache;    // Cache type
  logic [2:0]              awprot;     // Protection type
  logic [3:0]              awqos;      // Quality of service
  logic [3:0]              awregion;   // Region identifier
  logic [AWUSER_WIDTH-1:0] awuser;     // User signal
  logic                    awvalid;    // Write address valid
  logic                    awready;    // Write address ready
 
  
  // Write Data Channel (W)
  logic [DATA_WIDTH-1:0]   wdata;      // Write data
  logic [STRB_WIDTH-1:0]   wstrb;      // Write strobes (byte enables)
  logic                    wlast;      // Last write data beat
  logic [WUSER_WIDTH-1:0]  wuser;      // User signal
  logic                    wvalid;     // Write data valid
  logic                    wready;     // Write data ready
 
  // Write Response Channel (B)
  logic [ID_WIDTH-1:0]     bid;        // Response ID
  logic [1:0]              bresp;      // Write response
  logic [BUSER_WIDTH-1:0]  buser;      // User signal
  logic                    bvalid;     // Write response valid
  logic                    bready;     // Write response ready
 
  
  // Read Address Channel (AR)
  logic [ID_WIDTH-1:0]     arid;
  logic [ADDR_WIDTH-1:0]   araddr;
  logic [7:0]              arlen;
  logic [2:0]              arsize;
  logic [1:0]              arburst;
  logic                    arlock;
  logic [3:0]              arcache;
  logic [2:0]              arprot;
  logic [3:0]              arqos;
  logic [3:0]              arregion;
  logic [ARUSER_WIDTH-1:0] aruser;
  logic                    arvalid;
  logic                    arready;
 
  // Read Data Channel (R)
  logic [ID_WIDTH-1:0]     rid;
  logic [DATA_WIDTH-1:0]   rdata;
  logic [1:0]              rresp;
  logic                    rlast;
  logic [RUSER_WIDTH-1:0]  ruser;
  logic                    rvalid;
  logic                    rready;
 
  // Modports
  // Master modport - drives AW, W, AR channels; receives B, R channels
  modport master (
    input  aclk, aresetn,
    // Write Address Channel
    output awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
           awqos, awregion, awuser, awvalid,
    input  awready,
    // Write Data Channel
    output wdata, wstrb, wlast, wuser, wvalid,
    input  wready,
    // Write Response Channel
    input  bid, bresp, buser, bvalid,
    output bready,
    // Read Address Channel
    output arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
           arqos, arregion, aruser, arvalid,
    input  arready,
    // Read Data Channel
    input  rid, rdata, rresp, rlast, ruser, rvalid,
    output rready
  );
 
  // Slave modport - receives AW, W, AR channels; drives B, R channels
  modport slave (
    input  aclk, aresetn,
    // Write Address Channel
    input  awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
           awqos, awregion, awuser, awvalid,
    output awready,
    // Write Data Channel
    input  wdata, wstrb, wlast, wuser, wvalid,
    output wready,
    // Write Response Channel
    output bid, bresp, buser, bvalid,
    input  bready,
    // Read Address Channel
    input  arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
           arqos, arregion, aruser, arvalid,
    output arready,
    // Read Data Channel
    output rid, rdata, rresp, rlast, ruser, rvalid,
    input  rready
  );
 
  // Monitor modport - passive observation
  modport monitor (
    input aclk, aresetn,
    input awid, awaddr, awlen, awsize, awburst, awlock, awcache, awprot,
          awqos, awregion, awuser, awvalid, awready,
    input wdata, wstrb, wlast, wuser, wvalid, wready,
    input bid, bresp, buser, bvalid, bready,
    input arid, araddr, arlen, arsize, arburst, arlock, arcache, arprot,
          arqos, arregion, aruser, arvalid, arready,
    input rid, rdata, rresp, rlast, ruser, rvalid, rready
  );
 

  // Protocol Assertions (for formal verification and debug)
  // Stability assertions: Once VALID is asserted, signals must remain stable
  // until READY is asserted
  
  `ifdef AXI4_ASSERTIONS_ON
 
  // AW channel stability
  property aw_stable_when_valid;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && !awready) |=> ($stable(awid) && $stable(awaddr) && 
                                $stable(awlen) && $stable(awsize) && 
                                $stable(awburst) && $stable(awlock) &&
                                $stable(awcache) && $stable(awprot) &&
                                $stable(awqos) && $stable(awregion) &&
                                $stable(awuser) && awvalid);
  endproperty
  AW_STABLE: assert property (aw_stable_when_valid)
    else $error("AW channel signals changed while AWVALID high and AWREADY low");
 
  // W channel stability
  property w_stable_when_valid;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && !wready) |=> ($stable(wdata) && $stable(wstrb) && 
                              $stable(wlast) && $stable(wuser) && wvalid);
  endproperty
  W_STABLE: assert property (w_stable_when_valid)
    else $error("W channel signals changed while WVALID high and WREADY low");
 
  // AR channel stability
  property ar_stable_when_valid;
    @(posedge aclk) disable iff (!aresetn)
    (arvalid && !arready) |=> ($stable(arid) && $stable(araddr) && 
                                $stable(arlen) && $stable(arsize) && 
                                $stable(arburst) && $stable(arlock) &&
                                $stable(arcache) && $stable(arprot) &&
                                $stable(arqos) && $stable(arregion) &&
                                $stable(aruser) && arvalid);
  endproperty
  AR_STABLE: assert property (ar_stable_when_valid)
    else $error("AR channel signals changed while ARVALID high and ARREADY low");
 
  // B channel stability
  property b_stable_when_valid;
    @(posedge aclk) disable iff (!aresetn)
    (bvalid && !bready) |=> ($stable(bid) && $stable(bresp) && 
                              $stable(buser) && bvalid);
  endproperty
  B_STABLE: assert property (b_stable_when_valid)
    else $error("B channel signals changed while BVALID high and BREADY low");
 
  // R channel stability
  property r_stable_when_valid;
    @(posedge aclk) disable iff (!aresetn)
    (rvalid && !rready) |=> ($stable(rid) && $stable(rdata) && 
                              $stable(rresp) && $stable(rlast) &&
                              $stable(ruser) && rvalid);
  endproperty
  R_STABLE: assert property (r_stable_when_valid)
    else $error("R channel signals changed while RVALID high and RREADY low");
 
  // VALID cannot be deasserted without READY
  property awvalid_deassert;
    @(posedge aclk) disable iff (!aresetn)
    (awvalid && !awready) |=> awvalid;
  endproperty
  AWVALID_HOLD: assert property (awvalid_deassert)
    else $error("AWVALID deasserted without AWREADY");
 
  property wvalid_deassert;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && !wready) |=> wvalid;
  endproperty
  WVALID_HOLD: assert property (wvalid_deassert)
    else $error("WVALID deasserted without WREADY");
 
  property arvalid_deassert;
    @(posedge aclk) disable iff (!aresetn)
    (arvalid && !arready) |=> arvalid;
  endproperty
  ARVALID_HOLD: assert property (arvalid_deassert)
    else $error("ARVALID deasserted without ARREADY");
 
  // WLAST assertion check
  property wlast_on_final_beat;
    @(posedge aclk) disable iff (!aresetn)
    (wvalid && wready && wlast) |-> 1'b1;
  endproperty
 
  // Reset behavior
  property reset_aw_valid;
    @(posedge aclk)
    !aresetn |-> !awvalid;
  endproperty
 
  property reset_w_valid;
    @(posedge aclk)
    !aresetn |-> !wvalid;
  endproperty
 
  property reset_ar_valid;
    @(posedge aclk)
    !aresetn |-> !arvalid;
  endproperty
 
  property reset_b_valid;
    @(posedge aclk)
    !aresetn |-> !bvalid;
  endproperty
 
  property reset_r_valid;
    @(posedge aclk)
    !aresetn |-> !rvalid;
  endproperty
 
  `endif
 

  // Coverage Points
  
  `ifdef AXI4_COVERAGE_ON
 
  covergroup axi4_aw_cg @(posedge aclk iff aresetn);
    option.per_instance = 1;
    
    burst_type: coverpoint awburst {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
    }
    
    burst_size: coverpoint awsize {
      bins size_1b   = {3'b000};
      bins size_2b   = {3'b001};
      bins size_4b   = {3'b010};
      bins size_8b   = {3'b011};
    }
    
    burst_len: coverpoint awlen {
      bins len_1    = {8'd0};
      bins len_2    = {8'd1};
      bins len_4    = {8'd3};
      bins len_8    = {8'd7};
      bins len_16   = {8'd15};
      bins len_32   = {8'd31};
      bins len_64   = {8'd63};
      bins len_128  = {8'd127};
      bins len_256  = {8'd255};
      bins others   = default;
    }
    
    addr_alignment: coverpoint awaddr[2:0] {
      bins aligned   = {3'b000};
      bins unaligned = default;
    }
    
    burst_x_size: cross burst_type, burst_size;
    burst_x_len:  cross burst_type, burst_len;
  endgroup
 
  covergroup axi4_ar_cg @(posedge aclk iff aresetn);
    option.per_instance = 1;
    
    burst_type: coverpoint arburst {
      bins fixed = {2'b00};
      bins incr  = {2'b01};
      bins wrap  = {2'b10};
    }
    
    burst_size: coverpoint arsize {
      bins size_1b   = {3'b000};
      bins size_2b   = {3'b001};
      bins size_4b   = {3'b010};
      bins size_8b   = {3'b011};
    }
    
    burst_len: coverpoint arlen {
      bins len_1    = {8'd0};
      bins len_2    = {8'd1};
      bins len_4    = {8'd3};
      bins len_8    = {8'd7};
      bins len_16   = {8'd15};
      bins len_others = default;
    }
    
    addr_alignment: coverpoint araddr[2:0] {
      bins aligned   = {3'b000};
      bins unaligned = default;
    }
  endgroup
 
  covergroup axi4_strobe_cg @(posedge aclk iff (aresetn && wvalid && wready));
    option.per_instance = 1;
    
    strobe_pattern: coverpoint wstrb {
      bins all_bytes   = {'1};
      bins single_byte = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins narrow_low  = {8'h0F};
      bins narrow_high = {8'hF0};
      bins sparse      = default;
    }
  endgroup
 
  `endif
 
endinterface : axi4_if