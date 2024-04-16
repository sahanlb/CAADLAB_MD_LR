// ==========================================================================
//
// Original Author: aducimo
// Filename       : md_lr_pkg.sv
// Description    : Cadence HAL design info text file.
// 
// ==========================================================================

`ifndef __MD_LR_PKG__
 `define __MD_LR_PKG__

package md_lr_pkg;
  
  typedef enum logic [3:0] {INIT   = 4'h0, // Initialize Grid Memory
                            WAIT   = 4'h1, // Wait for first valid particle data
                            PGMAP  = 4'h2, // Particle-to-Grid Mapping
                            FFTX   = 4'h3, // FFTX
                            FFTY   = 4'h4, // FFTY
                            FFTZNG = 4'h5, // FFTZ and Green's Function
                            IFFTX  = 4'h6, // IFFTX
                            IFFTY  = 4'h7, // IFFTY
                            IFFTZ  = 4'h8, // IFFTZ
                            FCALC  = 4'h9, // Force Transmission
                            RSVDSA = 4'hA, // Reserved
                            RSVDSB = 4'hB, // Reserved
                            RSVDSC = 4'hC, // Reserved
                            RSVDSD = 4'hD, // Reserved
                            RSVDSE = 4'hE, // Reserved
                            RSVDSF = 4'hF  // Reserved
                            } te_md_lr_seqr_state;

endpackage

`endif //  `ifndef __MD_LR_PKG__
  
