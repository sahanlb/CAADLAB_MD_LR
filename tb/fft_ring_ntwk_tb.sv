// ==========================================================================
//
// Original Author: aducimo
// Filename       : fft_ring_ntwk_tb.sv
// Description    : FFT Ring Network
// 
// ==========================================================================

`include "fft_ring_pkg.sv"

module fft_ring_ntwk_tb;
  
  // --------------------------------------------------------------------------
  // Local / Derived Parameters
  //
  localparam [15:0][31:0] NODEID = {32'd15, 32'd14, 32'd13, 32'd12,
                                    32'd11, 32'd10,  32'd9,  32'd8,
                                     32'd7,  32'd6,  32'd5,  32'd4,
                                     32'd3,  32'd2,  32'd1,  32'd0};

  // Source ID 
  localparam [15:0][31:0] FMD_STOP_SRC = { 32'd7,  32'd6,  32'd5,  32'd4,  32'd3,  32'd2,  32'd1,  32'd0, 32'd15, 32'd14, 32'd13, 32'd12, 32'd11, 32'd10,  32'd9,  32'd8};
  localparam [15:0][31:0] FOD_STOP_SRC = { 32'd8,  32'd9, 32'd10, 32'd11,  32'd4,  32'd5,  32'd6,  32'd7,  32'd0,  32'd1,  32'd2,  32'd3, 32'd12, 32'd13, 32'd14, 32'd15};
  localparam [15:0][31:0] RMD_STOP_SRC = { 32'd7,  32'd6,  32'd5,  32'd4,  32'd3,  32'd2,  32'd1,  32'd0, 32'd15, 32'd14, 32'd13, 32'd12, 32'd11, 32'd10,  32'd9,  32'd8};
  localparam [15:0][31:0] ROD_STOP_SRC = { 32'd0,  32'd1,  32'd2,  32'd3, 32'd12, 32'd13, 32'd14, 32'd15,  32'd8,  32'd9, 32'd10, 32'd11,  32'd4,  32'd5,  32'd6,  32'd7};

  // Default Message Types
  localparam [15:0][0:0] FWD_MSG_TYPE_RST = {1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0};
  localparam [15:0][0:0] REV_MSG_TYPE_RST = {1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1};

  localparam [15:0][2:0][31:0] NIDS = {
     32'd8,  32'd7, 32'd0,  
     32'd9,  32'd6, 32'd1,  
    32'd10,  32'd5, 32'd2,  
    32'd11,  32'd4, 32'd3,  
    32'd12,  32'd4, 32'd3,  
    32'd13,  32'd5, 32'd2,  
    32'd14,  32'd6, 32'd1,  
    32'd15,  32'd7, 32'd0,  
    32'd15,  32'd8, 32'd0,  
    32'd14,  32'd9, 32'd1,  
    32'd13, 32'd10, 32'd2,  
    32'd12, 32'd11, 32'd3,  
    32'd12, 32'd11, 32'd4,  
    32'd13, 32'd10, 32'd5,  
    32'd14,  32'd9, 32'd6,  
    32'd15,  32'd8, 32'd7};


  // --------------------------------------------------------------------------
  // Package Imports
  //
  import fft_ring_pkg::*;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar  gii;
  integer iii;

  reg clk;
  reg rstn;
  
  // Messaging Structs
  ts_fft_ring_msg [15:0] rx_msg_f;
  ts_fft_ring_msg [15:0] tx_msg_f;

  ts_fft_ring_msg [15:0] rx_msg_r;
  ts_fft_ring_msg [15:0] tx_msg_r;

  // Pattern Display
  reg [31:0] ccount;
  
  wire [15:0]        f_rx_msg_types;
  wire [15:0] [31:0] f_rx_msg_src_ids;

  wire [15:0]        r_rx_msg_types;
  wire [15:0] [31:0] r_rx_msg_src_ids;

  wire [15:0] [31:0] f_rx_start_source_ids;
  wire [15:0] [31:0] r_rx_start_source_ids;

  wire [15:0]        f_rx_start_msg_types;
  wire [15:0]        r_rx_start_msg_types;

  // --------------------------------------------------------------------------
  // Network
  //
  for (gii=0; gii<16; gii=gii+1) begin
    localparam NXTID = (gii + 32'd1) % 16;
    localparam PRVID = (gii - 32'd1) % 16;

    fft_ring_node #(
      .NNNODES (32'd16),

      .NODEID (NODEID[gii]),

      // Source ID 
      .FMD_STOP_SRC (FMD_STOP_SRC[gii]),
      .FOD_STOP_SRC (FOD_STOP_SRC[gii]),
      .RMD_STOP_SRC (RMD_STOP_SRC[gii]),
      .ROD_STOP_SRC (ROD_STOP_SRC[gii]),

      // Default Message Types
      .FWD_MSG_TYPE_RST (FWD_MSG_TYPE_RST[gii]),
      .REV_MSG_TYPE_RST (REV_MSG_TYPE_RST[gii]),

      .NPBUFFS(32'd2),

      .NIDS(NIDS[gii])
    ) u_fft_ring_node (
      // Clocks and resets
      .clk  (clk),  // (I) Clock
      .rstn (rstn), // (I) Clock

      // Messaging Structs
      .rx_msg_f (rx_msg_f[gii]), // (I) Forward direction message Rx port
      .tx_msg_f (tx_msg_f[gii]), // (O) Forward direction message Tx port

      .rx_msg_r (rx_msg_r[gii]), // (I) Reverse direction message Rx port
      .tx_msg_r (tx_msg_r[gii])  // (O) Reverse direction message Tx port
    );

    assign rx_msg_f[gii] = tx_msg_f[PRVID];
    assign rx_msg_r[gii] = tx_msg_r[NXTID];

    assign f_rx_msg_types[gii]   = rx_msg_f[gii].msg_type;
    assign f_rx_msg_src_ids[gii] = rx_msg_f[gii].src_node_id;

    assign r_rx_msg_types[gii]   = rx_msg_r[gii].msg_type;
    assign r_rx_msg_src_ids[gii] = rx_msg_r[gii].src_node_id;
    
    assign f_rx_start_source_ids[gii] = PRVID;
    assign r_rx_start_source_ids[gii] = NXTID;

    assign f_rx_start_msg_types[gii] = FWD_MSG_TYPE_RST[PRVID];
    assign r_rx_start_msg_types[gii] = REV_MSG_TYPE_RST[NXTID];
  end

  // --------------------------------------------------------------------------
  // Stimulus Generation
  //
  always @(clk) begin : clock_gen
    #5 clk <= ~clk;
  end

  initial begin
    // Initialize clock
    clk = 1'd0;

    // Initialize reset
    rstn = 1'b0;

    #10;
    // De-assert reset
    rstn = 1'b1;

    // Wait for defaults to get transmitted
    #11;

    if ((f_rx_msg_types == f_rx_start_msg_types) &&
        (r_rx_msg_types == r_rx_start_msg_types) &&
        (f_rx_msg_src_ids == f_rx_start_source_ids) &&
        (r_rx_msg_src_ids == r_rx_start_source_ids)) begin
      $display("Pattern repetition detected");
      $finish;
    end
  end

  initial begin
    #81940;
    $display("ERROR TIMEOUT");
    $finish;
  end

  // --------------------------------------------------------------------------
  // Pattern Display
  //
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      ccount <= 32'd0;
    end else begin
      ccount <= ccount + 32'd1;
    end
  end

  always @(negedge clk) begin
    $display("--------------------------------------------------------------------------");
    $display("[%0t] Clock Count: %0d", $time, ccount);
    $display("--------------------------------------------------------------------------");
    
    for (iii=0; iii<16; iii=iii+1) begin
      $display ("Node %0d: Forward Source %02d, Forward Point %0d, Forward Type %0b, Reverse Source %02d, Reverse Point %0d, Reverse Type %0b", iii,
                rx_msg_f[iii].src_node_id, rx_msg_f[iii].fft_pt, rx_msg_f[iii].msg_type,
                rx_msg_r[iii].src_node_id, rx_msg_r[iii].fft_pt, rx_msg_r[iii].msg_type);
    end
  end
endmodule
