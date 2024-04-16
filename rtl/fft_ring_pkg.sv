// ==========================================================================
//
// Original Author: aducimo
// Filename       : fft_ring_pkg.sv
// Description    : FFR Ring Network Package File
// 
// ==========================================================================

`ifndef __FFT_RING_PKG__
 `define __FFT_RING_PKG__

package fft_ring_pkg;
  typedef enum logic {ODST = 1'b0, MDEST = 1'b1} te_fft_ring_msg_len;

  typedef struct packed {
    logic               [31:0] src_node_id;
    logic               [31:0] fft_pt;
    te_fft_ring_msg_len        msg_type;
  } ts_fft_ring_msg;
endpackage

`endif //  `ifndef __FFT_RING_PKG__
