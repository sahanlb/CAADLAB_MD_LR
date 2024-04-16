// ==========================================================================
//
// Original Author: aducimo
// Filename       : fft_ring_node.sv
// Description    : FFT Message Ring Node
// 
// ==========================================================================

`include "fft_ring_pkg.sv"

module fft_ring_node (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  clk,  // (I) Clock
  rstn, // (I) Clock

  // Messaging Structs
  rx_msg_f, // (I) Forward direction message Rx port
  tx_msg_f, // (O) Forward direction message Tx port

  rx_msg_r, // (I) Reverse direction message Rx port
  tx_msg_r  // (O) Reverse direction message Tx port
);

  // --------------------------------------------------------------------------
  // Parameters / Derived Local Parameters
  //
  // Number of network nodes
  parameter [31:0] NNNODES = 32'd16;  

  // Node ID
  parameter [31:0] NODEID = 32'd16;

  // Source ID 
  parameter [31:0] FMD_STOP_SRC = 32'd0;
  parameter [31:0] FOD_STOP_SRC = 32'd0;
  parameter [31:0] RMD_STOP_SRC = 32'd0;
  parameter [31:0] ROD_STOP_SRC = 32'd0;

  // Default Message Types
  parameter [0:0] FWD_MSG_TYPE_RST = 1'b0;
  parameter [0:0] REV_MSG_TYPE_RST = 1'b1;

  // Local message tracking: message type defaults
  localparam [0:0] LCL_FWD_MSG_TYPE_RST = ~FWD_MSG_TYPE_RST;
  localparam [0:0] LCL_REV_MSG_TYPE_RST = ~REV_MSG_TYPE_RST;

  // Number of pointer buffers
  parameter [31:0] NPBUFFS = 32'd2;

  // Depth of point buffers
  localparam [31:0] PDEPTH = $clog2(NNNODES) - 32'd1;
  
  // Node IDs to keep an eye out for
  parameter [PDEPTH-1:0][31:0] NIDS = {PDEPTH{32'd0}};

  // --------------------------------------------------------------------------
  // Package Imports
  //
  import fft_ring_pkg::*;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  // Clocks and resets
  input clk;
  input rstn;

  // Messaging Structs
  input  ts_fft_ring_msg rx_msg_f;
  output ts_fft_ring_msg tx_msg_f;

  input  ts_fft_ring_msg rx_msg_r;
  output ts_fft_ring_msg tx_msg_r;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar  gii;
  integer iii;
  integer ijj;

  // Localized FFT point counts and message types
  reg                 [31:0] lcl_fft_pt_cnt_f;
  reg                 [31:0] nxt_lcl_fft_pt_cnt_f;
  te_fft_ring_msg_len        lcl_msg_type_f;
  te_fft_ring_msg_len        nxt_lcl_msg_type_f;

  reg                 [31:0] lcl_fft_pt_cnt_r;
  reg                 [31:0] nxt_lcl_fft_pt_cnt_r;
  te_fft_ring_msg_len        lcl_msg_type_r;
  te_fft_ring_msg_len        nxt_lcl_msg_type_r;
  
  reg [PDEPTH-1:0][63:0] fft_pt_buff          [NPBUFFS-1:0];
  reg [PDEPTH-1:0]       fft_pt_buff_valid    [NPBUFFS-1:0];
  reg [PDEPTH-1:0][63:0] nxt_fft_pt_buff      [NPBUFFS-1:0];
  reg [PDEPTH-1:0]       nxt_fft_pt_buff_valid[NPBUFFS-1:0];

  // --------------------------------------------------------------------------
  // Localized Message Tracking
  //
  always @(posedge clk) begin : msg_track_f_seq
    if (!rstn) begin
      lcl_fft_pt_cnt_f <= 32'd1;
      lcl_msg_type_f   <= te_fft_ring_msg_len' (LCL_FWD_MSG_TYPE_RST);
    end else begin
      lcl_fft_pt_cnt_f <= nxt_lcl_fft_pt_cnt_f;
      lcl_msg_type_f   <= nxt_lcl_msg_type_f;
    end
  end

  always @* begin : msg_track_f_cmb
    if (rx_msg_f.msg_type == ODST) begin
      if (rx_msg_f.src_node_id == FOD_STOP_SRC) begin
        // Final stop for message
        nxt_lcl_fft_pt_cnt_f = lcl_fft_pt_cnt_f + 32'd1;
        nxt_lcl_msg_type_f   = lcl_msg_type_f.next;
      end else begin
        nxt_lcl_fft_pt_cnt_f = lcl_fft_pt_cnt_f;
        nxt_lcl_msg_type_f   = lcl_msg_type_f;
      end
    end else begin
      if (rx_msg_f.src_node_id == FMD_STOP_SRC) begin
        // Final stop for message
        nxt_lcl_fft_pt_cnt_f = lcl_fft_pt_cnt_f + 32'd1;
        nxt_lcl_msg_type_f   = lcl_msg_type_f.next;
      end else begin
        nxt_lcl_fft_pt_cnt_f = lcl_fft_pt_cnt_f;
        nxt_lcl_msg_type_f   = lcl_msg_type_f;
      end
    end
  end

  always @(posedge clk) begin : msg_track_r_seq
    if (!rstn) begin
      lcl_fft_pt_cnt_r <= 32'd1;
      lcl_msg_type_r   <= te_fft_ring_msg_len'(LCL_REV_MSG_TYPE_RST);
    end else begin
      lcl_fft_pt_cnt_r <= nxt_lcl_fft_pt_cnt_r;
      lcl_msg_type_r   <= nxt_lcl_msg_type_r;
    end
  end

  always @* begin : msg_track_r_cmb
    if (rx_msg_r.msg_type == ODST) begin
      if (rx_msg_r.src_node_id == ROD_STOP_SRC) begin
        // Final stop for message
        nxt_lcl_fft_pt_cnt_r = lcl_fft_pt_cnt_r + 32'd1;
        nxt_lcl_msg_type_r   = lcl_msg_type_r.next;
      end else begin
        nxt_lcl_fft_pt_cnt_r = lcl_fft_pt_cnt_r;
        nxt_lcl_msg_type_r   = lcl_msg_type_r;
      end
    end else begin
      if (rx_msg_r.src_node_id == RMD_STOP_SRC) begin
        // Final stop for message
        nxt_lcl_fft_pt_cnt_r = lcl_fft_pt_cnt_r + 32'd1;
        nxt_lcl_msg_type_r   = lcl_msg_type_r.next;
      end else begin
        nxt_lcl_fft_pt_cnt_r = lcl_fft_pt_cnt_r;
        nxt_lcl_msg_type_r   = lcl_msg_type_r;
      end
    end
  end

  // --------------------------------------------------------------------------
  // Message Tx
  //
  always @(posedge clk) begin : msg_gen_f_seq
    if (!rstn) begin
      tx_msg_f.msg_type    <= te_fft_ring_msg_len'(FWD_MSG_TYPE_RST);
      tx_msg_f.src_node_id <= NODEID;
      tx_msg_f.fft_pt      <= 32'd0;
    end else begin
      if (rx_msg_f.msg_type == ODST) begin
        if (rx_msg_f.src_node_id == FOD_STOP_SRC) begin
          // Final stop for message
          tx_msg_f.msg_type    <= lcl_msg_type_f;
          tx_msg_f.src_node_id <= NODEID;
          tx_msg_f.fft_pt      <= lcl_fft_pt_cnt_f;
        end else begin
          // Forward data from Rx
          tx_msg_f.msg_type    <= rx_msg_f.msg_type;
          tx_msg_f.src_node_id <= rx_msg_f.src_node_id;
          tx_msg_f.fft_pt      <= rx_msg_f.fft_pt;
        end
      end else begin
        if (rx_msg_f.src_node_id == FMD_STOP_SRC) begin
          // Final stop for message
          tx_msg_f.msg_type    <= lcl_msg_type_f;
          tx_msg_f.src_node_id <= NODEID;
          tx_msg_f.fft_pt      <= lcl_fft_pt_cnt_f;
        end else begin
          // Forward data from Rx
          tx_msg_f.msg_type    <= rx_msg_f.msg_type;
          tx_msg_f.src_node_id <= rx_msg_f.src_node_id;
          tx_msg_f.fft_pt      <= rx_msg_f.fft_pt;
        end
      end
    end
  end 

  always @(posedge clk) begin : msg_gen_r_seq
    if (!rstn) begin
      tx_msg_r.msg_type    <= te_fft_ring_msg_len'(REV_MSG_TYPE_RST);
      tx_msg_r.src_node_id <= NODEID;
      tx_msg_r.fft_pt      <= 32'd0;
    end else begin
      if (rx_msg_r.msg_type == ODST) begin
        if (rx_msg_r.src_node_id == ROD_STOP_SRC) begin
          // Final stop for message
          tx_msg_r.msg_type    <= lcl_msg_type_r;
          tx_msg_r.src_node_id <= NODEID;
          tx_msg_r.fft_pt      <= lcl_fft_pt_cnt_r;
        end else begin
          // Forward data from Rx
          tx_msg_r.msg_type    <= rx_msg_r.msg_type;
          tx_msg_r.src_node_id <= rx_msg_r.src_node_id;
          tx_msg_r.fft_pt      <= rx_msg_r.fft_pt;
        end
      end else begin
        if (rx_msg_r.src_node_id == RMD_STOP_SRC) begin
          // Final stop for message
          tx_msg_r.msg_type    <= lcl_msg_type_r;
          tx_msg_r.src_node_id <= NODEID;
          tx_msg_r.fft_pt      <= lcl_fft_pt_cnt_r;
        end else begin
          // Forward data from Rx
          tx_msg_r.msg_type    <= rx_msg_r.msg_type;
          tx_msg_r.src_node_id <= rx_msg_r.src_node_id;
          tx_msg_r.fft_pt      <= rx_msg_r.fft_pt;
        end
      end
    end 
  end

  // --------------------------------------------------------------------------
  // Message Storage
  //
  always @(posedge clk) begin : pt_buff_seq
    if (!rstn) begin
      for (iii=0; iii<NPBUFFS; iii=iii+1) begin
        for (ijj=0; ijj<PDEPTH; ijj=ijj+1) begin
          fft_pt_buff_valid[iii][ijj] <= 1'd0;
          fft_pt_buff      [iii][ijj] <= 64'd0;
        end
      end
    end else begin
      for (iii=0; iii<NPBUFFS; iii=iii+1) begin
        for (ijj=0; ijj<PDEPTH; ijj=ijj+1) begin
          fft_pt_buff_valid[iii][ijj] <= nxt_fft_pt_buff_valid[iii][ijj];
          fft_pt_buff      [iii][ijj] <= nxt_fft_pt_buff      [iii][ijj];
        end
      end
    end
  end

  always @* begin : pt_buff_cmb
    // Defaults
    for (iii=0; iii<NPBUFFS; iii=iii+1) begin
      for (ijj=0; ijj<PDEPTH; ijj=ijj+1) begin
        nxt_fft_pt_buff_valid[iii][ijj] = fft_pt_buff_valid[iii][ijj];
        nxt_fft_pt_buff      [iii][ijj] = fft_pt_buff[iii][ijj];
      end
    end

    for (iii=0; iii<NPBUFFS; iii=iii+1) begin
      if (&fft_pt_buff_valid[iii]) begin
        // Buffer full
        //
        // Clear buffer valids
        for (ijj=0; ijj<PDEPTH; ijj=ijj+1) begin
          nxt_fft_pt_buff_valid[iii][ijj] = 1'd0;
        end
      end
    end

    for (iii=0; iii<PDEPTH; iii=iii+1) begin
      if (rx_msg_f.src_node_id == NIDS[iii]) begin
        // Found a data point for this node in forward direction Rx port
        nxt_fft_pt_buff_valid[rx_msg_f.fft_pt % NPBUFFS][iii] = 1'd1;
        nxt_fft_pt_buff      [rx_msg_f.fft_pt % NPBUFFS][iii] = {rx_msg_f.src_node_id, rx_msg_f.fft_pt};
      end
      if (rx_msg_r.src_node_id == NIDS[iii]) begin
        // Found a data point for this node reverse direction Rx port
        nxt_fft_pt_buff_valid[rx_msg_r.fft_pt % NPBUFFS][iii] = 1'd1;
        nxt_fft_pt_buff      [rx_msg_r.fft_pt % NPBUFFS][iii] = {rx_msg_r.src_node_id, rx_msg_r.fft_pt};
      end
    end
  end

  always @(negedge clk) begin
    for (iii=0; iii<NPBUFFS; iii=iii+1) begin
      if (&fft_pt_buff_valid[iii]) begin
        // Buffer full
        $display("[%0t] Node %0d: Starting FFT %0d", $time, NODEID, fft_pt_buff[iii][0][31:0]);
      end
    end

    for (iii=0; iii<PDEPTH; iii=iii+1) begin
      // Found a data point for this node in forward direction Rx port
      if (rx_msg_f.src_node_id == NIDS[iii]) begin
        // Found a data point for this node in forward direction Rx port
        if (fft_pt_buff_valid[rx_msg_f.fft_pt % NPBUFFS][iii]) begin
          // Buffer already has data in it
          if (!(&fft_pt_buff_valid[rx_msg_f.fft_pt % NPBUFFS])) begin
            // Not all buffers are valid
            #2;
            $display("[%0t] Node %0d: Error Buffer %0d Contention, Line %0d", $time, NODEID, iii, `__LINE__);
            $finish;
          end
        end
      end else begin
        if (rx_msg_r.src_node_id == NIDS[iii]) begin
          // Found a data point for this node reverse direction Rx port
          if (fft_pt_buff_valid[rx_msg_r.fft_pt % NPBUFFS][iii]) begin
            // Buffer already has data in it
            if (!(&fft_pt_buff_valid[rx_msg_r.fft_pt % NPBUFFS])) begin
              // Not all buffers are valid
              #2;
              $display("[%0t] Node %0d: Error Buffer %0d Contention, Line %0d", $time, NODEID, iii, `__LINE__);
              $finish;
            end
          end
        end
      end
    end
  end
endmodule
