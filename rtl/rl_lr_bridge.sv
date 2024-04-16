// ============================================================================
//
// Original Author: Sahan Bandara
// Filename       : rl_lr_bridge.sv
// Description    : Bridge module connecting the input ring of the RL unit to
//                  the LR unit.
// 
// ============================================================================

module rl_lr_bridge (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  rst,    // (I) Active high reset
  clk,    // (I) Clock

  // Ring bus interface
  pready, // (O) Particle Memory ready
  pvalid, // (I) Particle Memory control valid
  paddr,  // (I) Particle Memory address
  pwe,    // (I) Particle Memory write enable
  pwdata, // (I) Particle Memory write data
  plast,  // (I) Last particle data indicator

);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // Number of cells in the RL part.
  parameter TOTCELLS = 32'd64; 

  
  // Read delay timing of particle memory
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] PMRDTYPE = 2'd2;

  // Read delay timing of grid mem blocks
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] GMRDTYPE = 2'd2;


  // --------------------------------------------------------------------------
  // Local / Derived Parameters
  //
  // Width of particle address bus
  localparam PADDRW = $clog2(MAXNUMP);


  // --------------------------------------------------------------------------
  // Package Imports
  //
  import md_lr_pkg::*;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  // Clocks and resets
  input rst;
  input clk;

  // Particle Memory Interface
  output reg              pready;
  input                   pvalid;
  input      [PADDRW-1:0] paddr;
  input                   pwe;
  input      [PDATAW-1:0] pwdata;
  input                   plast;
  

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar gii;
  genvar gjj;
  genvar gkk;

  // --------------------------------------------------------------------------
  // Internal Signals
  //
  // Sequencer State
  te_md_lr_seqr_state md_lr_seqr_state;
  te_md_lr_seqr_state nxt_md_lr_seqr_state;
  te_md_lr_seqr_state md_lr_seqr_state_d1;

  // Particle Memory Interface
  reg                nxt_pready;
  reg                transfer_complete;
  reg                nxt_transfer_complete;


  // --------------------------------------------------------------------------
  // Control FSM
  //
  always @(posedge clk) begin : seqr_seq
  end

  always @* begin : seqr_comb    
  end


  // --------------------------------------------------------------------------
  // Grid memory clear counter
  //
endmodule
