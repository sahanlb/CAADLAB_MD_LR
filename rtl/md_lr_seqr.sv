// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : md_lr_seqr.sv
// Description    : MD LR Control Sequencer
// 
// ============================================================================

module md_lr_seqr (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  rst,    // (I) Active high reset
  clk,    // (I) Clock

  // Particle Memory Interface
  pready, // (O) Particle Memory ready
  pvalid, // (I) Particle Memory control valid
  paddr,  // (I) Particle Memory address
  pwe,    // (I) Particle Memory write enable
  pwdata, // (I) Particle Memory write data
  plast,  // (I) Last particle data indicator

  pmem_me,    // (O) Particle memory enable
  pmem_addr,  // (O) Particle memory array address
  pmem_segwe, // (O) Active high memory array entry segment write enable
  pmem_wdata, // (O) Particle memory array entry write data

  // Force Interface
  fready, // (I) Ready
  fvalid, // (O) Valid
  faddr,  // (O) Address
  flast,  // (O) Last force data indicator

  // Charge Mapping
  ccoeff_valid, // (I) Coefficient data validation indicator

  ccoord_valid, // (I) Coordinate information valid
  ccoord_en,    // (I) Coordinate access enable
  ccoordsx,     // (I) Coefficient x-coordinate
  ccoordsy,     // (I) Coefficient y-coordinate
  ccoordsz,     // (I) Coefficient z-coordinate

  // Charge Mapping Accumulators
  accum_real, // (I)
  accum_imag, // (I)

  // Grid Memory Control
  gmem_clr,      // (O) Grid memory clear signal
  gmem_clr_addr, // (O) Grid memory clear address
  gmem_mew,      // (O) Grid Memory write port enable
  gmem_wcoordsx, // (O) Grid Memory write coordinates
  gmem_wcoordsy, // (O) Grid Memory write coordinates
  gmem_wcoordsz, // (O) Grid Memory write coordinates
  gmem_we,       // (O) Grid Memory segment write enable
  gmem_wdata,    // (O) Grid Memory write data

  gmem_mer,      // (O) Grid Memory read port enable
  gmem_rcoordsx, // (O) Grid Memory read coordinates
  gmem_rcoordsy, // (O) Grid Memory read coordinates
  gmem_rcoordsz, // (O) Grid Memory read coordinates
  
  // FFT Array Control / Status
  fft_reset_n,           // (O)
  fft_pts_in,            // (O)
  fft_sink_valid,        // (O)
  fft_sink_sop,          // (O)
  fft_sink_eop,          // (O)
  tplt_fft_source_valid, // (I)
  tplt_fft_source_sop,   // (I)
  fft_source_real,       // (I)
  fft_source_imag,       // (I)

  // Green's Function
  grom_coordsx, // (O) Memory x coordinates
  grom_coordsy, // (O) Memory y coordinates
  grom_coordsz, // (O) Memory z coordinates

  green_real, // (I)
  green_imag, // (I)

  // Force Mapping
  ffpen,        // (O) Floating point enable

  fmap_en,      // (O) Particle data validation indicator

  fcoeff_valid, // (I) Coefficient data validation indicator

  fcoord_valid, // (I) Coordinate information valid
  fcoord_en,    // (I) Coordinate access enable
  fcoordsx,     // (I) Coefficient x-coordinate
  fcoordsy,     // (I) Coefficient y-coordinate
  fcoordsz      // (I) Coefficient z-coordinate
);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // 1D Grid Dimensions
  parameter GSIZE1DX = 32'd32;
  parameter GSIZE1DY = 32'd32;
  parameter GSIZE1DZ = 32'd32;
  
  // Maximum number of particles
  parameter MAXNUMP = 32'd32768;

  // Particle data width
  parameter PDATAW = 32'd128;

  // Number of nearest neighbors along one dimension
  parameter NNN1D = 32'd4;
  
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

  // Latency of floating point addition
  parameter FPADDDEL = 32'd5;

  // Latency of floating point multiplication
  parameter FPMULDEL = 32'd5;

  // Latency of Green's function
  parameter GRNDEL = FPMULDEL + FPADDDEL;

  // Width of floating point values
  parameter FPVW = 32'd32;

  // Maximum number of FFT points that can be processed by FFT IP
  parameter MAXFFTP = 32'd32;

  // --------------------------------------------------------------------------
  // Local / Derived Parameters
  //
  // Width of particle address bus
  localparam PADDRW = $clog2(MAXNUMP);

  // Address width of nearest neighbor in one dimension
  localparam NN1DIDW   = $clog2(NNN1D);
  localparam NN1DIDWM1 = NN1DIDW-32'd1;

  // Address ranges covered by access cluster slices
  localparam ZDXRANGE = GSIZE1DX/NNN1D;
  localparam ZDXRANGEW = $clog2(ZDXRANGE);
  localparam ZDXRANGEWM1 = ZDXRANGEW-1;
  
  // Number of nearest neighbors in 2D
  localparam NNN2D = NNN1D*NNN1D;

  // Width of 1D grid addresses
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);
  
  localparam GADDRW1DXM1 = GADDRW1DX - 32'd1;
  localparam GADDRW1DYM1 = GADDRW1DY - 32'd1;
  localparam GADDRW1DZM1 = GADDRW1DZ - 32'd1;
  
  // Bit width of each grid element
  localparam GELEW = FPVW+FPVW;

  // Particle Memory Readback Latency
  localparam PMRBDEL = (PMRDTYPE == 2'd0) ? 32'd0 :
                       (PMRDTYPE == 2'd1) ? 32'd1 :
                       (PMRDTYPE == 2'd2) ? 32'd1 : 32'd2;

  localparam PMRBDELMSBIT = (PMRBDEL == 32'd0) ? 32'd0 : PMRBDEL - 32'd1;

  // Grid Memory Readback Latency
  //  o Account for readback latency of block RAMs
  //  o Account for 3 stages of piplined control MUXing
  //  o Account for 3 stages of pipelined read data MUXing
  localparam GMRBDEL0 = (GMRDTYPE == 2'd0) ? 32'd0 :
                        (GMRDTYPE == 2'd1) ? 32'd1 :
                        (GMRDTYPE == 2'd2) ? 32'd1 : 32'd2;

  localparam GMRBDEL = GMRBDEL0 + 32'd6;

  localparam GMRBDELM1 = (GMRBDEL == 32'd0) ? 32'd0 : GMRBDEL - 32'd1;

  localparam GMRBDELMSBIT   = (GMRBDEL <= 32'd1) ? 32'd0 : GMRBDEL - 32'd1;
  
  localparam GMRBDELMSBITM1 = (GMRBDELMSBIT == 32'd0) ? 32'd0 : GMRBDELMSBIT - 32'd1;

  // Latency of coefficient accumulation.
  localparam ACCDDEL = FPADDDEL;

  localparam ACCDDELM1 = ACCDDEL - 32'd1;

  // Bit width of accumulator counter
  localparam ACCCNTW = $clog2(ACCDDEL);

  // Number of clock cycles put between each coefficient mapping enable.
  //
  // Write latency from valid coordinate presentation:
  // 1) One clock cycle to generate read coordinates for read data to be
  //    accumulated.
  // 2) 3 stages of piplined control MUXing
  // 3) Readback latency of block RAMs
  // 4) 3 stages of pipelined read data MUXing
  // 5) Latency of accumulation.
  // 6) One clock cycle to generate write coordinates for accumulation result.
  // 7) 3 stages of piplined control MUXing
  // 8) One clock cycle register write in block memory entry
  // 
  // Read latency from valid coordinate presentation:
  // 1) One clock cycle to generate read coordinates for read data to be
  //    accumulated.
  // 2) 3 stages of piplined control MUXing
  localparam MAPENDEL = 32'd1 + GMRBDEL + ACCDDEL + 32'd1 + 32'd3 + 32'd1 - 32'd1 - 32'd3;

  localparam MAPENDELM2 = MAPENDEL - 32'd2;

  // Mapping enable counter width
  localparam MAPENCNTW = $clog2(MAPENDELM2);

  // Force Tree Latency
  localparam FTDEL   = 32'd6*FPADDDEL+FPMULDEL + 32'd1;
  localparam FTDELM1 = FTDEL - 32'd1;

  // Force Tree Counter Width
  localparam FTCNTW = $clog2(FTDEL);
  
  // Width of FFT points control
  localparam FFTPW = $clog2(MAXFFTP);

  // Width of Floating-Point Exponent
  localparam FPEW = (FPVW == 32'd64) ? 32'd11 : 32'd8;
  
  // Width of Floating-Point Mantissa
  localparam FPMW = (FPVW == 32'd64) ? 32'd52 : 32'd23;
  
  // Latency of FFT computation
  //localparam FFTLAT = 32'd77;  /* For 16-point FFT simulation */
  localparam FFTLAT = 32'd75;    /* For 16-point FFT syntesis   */
  //localparam FFTLAT = 32'd132; /* For 32-point FFT simulation */
  //localparam FFTLAT = 32'd130; /* For 32-point FFT synthesis  */
  //localparam FFTLAT = 32'd194; /* For 64-point no hard FP FFT IP simulation */
  //localparam FFTLAT = 32'd192; /* For 64-point no hard FP FFT IP ssynthesis */

  // Maximum value counter for ROM updates can achieve
  // = latency of FFT calculation
  // - latency of clustered grid rom reads
  // - 1 because we assert update valis signal on clock cycle following
  //   counter reaching maximum value allowed
  localparam CNT4ROMMAX = FFTLAT - GMRBDEL - 32'd1;

  // Width of counter for ROM updates
  localparam CNT4ROMW   = $clog2(CNT4ROMMAX);
  localparam CNT4ROMWM1 = CNT4ROMW - 32'd1;

  // Declared as a local parameters in both sequencer and grid memory. Move to 
  // md_lr_pkg later.
  // Grid size in 3D
  localparam GSIZE3D = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Number of nearest neighbors in 3D
  localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // The size of the grid divided by the number of nearest neighbors will serve
  // as the depth of each memory block
  localparam BMEMD = GSIZE3D / NNN3D;

  // Address width of each block of memory
  localparam BADDRW = $clog2(BMEMD);


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
  
  output reg              pmem_me;
  output reg [PADDRW-1:0] pmem_addr;
  output reg              pmem_segwe;
  output reg [PDATAW-1:0] pmem_wdata;

  // Force Interface
  input                   fready;
  output reg              fvalid;
  output reg [PADDRW-1:0] faddr;
  output reg              flast;

  // Particle-to-Grid Generator Control/Status
  input                                                       ccoeff_valid;

  input                                                       ccoord_valid;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                ccoord_en;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] ccoordsx;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] ccoordsy;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] ccoordsz;
 
  // Charge Mapping Accumulators
  input [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] accum_real;
  input [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] accum_imag;

  // Grid Memory Control
  output reg                                                  gmem_clr;
  output reg                                     [BADDRW-1:0] gmem_clr_addr;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_mew;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] gmem_wcoordsx;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] gmem_wcoordsy;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] gmem_wcoordsz;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_we;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]    [GELEW-1:0] gmem_wdata;

  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_mer;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] gmem_rcoordsx;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] gmem_rcoordsy;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] gmem_rcoordsz;
  
  // FFT Array Control / Status
  output reg                                             fft_reset_n;
  output reg                                   [FFTPW:0] fft_pts_in;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_valid;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_sop;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_eop;
  input      [NNN1D-1:0]                                 tplt_fft_source_valid;
  input      [NNN1D-1:0]                                 tplt_fft_source_sop;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_source_real;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_source_imag;

  // Green's Function
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] grom_coordsx;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] grom_coordsy;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] grom_coordsz;

  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] green_real;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] green_imag;

  // Force Coefficient Generator Control
  output reg                                                  ffpen;

  output wire                                                 fmap_en;

  input                                                       fcoeff_valid;

  input                                                       fcoord_valid;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                fcoord_en;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] fcoordsx;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] fcoordsy;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] fcoordsz;

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

  reg                nxt_pmem_me;
  reg   [PADDRW-1:0] nxt_pmem_addr;
  reg                nxt_pmem_segwe;
  reg   [PDATAW-1:0] nxt_pmem_wdata;
  
  // Particle Counter
  reg  [PADDRW-1:0] pcount;
  reg  [PADDRW-1:0] nxt_pcount;

  wire   [PADDRW:0] pcount_plus_one;

  // Delayed ccoeff_valid signal
  reg [2:0] ccoeff_valid_d;

  // Delayed coordinates and enable sigals
  typedef struct packed{
    logic [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                ccoord_en;
    logic [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] ccoordsx;
    logic [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] ccoordsy;
    logic [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] ccoordsz;
  }coords_t;

  coords_t [10:0] delayed_coords;


  // Mapping Counters
  reg [PADDRW:0] mapcountr;
  reg [PADDRW:0] nxt_mapcountr;

  reg [PADDRW:0] mapcountw;
  reg [PADDRW:0] nxt_mapcountw;

  // Particle-to-Grid Generator enable counter
  reg [MAPENCNTW-1:0] nxt_cmapencount;
 
  reg               first_ccoeff_valid_det;
  reg               nxt_first_ccoeff_valid_det;

  // Accumulation Counter
  reg [ACCCNTW-1:0] acccount;
  reg [ACCCNTW-1:0] nxt_acccount;

  wire              max_acccount;
  reg               max_acccount_d1;

  // Force Tree Counter
  reg [FTCNTW-1:0] ftcount;
  reg [FTCNTW-1:0] nxt_ftcount;

  // Grid Memory Control
  reg                                     [BADDRW-1:0] gmem_clr_counter;
  reg                                     [BADDRW-1:0] nxt_gmem_clr_counter;
  reg                                                  nxt_gmem_clr;
  reg                                     [BADDRW-1:0] nxt_gmem_clr_addr;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                nxt_gmem_mew;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] nxt_gmem_wcoordsx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] nxt_gmem_wcoordsy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] nxt_gmem_wcoordsz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                nxt_gmem_we;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]    [GELEW-1:0] nxt_gmem_wdata;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                nxt_gmem_mer;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] nxt_gmem_rcoordsx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] nxt_gmem_rcoordsy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] nxt_gmem_rcoordsz;
  
  // FFT Array Control Status
  reg                                            nxt_fft_reset_n;
  reg                                  [FFTPW:0] nxt_fft_pts_in;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]          nxt_fft_sink_valid;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]          nxt_fft_sink_sop;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]          nxt_fft_sink_eop;

  // Green's Function
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] nxt_grom_coordsx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] nxt_grom_coordsy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] nxt_grom_coordsz;

  // Force Interface
  reg              nxt_fvalid;
  reg [PADDRW-1:0] nxt_faddr;
  reg              nxt_flast;

  // Corfficient Mapping Status
  reg mapping_done;
  reg nxt_mapping_done;
  
  // FFT Input Data Framing
  reg [NNN1D-1:0] tplt_fftc_fstart;

  reg [NNN1D-1:0] tplt_fftc_lastx;
  reg [NNN1D-1:0] tplt_fftc_lasty;
  reg [NNN1D-1:0] tplt_fftc_lastz;

  reg [NNN1D-1:0] tplt_fftr_lastx;
  reg [NNN1D-1:0] tplt_fftr_lasty;
  reg [NNN1D-1:0] tplt_fftr_lastz;

  reg [NNN1D-1:0][GMRBDELMSBITM1:0] tplt_fftc_fstart_d;

  reg [NNN1D-1:0][GMRBDELMSBIT:0] tplt_fftc_lastx_d;
  reg [NNN1D-1:0][GMRBDELMSBIT:0] tplt_fftc_lasty_d;
  reg [NNN1D-1:0][GMRBDELMSBIT:0] tplt_fftc_lastz_d;

  // FFT Output Data Framing
  reg [NNN1D-1:0] tplt_fftw_lastx;
  reg [NNN1D-1:0] tplt_fftw_lasty;
  reg [NNN1D-1:0] tplt_fftw_lastz;

  reg [NNN1D-1:0][GRNDEL-1:0] tplt_fft_vld_src_start_d;

  // End of FFT Detection
  wire last_fftw;
  reg  last_fftw_d1;

  // Charge Coefficient Generator Control
  reg nxt_cmap_en;

  // Green's Function ROM Framing
  reg [NNN1D-1:0] grom_lastx;
  reg [NNN1D-1:0] grom_lasty;
  reg [NNN1D-1:0] grom_lastz;

  reg [CNT4ROMW-1:0] cntr4rom;
  reg [CNT4ROMW-1:0] nxt_cntr4rom;
  reg    [NNN1D-1:0] update_grom_ctrl_tplt;

  // Force Coefficient Generator Control
  wire                  fcalc_pmem_me;
  reg  [PMRBDELMSBIT:0] fcalc_pmem_me_d;

  // Misc. Sequencer Control Logic
  wire last_p_xfer;
  reg  last_p_xfer_d1;

  // --------------------------------------------------------------------------
  // Sequencer FSM
  //
  always @(posedge clk) begin : seqr_seq
    if (rst) begin
      md_lr_seqr_state <= INIT;
    end else begin
      md_lr_seqr_state <= nxt_md_lr_seqr_state;
    end
  end

  always @* begin : seqr_comb    
    case (md_lr_seqr_state)
      INIT: begin
        if(gmem_clr_counter == BMEMD-1)begin
          nxt_md_lr_seqr_state = WAIT;
        end
        else begin
          nxt_md_lr_seqr_state = INIT;
        end
      end
      
      WAIT: begin
        if(pready & pvalid) begin //Receive first particle over particle interface
          nxt_md_lr_seqr_state = PGMAP;
        end
        else begin
          nxt_md_lr_seqr_state = WAIT;
        end
      end

      PGMAP : begin
        // Particle-to-Grid Mapping        
        if (mapping_done) begin
          nxt_md_lr_seqr_state = FFTX;
        end else begin
          nxt_md_lr_seqr_state = PGMAP;
        end
      end

      FFTX : begin
        // FFTX   
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = FFTY;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      FFTY : begin
        // FFTY
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = FFTZNG;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      FFTZNG : begin
        // FFTZ and Green Function
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = IFFTX;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      IFFTX : begin
        // IFFTX
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = IFFTY;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      IFFTY : begin
        // IFFTY        
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = IFFTZ;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      IFFTZ : begin
        // IFFTZ
        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_md_lr_seqr_state = FCALC;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      FCALC : begin 
        // Force Transmission 
        if (flast && fvalid && fready) begin
          // Last force transfer
          nxt_md_lr_seqr_state = INIT;
        end else begin
          nxt_md_lr_seqr_state = md_lr_seqr_state;
        end
      end

      default : begin
        // Shouldn't get here, but do something benign
        nxt_md_lr_seqr_state = md_lr_seqr_state;
      end
    endcase
  end


  // --------------------------------------------------------------------------
  // Grid memory clear counter
  //
  always @(posedge clk) begin : clear_counter_seq
    if(rst)begin
      gmem_clr_counter <= {BADDRW{1'b0}};
    end
    else begin
      gmem_clr_counter <= nxt_gmem_clr_counter;
    end
  end

  always @(*) begin : clear_counter_comb
    case(md_lr_seqr_state)
      INIT:begin
        nxt_gmem_clr_counter = gmem_clr_counter + {{(BADDRW-1){1'b0}}, 1'b1};
      end
      WAIT,PGMAP,FFTX,FFTY,FFTZNG,IFFTX,IFFTY,IFFTZ:begin
        nxt_gmem_clr_counter = gmem_clr_counter;
      end 
      FCALC:begin
        if (flast && fvalid && fready) begin
          // Last force transfer. Go back to INIT state and initialize the grid memory.
          nxt_gmem_clr_counter = {BADDRW{1'b0}};
        end else begin
          nxt_gmem_clr_counter = gmem_clr_counter;
        end
      end
      default:begin
        nxt_gmem_clr_counter <= gmem_clr_counter;
      end
    endcase
  end


  // --------------------------------------------------------------------------
  // Particle Memory Interface
  //
  always @(posedge clk) begin : pready_seq
    if (rst) begin
      pready            <= 1'b0;
      transfer_complete <= 1'b0;
    end else begin
      pready            <= nxt_pready;
      transfer_complete <= nxt_transfer_complete;
    end
  end

  always @* begin : pready_comb    
    case (md_lr_seqr_state)
      INIT   : begin
        nxt_pready            = 1'b0;
        nxt_transfer_complete = 1'b0;
      end
      WAIT   : begin
        nxt_pready            = 1'b1;
        nxt_transfer_complete = 1'b0;
      end
      PGMAP  : begin
        if(transfer_complete)begin
          nxt_pready            = 1'b0;
          nxt_transfer_complete = transfer_complete;
        end
        else begin
          if (last_p_xfer || last_p_xfer_d1) begin
            // No new particle position to be written
            nxt_pready            = 1'b0;
            nxt_transfer_complete = 1'b1;
          end else begin
            // New particle position to be written into particle cache
            nxt_pready            = 1'b1;
            nxt_transfer_complete = transfer_complete;
          end
        end
      end 
      FFTX,FFTY,FFTZNG,IFFTX,IFFTY,IFFTZ,FCALC : begin
        nxt_pready            = 1'b0;
        nxt_transfer_complete = transfer_complete;
      end
      default : begin
        // Shouldn't get here, but do something benign
        nxt_pready            = 1'd0;
        nxt_transfer_complete = 1'b0;
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // Particle Counter:
  // Keep track of number of particles being loaded
  //
  /*********************************
  o pcount is actually the last address of the pmem which has a particle
  o pcount_plus_one is the real particle count. 
  *********************************/

  always @(posedge clk) begin : pcount_seq
    if (rst) begin
      pcount <= {PADDRW{1'd0}};
    end else begin
      pcount <= nxt_pcount;
    end
  end

  always @* begin : pcount_comb
    case (md_lr_seqr_state)
      INIT : nxt_pcount = {PADDRW{1'b0}};
      WAIT : begin
        if(pready && pvalid)begin
          nxt_pcount = pcount_plus_one[PADDRW-1:0];
        end
        else begin
            nxt_pcount = pcount;
        end
      end

      PGMAP : begin
        if (pready && pvalid) begin
          // New particle has been written into particle cache
          if (plast) begin
            // Last particle
            nxt_pcount = pcount;
          end else begin
            nxt_pcount = pcount_plus_one[PADDRW-1:0];
          end
        end else begin
          nxt_pcount = pcount;
        end
      end
    
      FFTX   : nxt_pcount = pcount;
      FFTY   : nxt_pcount = pcount;
      FFTZNG : nxt_pcount = pcount;
      IFFTX  : nxt_pcount = pcount;
      IFFTY  : nxt_pcount = pcount;
      IFFTZ  : nxt_pcount = pcount;     
      FCALC  : begin
        if (flast && fvalid && fready) begin
          nxt_pcount = {PADDRW{1'd0}};
        end else begin
          nxt_pcount = pcount;
        end
      end

      default: nxt_pcount = {PADDRW{1'd0}};
    endcase
  end

  assign pcount_plus_one = pcount + {{(PADDRW-1){1'd0}}, 1'd1};


  // --------------------------------------------------------------------------
  // Delayed ccoeff_valid signal:
  // Used to increment mapcountw
  always @(posedge clk) begin : delayed_coeff_valid_seq
    ccoeff_valid_d[0] <= ccoeff_valid;
    ccoeff_valid_d[1] <= ccoeff_valid_d[0];
    ccoeff_valid_d[2] <= ccoeff_valid_d[1];
  end 

  
  // --------------------------------------------------------------------------
  // Delayed coordinates and enable signals from the coefficient generator
  // Used to set corect write coordinates since the same read coordinates are 
  // not available when setting write coordinates.
  always @(posedge clk) begin : delayed_coordinates_seq
    if(rst)begin
      delayed_coords              <= 0;
    end
    else begin
      delayed_coords[0].ccoord_en <= ccoord_en;
      delayed_coords[0].ccoordsx  <= ccoordsx;
      delayed_coords[0].ccoordsy  <= ccoordsy;
      delayed_coords[0].ccoordsz  <= ccoordsz;
      delayed_coords[1]           <= delayed_coords[0];
      delayed_coords[2]           <= delayed_coords[1];
      delayed_coords[3]           <= delayed_coords[2];
      delayed_coords[4]           <= delayed_coords[3];
      delayed_coords[5]           <= delayed_coords[4];
      delayed_coords[6]           <= delayed_coords[5];
      delayed_coords[7]           <= delayed_coords[6];
      delayed_coords[8]           <= delayed_coords[7];
      delayed_coords[9]           <= delayed_coords[8];
      delayed_coords[10]          <= delayed_coords[9];
    end
  end


  // --------------------------------------------------------------------------
  // Mapping Counter:
  // Keep track of number of particles being mapped
  //
  always @(posedge clk) begin : mapcount_seq
    if (rst) begin
      mapcountw <= {(PADDRW+1){1'd0}};
    end else begin
      mapcountw  <= nxt_mapcountw;
    end
  end

  always @* begin : mapcountw_comb
    case (md_lr_seqr_state)
      INIT : begin
        nxt_mapcountw = {(PADDRW+1){1'd0}};
      end
      WAIT : begin
        nxt_mapcountw = {(PADDRW+1){1'd0}};
      end
      PGMAP : begin
        if (ccoeff_valid_d[2]) begin
          // Accumulation result valid
          nxt_mapcountw = mapcountw + {{PADDRW{1'd0}}, 1'd1};
        end else begin
          nxt_mapcountw = mapcountw;
        end
      end
      FFTX : begin
        nxt_mapcountw = mapcountw;
      end
      FFTY : begin
        nxt_mapcountw = mapcountw;
      end
      FFTZNG : begin
        nxt_mapcountw = mapcountw;
      end
      IFFTX : begin
        nxt_mapcountw = mapcountw;
      end
      IFFTY : begin
        nxt_mapcountw = mapcountw;
      end
      IFFTZ : begin
        nxt_mapcountw = mapcountw; 
      end
      FCALC : begin
        nxt_mapcountw = mapcountw;
      end
      default : begin
        nxt_mapcountw = {(PADDRW+1){1'd0}};
      end
    endcase
  end
  
  // --------------------------------------------------------------------------
  // Particle Memory Control
  //
  always @(posedge clk) begin : pmem_ctrl_seq
    if (rst) begin
      pmem_me    <= 1'd0;
      pmem_addr  <= {PADDRW{1'd0}};
      pmem_segwe <= 1'd0;
      pmem_wdata <= {PDATAW{1'd0}};
    end else begin
      pmem_me    <= nxt_pmem_me;
      pmem_addr  <= nxt_pmem_addr;
      pmem_segwe <= nxt_pmem_segwe;
      pmem_wdata <= nxt_pmem_wdata;
    end
  end

  always @* begin : pmem_ctrl_comb
    case (md_lr_seqr_state)
      INIT : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      WAIT : begin
        if(pvalid && pready)begin
          nxt_pmem_me    = 1'd1;
          nxt_pmem_segwe = pwe;
          nxt_pmem_addr  = paddr;
          nxt_pmem_wdata = pwdata;
        end
        else begin
          nxt_pmem_me    = 1'd0;
          nxt_pmem_segwe = 1'd0;
          nxt_pmem_addr  = pmem_addr;
          nxt_pmem_wdata = pmem_wdata;        
        end
      end
      PGMAP : begin
        if (last_p_xfer_d1) begin
          // New particle position to be written into particle cache
          nxt_pmem_me    = 1'd0;
          nxt_pmem_addr  = {PADDRW{1'd0}};
          nxt_pmem_segwe = 1'd0;
          nxt_pmem_wdata = {PDATAW{1'd0}};
        end else begin
          if (pvalid && pready) begin
            // Valid particle transfer
            nxt_pmem_me    = 1'd1;
            nxt_pmem_segwe = pwe;
            nxt_pmem_addr  = paddr;
            nxt_pmem_wdata = pwdata;        
          end else begin
            nxt_pmem_me    = 1'd0;
            nxt_pmem_segwe = 1'd0;
            nxt_pmem_addr  = pmem_addr;
            nxt_pmem_wdata = pmem_wdata;        
          end
        end
      end
      FFTX : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      FFTY : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      FFTZNG : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      IFFTX : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      IFFTY : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
      IFFTZ : begin
        nxt_pmem_wdata = {PDATAW{1'd0}};
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;

        if (last_fftw && !last_fftw_d1) begin
          // Last FFT write for this direction is taking place
          nxt_pmem_me = 1'd1;
        end else begin
          nxt_pmem_me = 1'd0;
        end
       end
      FCALC : begin
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
        
        if (!fvalid) begin
          // Force information not valid yet. It's still working its way out
          nxt_pmem_me   = 1'd1;
          nxt_pmem_addr = pmem_addr + {{(PADDRW-1){1'd0}}, 1'd1};
        end else begin
          // Force information valid
          if(!fready) begin
            // External not ready for force information
            nxt_pmem_me   = 1'd1;
            nxt_pmem_addr = pmem_addr;
          end else begin
            // External ready for force information
            if (pmem_addr == pcount) begin
              // Last particle memory address has been issued
              nxt_pmem_me   = 1'd0;
              nxt_pmem_addr = pmem_addr;
            end else begin
              // The last particle memory address has not been issued
              nxt_pmem_me   = 1'd1;
              nxt_pmem_addr = pmem_addr + {{(PADDRW-1){1'd0}}, 1'd1};
            end
          end
        end
      end
      default : begin
        nxt_pmem_me    = 1'd0;
        nxt_pmem_addr  = {PADDRW{1'd0}};
        nxt_pmem_segwe = 1'd0;
        nxt_pmem_wdata = {PDATAW{1'd0}};
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // Grid Memory Write Control
  //
  // Address manipulation for FFT and IFFT is the most complex out of all
  // the phases. For FFT and IFFT operations, the block memories that make up
  // the grid memory are grouped into NNN1D tuplets of size NNN2D.
  //
  // Group control in the same manner to coding simplicity


  // Separate state machine for gmem_clear signals
  always @(posedge clk) begin : gmem_clr_seq
    if(rst)begin
      gmem_clr      <= 1'd1;
      gmem_clr_addr <= {BADDRW{1'b0}};
    end
    else begin
      gmem_clr      <= nxt_gmem_clr;
      gmem_clr_addr <= nxt_gmem_clr_addr;
    end
  end

  always @(*) begin : gmem_clr_comb
    case (md_lr_seqr_state)
      INIT : begin
        nxt_gmem_clr      = 1'b1;
        nxt_gmem_clr_addr = gmem_clr_addr + {{(BADDRW-1){1'b0}}, 1'b1}; 
      end
      WAIT,PGMAP,FFTX,FFTY,FFTZNG,IFFTX,IFFTY,IFFTZ,FCALC : begin
        nxt_gmem_clr      = 1'b0;
        nxt_gmem_clr_addr = gmem_clr_addr; 
      end
      default : begin
        // Should never get here! Do something benign
        nxt_gmem_clr                         = 1'b0;
        nxt_gmem_clr_addr                    = gmem_clr_addr; 
      end
    endcase
  end

  // State machines for rest of the gmem signals
  for (gii=0; gii<NNN1D; gii=gii+1) begin : gmw_tuplet
    // Allow for uniqification of zeroth tuplet
    if (gii == 0) begin : zeroth
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;

        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;

        // Per-dimension, port-based start coordinates
        localparam XDXS = 32'd0;
        localparam XDYS = gii*NNN1D+idx2d;
        localparam XDZS = idx3d;

        //localparam YDXS = gii+NNN1D*idx2d;
        localparam YDXS = gii+(GSIZE1DX/NNN1D)*idx2d;
        localparam YDYS = 32'd0;
        localparam YDZS = gii*NNN1D+idx3d;

        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0;

        // During INIT phase particle cache needs to be completely written.
        // Number or particles to be written is > # of grid elements.
        // Rather than have complex logic, use only ione grid memory port to
        // clear out grid memory
        //
        // Allow for uniqification of member (0,0)
        if ((idx2d == 0) && (idx3d == 0)) begin : zero_zero
          always @(posedge clk) begin : ctrl_seq
            if (rst) begin
              gmem_mew     [idx3d][idx2d][gii] <= 1'd0;
              gmem_wcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
              gmem_wcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
              gmem_wcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
              gmem_we      [idx3d][idx2d][gii] <= 1'd0;
              gmem_wdata   [idx3d][idx2d][gii] <= {GELEW{1'd0}};
            end else begin
              gmem_mew     [idx3d][idx2d][gii] <= nxt_gmem_mew     [idx3d][idx2d][gii];
              gmem_wcoordsx[idx3d][idx2d][gii] <= nxt_gmem_wcoordsx[idx3d][idx2d][gii];
              gmem_wcoordsy[idx3d][idx2d][gii] <= nxt_gmem_wcoordsy[idx3d][idx2d][gii];
              gmem_wcoordsz[idx3d][idx2d][gii] <= nxt_gmem_wcoordsz[idx3d][idx2d][gii];
              gmem_we      [idx3d][idx2d][gii] <= nxt_gmem_we      [idx3d][idx2d][gii];
              gmem_wdata   [idx3d][idx2d][gii] <= nxt_gmem_wdata   [idx3d][idx2d][gii];
            end
          end

          always @* begin : ctrl_comb
            case (md_lr_seqr_state)
              INIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
              WAIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
              PGMAP : begin
                if (mapping_done) begin
                  // Last mapping-based write is occuring...
                  //
                  // Stop writing
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;

                  // Prime write addresses for FFTX
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
 
                  // No need to update remainder of controls
                  nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                  
                end else begin
                  // Last mapping-based write is not occuring
                  //
                  // Setup addressing ahead of capturing accumulation result
                  if (ccoeff_valid_d[2]) begin
                    // Valid data begin presented to accumulator
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = delayed_coords[10].ccoordsx[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = delayed_coords[10].ccoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = delayed_coords[10].ccoordsz[idx3d][idx2d][gii];
                  end else begin
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end

                  // Accumulation result capture
                  if (ccoeff_valid_d[2]) begin
                    // Accumulation complete, accumulation result valid 
                    nxt_gmem_mew     [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_we      [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_wdata   [idx3d][idx2d][gii] = {accum_real[idx3d][idx2d][gii],
                                                            accum_imag[idx3d][idx2d][gii]};
                  end else begin
                    // Accumulation incomplete, accumulation result invalid
                    //
                    // Disable writes
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // No need to update remainder of controls
                    nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                  end
                end
              end
              FFTX : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                     fft_source_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for FFTY
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              FFTY : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                     fft_source_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for FFTZNG
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              FFTZNG : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {green_real[idx3d][idx2d][gii],
                                                     green_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_vld_src_start_d[idx3d][GRNDEL-1]) begin
                    // Result of Green's function is valid
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTX
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                    end
                  endcase
                end
              end
              IFFTX : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTY
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              IFFTY : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTZ
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              IFFTZ : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx3d] && tplt_fft_source_valid[idx3d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Hold addresses the same. Reduce complexity of nxt state logic options
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];                        
                      end
                  endcase
                end
              end
              FCALC : begin
                // No writes should happen here
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
              end
              default : begin
                // Should never get here! Do something benign
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
              end
            endcase
          end
        end else begin : non_zero_zero
          always @(posedge clk) begin : ctrl_seq
            if (rst) begin
              gmem_mew     [idx3d][idx2d][gii] <= 1'd0;
              gmem_wcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
              gmem_wcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
              gmem_wcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
              gmem_we      [idx3d][idx2d][gii] <= 1'd0;
              gmem_wdata   [idx3d][idx2d][gii] <= {GELEW{1'd0}};
            end else begin
              gmem_mew     [idx3d][idx2d][gii] <= nxt_gmem_mew     [idx3d][idx2d][gii];
              gmem_wcoordsx[idx3d][idx2d][gii] <= nxt_gmem_wcoordsx[idx3d][idx2d][gii];
              gmem_wcoordsy[idx3d][idx2d][gii] <= nxt_gmem_wcoordsy[idx3d][idx2d][gii];
              gmem_wcoordsz[idx3d][idx2d][gii] <= nxt_gmem_wcoordsz[idx3d][idx2d][gii];
              gmem_we      [idx3d][idx2d][gii] <= nxt_gmem_we      [idx3d][idx2d][gii];
              gmem_wdata   [idx3d][idx2d][gii] <= nxt_gmem_wdata   [idx3d][idx2d][gii];
            end
          end

          always @* begin : ctrl_comb
            case (md_lr_seqr_state)
              INIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
              WAIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
              PGMAP : begin
                if (mapping_done) begin
                  // Last mapping-based write is occuring...
                  //
                  // Stop writing
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;

                  // Prime write addresses for FFTX
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
 
                  // No need to update remainder of controls
                  nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                  
                end else begin
                  // Last mapping-based write is not occuring
                  //
                  // Setup addressing ahead of capturing accumulation result
                  if (ccoeff_valid_d[2]) begin
                    // Valid data begin presented to accumulator
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = delayed_coords[10].ccoordsx[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = delayed_coords[10].ccoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = delayed_coords[10].ccoordsz[idx3d][idx2d][gii];
                  end else begin
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end

                  // Accumulation result capture
                  if (ccoeff_valid_d[2]) begin
                    // Accumulation complete, accumulation result valid 
                    nxt_gmem_mew     [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_we      [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_wdata   [idx3d][idx2d][gii] = {accum_real[idx3d][idx2d][gii],
                                                            accum_imag[idx3d][idx2d][gii]};
                  end else begin
                    // Accumulation incomplete, accumulation result invalid
                    //
                    // Disable writes
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // No need to update remainder of controls
                    nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                  end
                end
              end
              FFTX : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                     fft_source_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for FFTY
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              FFTY : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                     fft_source_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for FFTZNG
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              FFTZNG : begin
                // Always get data from FFT in this state
                nxt_gmem_wdata[idx3d][idx2d][gii] = {green_real[idx3d][idx2d][gii],
                                                     green_imag[idx3d][idx2d][gii]};

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_vld_src_start_d[idx3d][GRNDEL-1]) begin
                    // Result of Green's function is valid
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTX
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                    end
                  endcase
                end
              end
              IFFTX : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTY
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              IFFTY : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Setup write coordinates for IFFTZ
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                    end
                  endcase
                end
              end
              IFFTZ : begin
                // Always get data from FFT in this state
                //
                // Do not divide results. Green's ROM values are already scaled to acommodate
                nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
                
                nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
                nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
                nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

                if (!gmem_mew[idx3d][idx2d][gii]) begin
                  // Memory port has not been enabled yet,
                  // no valid data from FFT to be written
                  //
                  // Hold coordinates steady
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                  if (tplt_fft_source_sop[idx3d] && tplt_fft_source_valid[idx3d]) begin
                    // Valid incoming FFT frame start
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                  end else begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  end
                end else begin
                  // Memory port has been previously enabled,
                  case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                      nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                      
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      // Stop Writing
                      nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                      nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                      
                      // Hold addresses the same. Reduce complexity of nxt state logic options
                      nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];                        
                      end
                  endcase
                end
              end
              FCALC : begin
                // No writes should happen here
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
              end
              default : begin
                // Should never get here! Do something benign
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
              end
            endcase
          end
        end
      end
    end else begin : nth
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;

        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;

        // Per-dimension, port-based start coordinates
        localparam XDXS = 32'd0;
        localparam XDYS = gii*NNN1D+idx2d;
        localparam XDZS = idx3d;

        //localparam YDXS = gii+NNN1D*idx2d;
        localparam YDXS = gii+(GSIZE1DX/NNN1D)*idx2d;
        localparam YDYS = 32'd0;
        localparam YDZS = gii*NNN1D+idx3d;

        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0;

        always @(posedge clk) begin : ctrl_seq
          if (rst) begin
            gmem_mew     [idx3d][idx2d][gii] <= 1'd0;
            gmem_wcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
            gmem_wcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
            gmem_wcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
            gmem_we      [idx3d][idx2d][gii] <= 1'd0;
            gmem_wdata   [idx3d][idx2d][gii] <= {GELEW{1'd0}};
          end else begin
            gmem_mew     [idx3d][idx2d][gii] <= nxt_gmem_mew     [idx3d][idx2d][gii];
            gmem_wcoordsx[idx3d][idx2d][gii] <= nxt_gmem_wcoordsx[idx3d][idx2d][gii];
            gmem_wcoordsy[idx3d][idx2d][gii] <= nxt_gmem_wcoordsy[idx3d][idx2d][gii];
            gmem_wcoordsz[idx3d][idx2d][gii] <= nxt_gmem_wcoordsz[idx3d][idx2d][gii];
            gmem_we      [idx3d][idx2d][gii] <= nxt_gmem_we      [idx3d][idx2d][gii];
            gmem_wdata   [idx3d][idx2d][gii] <= nxt_gmem_wdata   [idx3d][idx2d][gii];
          end
        end

        always @* begin : ctrl_comb
          case (md_lr_seqr_state)
              INIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
              WAIT : begin
                nxt_gmem_mew     [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                nxt_gmem_we      [idx3d][idx2d][gii] = 1'b0;
                nxt_gmem_wdata   [idx3d][idx2d][gii] = {GELEW{1'd0}};
              end
            PGMAP : begin
              if (mapping_done) begin
                // Last mapping-based write is occuring...
                //
                // Stop writing
                nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                
                // Prime write addresses for FFTX
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                
                // No need to update remainder of controls
                nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                  
              end else begin
                // Last mapping-based write is not occuring
                //
                // Setup addressing ahead of capturing accumulation result
                if (ccoeff_valid_d[2]) begin
                  // Valid data begin presented to accumulator
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = delayed_coords[10].ccoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = delayed_coords[10].ccoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = delayed_coords[10].ccoordsz[idx3d][idx2d][gii]; 
                end else begin
                  nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                end

                // Accumulation result capture
                if (ccoeff_valid_d[2]) begin
                  // Accumulation complete, accumulation result valid 
                  nxt_gmem_mew     [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                  nxt_gmem_we      [idx3d][idx2d][gii] = delayed_coords[10].ccoord_en[idx3d][idx2d][gii];
                  nxt_gmem_wdata   [idx3d][idx2d][gii] = {accum_real[idx3d][idx2d][gii],
                                                          accum_imag[idx3d][idx2d][gii]};
                end else begin
                  // Accumulation incomplete, accumulation result invalid
                  //
                  // Disable writes
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                  
                  // No need to update remainder of controls
                  nxt_gmem_wdata[idx3d][idx2d][gii] = gmem_wdata[idx3d][idx2d][gii];
                end
              end
            end
            FFTX : begin
              // Always get data from FFT in this state
              nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                   fft_source_imag[idx3d][idx2d][gii]};

              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                  // Valid incoming FFT frame start
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Setup write coordinates for FFTY
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                  end
                endcase
              end
            end
            FFTY : begin
              // Always get data from FFT in this state
              nxt_gmem_wdata[idx3d][idx2d][gii] = {fft_source_real[idx3d][idx2d][gii],
                                                   fft_source_imag[idx3d][idx2d][gii]};

              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                  // Valid incoming FFT frame start
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Setup write coordinates for FFTZNG
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                  end
                endcase
              end
            end
            FFTZNG : begin
              // Always get data from FFT in this state
              nxt_gmem_wdata[idx3d][idx2d][gii] = {green_real[idx3d][idx2d][gii],
                                                   green_imag[idx3d][idx2d][gii]};

              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_vld_src_start_d[idx3d][GRNDEL-1]) begin
                  // Result of Green's function is valid
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Setup write coordinates for IFFTX
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                  end
                endcase
              end
            end
            IFFTX : begin
              // Always get data from FFT in this state
              nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
              
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa
              
              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_source_sop[gii] && tplt_fft_source_valid[gii]) begin
                  // Valid incoming FFT frame start
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lastx[gii], tplt_fftw_lasty[gii], tplt_fftw_lastz[gii]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Setup write coordinates for IFFTY
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                  end
                endcase
              end
            end
            IFFTY : begin
              // Always get data from FFT in this state
              //
              // Do not divide results. Green's ROM values are already scaled to acommodate
              nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
              
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_source_sop[idx2d] && tplt_fft_source_valid[idx2d]) begin
                  // Valid incoming FFT frame start
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lasty[idx2d], tplt_fftw_lastz[idx2d], tplt_fftw_lastx[idx2d]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Setup write coordinates for IFFTZ
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                  end
                endcase
              end
            end
            IFFTZ : begin
              // Always get data from FFT in this state
              //
              // Do not divide results. Green's ROM values are already scaled to acommodate
              nxt_gmem_wdata[idx3d][idx2d][gii][GELEW-1]         = fft_source_real[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+FPMW+:FPEW] = fft_source_real[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW+:FPMW]      = fft_source_real[idx3d][idx2d][gii][0+:FPMW];    // mantissa
              
              nxt_gmem_wdata[idx3d][idx2d][gii][FPVW-1]     = fft_source_imag[idx3d][idx2d][gii][FPVW-1];     // sign
              nxt_gmem_wdata[idx3d][idx2d][gii][FPMW+:FPEW] = fft_source_imag[idx3d][idx2d][gii][FPMW+:FPEW]; // exponent
              nxt_gmem_wdata[idx3d][idx2d][gii][0+:FPMW]    = fft_source_imag[idx3d][idx2d][gii][0+:FPMW];    // mantissa

              if (!gmem_mew[idx3d][idx2d][gii]) begin
                // Memory port has not been enabled yet,
                // no valid data from FFT to be written
                //
                // Hold coordinates steady
                nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];

                if (tplt_fft_source_sop[idx3d] && tplt_fft_source_valid[idx3d]) begin
                  // Valid incoming FFT frame start
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd1;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                end
              end else begin
                // Memory port has been previously enabled,
                case ({tplt_fftw_lastz[idx3d], tplt_fftw_lasty[idx3d], tplt_fftw_lastx[idx3d]})
                  3'b000 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mew[idx3d][idx2d][gii] = gmem_mew[idx3d][idx2d][gii];
                    nxt_gmem_we [idx3d][idx2d][gii] = gmem_we [idx3d][idx2d][gii];
                    
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_wcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_wcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    // Stop Writing
                    nxt_gmem_mew[idx3d][idx2d][gii] = 1'd0;
                    nxt_gmem_we [idx3d][idx2d][gii] = 1'd0;
                    
                    // Hold addresses the same. Reduce complexity of nxt state logic options
                    nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];                        
                    end
                endcase
              end
            end
            FCALC : begin
              // No writes should happen here
              nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
              nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
              nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
              nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
            end
            default : begin
              // Should never get here! Do something benign
              nxt_gmem_mew     [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_we      [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_wcoordsx[idx3d][idx2d][gii] = gmem_wcoordsx[idx3d][idx2d][gii];
              nxt_gmem_wcoordsy[idx3d][idx2d][gii] = gmem_wcoordsy[idx3d][idx2d][gii];
              nxt_gmem_wcoordsz[idx3d][idx2d][gii] = gmem_wcoordsz[idx3d][idx2d][gii];
              nxt_gmem_wdata   [idx3d][idx2d][gii] = gmem_wdata   [idx3d][idx2d][gii];
            end
          endcase
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Grid Memory Read Control
  //
  // Address manipulation for FFT and IFFT is the most complex out of all
  // the phases. For FFT and IFFT operations, the block memories that make up
  // the grid memory are grouped into NNN1D tuplets of size NNN2D.
  //
  // Group control in the same manner to coding simplicity

  /****************************************************************************
  o Changes to PGMAP is simple.
    - Set sigals based on mapping done and ccoord_valid as done  now.
  ****************************************************************************/

  for (gii=0; gii<NNN1D; gii=gii+1) begin : gmr_tuplet
    localparam giim1 = (gii == 32'd0) ? 32'd0 : gii - 32'd1;
    
    // Allow for uniqification of zeroth tuplet
    if (gii == 0) begin : zeroth
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;

        localparam idx2dm1 = (idx2d == 32'd0) ? 32'd0 : idx2d - 32'd1;
        
        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;
        
        localparam idx3dm1 = (idx3d == 32'd0) ? 32'd0 : idx3d - 32'd1;

        // Per-dimension, port-based start coordinates
        localparam XDXS = 32'd0;
        localparam XDYS = gii*NNN1D+idx2d;
        localparam XDZS = idx3d;

        //localparam YDXS = gii+NNN1D*idx2d;
        localparam YDXS = gii+(GSIZE1DX/NNN1D)*idx2d;
        localparam YDYS = 32'd0;
        localparam YDZS = gii*NNN1D+idx3d;

        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0;

        // Allow for uniqification of member (0,0)
        if ((idx2d == 0) && (idx3d == 0)) begin : zero_zero
          always @(posedge clk) begin : ctrl_seq
            if (rst) begin
              gmem_mer     [idx3d][idx2d][gii] <= 1'd0;
              gmem_rcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
              gmem_rcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
              gmem_rcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
            end else begin
              gmem_mer     [idx3d][idx2d][gii] <= nxt_gmem_mer     [idx3d][idx2d][gii];
              gmem_rcoordsx[idx3d][idx2d][gii] <= nxt_gmem_rcoordsx[idx3d][idx2d][gii];
              gmem_rcoordsy[idx3d][idx2d][gii] <= nxt_gmem_rcoordsy[idx3d][idx2d][gii];
              gmem_rcoordsz[idx3d][idx2d][gii] <= nxt_gmem_rcoordsz[idx3d][idx2d][gii];
            end
          end

          always @* begin : ctrl_comb
            case (md_lr_seqr_state)
              INIT : begin
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
              WAIT : begin
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
              PGMAP : begin
                if (mapping_done) begin
                  // Last mapping-based write is occuring...
                  //
                  // Setup read controls for FFTX
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (gii == 32'd0);
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                end else begin
                  // Last mapping-based write is not occuring
                  if (ccoord_valid) begin
                    // Information out of coefficient generator is valid
                    //
                    nxt_gmem_mer     [idx3d][idx2d][gii] = ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ccoordsx [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ccoordsy [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ccoordsz [idx3d][idx2d][gii];
                  end else begin
                    // Information out of coefficient generator is invalid
                    //
                    // Hold read controls for the sake of forwarding
                    // information to the write controls
                    //nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                    nxt_gmem_mer     [idx3d][idx2d][gii] = 1'b0;
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                end
              end
              FFTX : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTY
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                  endcase
                end
              end
              FFTY : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTZNG
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                  endcase
                end
              end
              FFTZNG : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for IFFTX
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (gii == 32'd0);
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                end else begin
                  case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                   end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                  endcase
                end
              end
              IFFTX: begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTY/IFFTY
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                  endcase
                end
              end
              IFFTY : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTZNG/IFFTZ
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                  endcase
                end
              end
              IFFTZ : begin
                // Needs to be unique because next state is a non FFT state
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for Force
                  nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}}; 
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
                end else begin
                  case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                  endcase
                end
              end
              FCALC : begin
                if (fvalid && fready && flast) begin
                  // Last forcce transfer
                  //
                  // Disable memory write ports
                  nxt_gmem_mer[idx3d][idx2d][gii] = 1'd0;
                  
                  // Zero out address
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}};
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
                end else begin
                  // Not the last force transfer
                  if (fcoord_valid) begin
                    // Information out of coefficient generator is valid
                    if (fvalid && !fready) begin
                      // Force calculation pipeline stalled
                      nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end else begin
                      // Force calculation pipeline not stalled
                      //
                      // Enable read port
                      nxt_gmem_mer[idx3d][idx2d][gii] = fcoord_en[idx3d][idx2d][gii];

                      // Use coordinates from coefficient generator to perform read
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = fcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = fcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = fcoordsz[idx3d][idx2d][gii];
                    end
                  end else begin
                    // Information out of coefficient generator is invalid
                    //
                    nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                end
              end
              default : begin
                // Should never get here! Do something benign
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
            endcase
          end
        end else begin : non_zero_zero
          always @(posedge clk) begin : ctrl_seq
            if (rst) begin
              gmem_mer     [idx3d][idx2d][gii] <= 1'd0;
              gmem_rcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
              gmem_rcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
              gmem_rcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
            end else begin
              gmem_mer     [idx3d][idx2d][gii] <= nxt_gmem_mer     [idx3d][idx2d][gii];
              gmem_rcoordsx[idx3d][idx2d][gii] <= nxt_gmem_rcoordsx[idx3d][idx2d][gii];
              gmem_rcoordsy[idx3d][idx2d][gii] <= nxt_gmem_rcoordsy[idx3d][idx2d][gii];
              gmem_rcoordsz[idx3d][idx2d][gii] <= nxt_gmem_rcoordsz[idx3d][idx2d][gii];
            end
          end

          always @* begin : ctrl_comb
            case (md_lr_seqr_state)
              INIT : begin
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
              WAIT : begin
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
              PGMAP : begin
                if (mapping_done) begin
                  // Last mapping-based write is occuring...
                  //
                  // Setup read controls for FFTX
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (gii == 32'd0);
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                end else begin
                  // Last mapping-based write is not occuring
                  if (ccoord_valid) begin
                    // Information out of coefficient generator is valid
                    //
                    nxt_gmem_mer     [idx3d][idx2d][gii] = ccoord_en[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ccoordsx [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ccoordsy [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ccoordsz [idx3d][idx2d][gii];
                  end else begin
                    // Information out of coefficient generator is invalid
                    //
                    // Hold read controls for the sake of forwarding
                    // information to the write controls
                    //nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                    nxt_gmem_mer     [idx3d][idx2d][gii] = 1'b0;
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                end
              end
              FFTX : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTY
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                  endcase
                end
              end
              FFTY : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTZNG
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                  endcase
                end
              end
              FFTZNG : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for IFFTX
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (gii == 32'd0);
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
                end else begin
                  case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                  endcase
                end
              end
              IFFTX: begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTY/IFFTY
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                    end
                  endcase
                end
              end
              IFFTY : begin
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for FFTZNG/IFFTZ
                  nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
                end else begin
                  case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end
                  endcase
                end
              end
              IFFTZ : begin
                // Needs to be unique because next state is a non FFT state
                if (last_fftw && !last_fftw_d1) begin
                  // Last FFT write for this direction is taking place
                  //
                  // Setup read controls for Force
                  nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}}; 
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
                end else begin
                  case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                    3'b000 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b001 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b010 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b011 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b100 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b101 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    3'b110 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                    3'b111 : begin
                      nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                      if (gmem_mer[idx3d][idx2d][gii]) begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                      end else begin
                        nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                      end

                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                    end
                  endcase
                end
              end
              FCALC : begin
                if (fvalid && fready && flast) begin
                  // Last forcce transfer
                  //
                  // Disable memory write ports
                  nxt_gmem_mer[idx3d][idx2d][gii] = 1'd0;
                  
                  // Zero out address
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}};
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
                end else begin
                  // Not the last force transfer
                  if (fcoord_valid) begin
                    // Information out of coefficient generator is valid
                    if (fvalid && !fready) begin
                      // Force calculation pipeline stalled
                      nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end else begin
                      // Force calculation pipeline not stalled
                      //
                      // Enable read port
                      nxt_gmem_mer[idx3d][idx2d][gii] = fcoord_en[idx3d][idx2d][gii];

                      // Use coordinates from coefficient generator to perform read
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = fcoordsx[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = fcoordsy[idx3d][idx2d][gii];
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = fcoordsz[idx3d][idx2d][gii];
                    end
                  end else begin
                    // Information out of coefficient generator is invalid
                    //
                    nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                end
              end
              default : begin
                // Should never get here! Do something benign
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
              end
            endcase
          end
        end
      end
    end else begin : nth
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;

        localparam idx2dm1 = (idx2d == 32'd0) ? 32'd0 : idx2d - 32'd1;
        
        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;

        localparam idx3dm1 = (idx3d == 32'd0) ? 32'd0 : idx3d - 32'd1;

        // Per-dimension, port-based start coordinates
        localparam XDXS = 32'd0;
        localparam XDYS = gii*NNN1D+idx2d;
        localparam XDZS = idx3d;

        //localparam YDXS = gii+NNN1D*idx2d;
        localparam YDXS = gii+(GSIZE1DX/NNN1D)*idx2d;
        localparam YDYS = 32'd0;
        localparam YDZS = gii*NNN1D+idx3d;

        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0;
        
        always @(posedge clk) begin : ctrl_seq
          if (rst) begin
            gmem_mer     [idx3d][idx2d][gii] <= 1'd0;
            gmem_rcoordsx[idx3d][idx2d][gii] <= {GADDRW1DX{1'd0}};
            gmem_rcoordsy[idx3d][idx2d][gii] <= {GADDRW1DY{1'd0}};
            gmem_rcoordsz[idx3d][idx2d][gii] <= {GADDRW1DZ{1'd0}};
          end else begin
            gmem_mer     [idx3d][idx2d][gii] <= nxt_gmem_mer     [idx3d][idx2d][gii];
            gmem_rcoordsx[idx3d][idx2d][gii] <= nxt_gmem_rcoordsx[idx3d][idx2d][gii];
            gmem_rcoordsy[idx3d][idx2d][gii] <= nxt_gmem_rcoordsy[idx3d][idx2d][gii];
            gmem_rcoordsz[idx3d][idx2d][gii] <= nxt_gmem_rcoordsz[idx3d][idx2d][gii];
          end
        end

        always @* begin : ctrl_comb
          case (md_lr_seqr_state)
            INIT : begin
              nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
              nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
              nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
            end
            WAIT : begin
              nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
              nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
              nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
            end
            PGMAP : begin
              if (mapping_done) begin
                // Last mapping-based write is occuring...
                //
                // Setup read controls for FFTX
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
              end else begin
                // Last mapping-based write is not occuring
                if (ccoord_valid) begin
                  // Information out of coefficient generator is valid
                  //
                  nxt_gmem_mer     [idx3d][idx2d][gii] = ccoord_en[idx3d][idx2d][gii];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ccoordsx [idx3d][idx2d][gii];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ccoordsy [idx3d][idx2d][gii];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ccoordsz [idx3d][idx2d][gii];
                end else begin
                  // Information out of coefficient generator is invalid
                  //
                  // Hold read controls for the sake of forwarding
                  // information to the write controls
                  //nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                  nxt_gmem_mer     [idx3d][idx2d][gii] = 1'b0;
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                end
              end
            end
            FFTX : begin
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for FFTY
                nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
              end else begin
                case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];
                    
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];
                    
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                endcase
              end
            end
            FFTY : begin
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for FFTZNG
                nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
              end else begin
                case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {{GADDRW1DYM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                endcase
              end
            end
            FFTZNG : begin
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for IFFTX
                nxt_gmem_mer     [idx3d][idx2d][gii] = (gii == 32'd0);
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = XDXS[GADDRW1DX-1:0];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = XDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = XDZS[GADDRW1DZ-1:0];
              end else begin
                case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];
 
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end
            end
            IFFTX: begin
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for FFTY/IFFTY
                nxt_gmem_mer     [idx3d][idx2d][gii] = (idx2d == 32'd0);
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = YDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = YDZS[GADDRW1DZ-1:0];
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = YDXS[GADDRW1DX-1:0];
              end else begin
                case ({tplt_fftr_lastx[gii], tplt_fftr_lasty[gii], tplt_fftr_lastz[gii]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];
                    
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];
                    
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end
                    
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][giim1];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {GADDRW1DX{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN1D[GADDRW1DZM1:0];
                  end
                endcase
              end
            end
            IFFTY : begin
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for FFTZNG/IFFTZ
                nxt_gmem_mer     [idx3d][idx2d][gii] = (idx3d == 32'd0);
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
              end else begin
                case ({tplt_fftr_lasty[idx2d], tplt_fftr_lastz[idx2d], tplt_fftr_lastx[idx2d]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2dm1][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + {GADDRW1DY{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + NNN2D[GADDRW1DZM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii] + {{GADDRW1DXM1{1'd0}}, 1'd1};
                  end
                endcase
              end
            end
            IFFTZ : begin
              // Needs to be unique because next state is a non FFT state
              if (last_fftw && !last_fftw_d1) begin
                // Last FFT write for this direction is taking place
                //
                // Setup read controls for Force
                nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}}; 
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
              end else begin
                case ({tplt_fftr_lastz[idx3d], tplt_fftr_lasty[idx3d], tplt_fftr_lastx[idx3d]})
                  3'b000 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3dm1][idx2d][gii];

                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_gmem_mer[idx3d][idx2d][gii] = gmem_mer[idx3d][idx2d][gii];
 
                    if (gmem_mer[idx3d][idx2d][gii]) begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii] + {GADDRW1DZ{1'd1}};
                    end else begin
                      nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                    end

                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = gmem_rcoordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0]         = gmem_rcoordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end
            end
            FCALC : begin
              if (fvalid && fready && flast) begin
                // Last forcce transfer
                //
                // Disable memory write ports
                nxt_gmem_mer[idx3d][idx2d][gii] = 1'd0;
                
                // Zero out address
                nxt_gmem_rcoordsx[idx3d][idx2d][gii] = {GADDRW1DX{1'd0}};
                nxt_gmem_rcoordsy[idx3d][idx2d][gii] = {GADDRW1DY{1'd0}};
                nxt_gmem_rcoordsz[idx3d][idx2d][gii] = {GADDRW1DZ{1'd0}};
              end else begin
                // Not the last force transfer
                if (fcoord_valid) begin
                  // Information out of coefficient generator is valid
                  if (fvalid && !fready) begin
                    // Force calculation pipeline stalled
                    nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                  end else begin
                    // Force calculation pipeline not stalled
                    //
                    // Enable read port
                    nxt_gmem_mer[idx3d][idx2d][gii] = fcoord_en[idx3d][idx2d][gii];
                  
                    // Use coordinates from coefficient generator to perform read
                    nxt_gmem_rcoordsx[idx3d][idx2d][gii] = fcoordsx[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsy[idx3d][idx2d][gii] = fcoordsy[idx3d][idx2d][gii];
                    nxt_gmem_rcoordsz[idx3d][idx2d][gii] = fcoordsz[idx3d][idx2d][gii];
                  end
                end else begin
                  // Information out of coefficient generator is invalid
                  //
                  nxt_gmem_mer     [idx3d][idx2d][gii] = gmem_mer     [idx3d][idx2d][gii];
                  nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
                  nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
                  nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
                end
              end
            end
            default : begin
              // Should never get here! Do something benign
              nxt_gmem_mer     [idx3d][idx2d][gii] = 1'd0;
              nxt_gmem_rcoordsx[idx3d][idx2d][gii] = gmem_rcoordsx[idx3d][idx2d][gii];
              nxt_gmem_rcoordsy[idx3d][idx2d][gii] = gmem_rcoordsy[idx3d][idx2d][gii];
              nxt_gmem_rcoordsz[idx3d][idx2d][gii] = gmem_rcoordsz[idx3d][idx2d][gii];
            end
          endcase
        end
      end
    end
  end
  
  // --------------------------------------------------------------------------
  // FFT Array Control
  //
  // Address manipulation for FFT and IFFT is the most complex out of all
  // the phases. For FFT and IFFT operations, the block memories that make up
  // the grid memory are grouped into NNN1D tuplets of size NNN2D.
  //
  // Group control in the same manner to coding simplicity

  for (gii=0; gii<NNN1D; gii=gii+1) begin : fft_tuplet
    for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
      // Create index for 2nd dimension
      localparam idx2d = gjj >> NN1DIDW;

      localparam idx2dm1 = (idx2d == 32'd0) ? 32'd0 : idx2d - 32'd1;
        
      // Create index for 3rd dimension
      localparam idx3d = gjj % NNN1D;
      
      localparam idx3dm1 = (idx3d == 32'd0) ? 32'd0 : idx3d - 32'd1;
      
      always @(posedge clk) begin : ctrl_seq
        if (rst) begin
          fft_sink_valid[idx3d][idx2d][gii] <= 1'd0;
          fft_sink_sop  [idx3d][idx2d][gii] <= 1'd0;
          fft_sink_eop  [idx3d][idx2d][gii] <= 1'd0;
        end else begin
          fft_sink_valid[idx3d][idx2d][gii] <= nxt_fft_sink_valid[idx3d][idx2d][gii];
          fft_sink_sop  [idx3d][idx2d][gii] <= nxt_fft_sink_sop  [idx3d][idx2d][gii];
          fft_sink_eop  [idx3d][idx2d][gii] <= nxt_fft_sink_eop  [idx3d][idx2d][gii];
        end
      end
  
      always @* begin : ctrl_comb
        case (md_lr_seqr_state)
          INIT : begin
            nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_sop  [idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_eop  [idx3d][idx2d][gii] = 1'd0;
          end
          PGMAP : begin
            nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_sop  [idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_eop  [idx3d][idx2d][gii] = 1'd0;
          end
          FFTX, IFFTX: begin
            // Valid should stay valid until last FFT data from tuplet0
            // is presented to FFT blocks
            //
            if (!fft_sink_valid[idx3d][idx2d][gii]) begin
              // Not previously valid
              if (tplt_fftc_fstart_d[gii][GMRBDELMSBITM1]) begin
                // FFT data is valid in this clock cycle
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
              end else begin
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end
            end else begin
              // Previous valid detected
              //
              // Need to keep fft_sink_valid in order for tplt_fft_source_valid to
              // remain valid
              if (last_fftw && !last_fftw_d1) begin
                // Last write in this FFT stage
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
                  // Last write for this tuplet in this dimension
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
                end else begin
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
                end
              end
            end

            // Use delayed frame start to create SOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_fstart_d[gii][GMRBDELMSBITM1]) begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
                end
              end
            end

            // Use delayed lastx to create EOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_lastx_d[gii][GMRBDELMSBITM1] && !tplt_fftc_lastx_d[gii][GMRBDELMSBIT]) begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
                end
              end
            end
          end
          FFTY, IFFTY : begin
            // Valid should stay valid until last FFT data from tuplet0
            // is presented to FFT blocks
            //
            if (!fft_sink_valid[idx3d][idx2d][gii]) begin
              // Not previously valid
              if (tplt_fftc_fstart_d[idx2d][GMRBDELMSBITM1]) begin
                // FFT data is valid in this clock cycle
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
              end else begin
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end
            end else begin
              // Previous valid detected
              //
              // Need to keep fft_sink_valid in order for tplt_fft_source_valid to
              // remain valid
              if (last_fftw && !last_fftw_d1) begin
                // Last write in this FFT stage
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftw_lastx[idx2d] && tplt_fftw_lasty[idx2d] && tplt_fftw_lastz[idx2d]) begin
                  // Last write for this tuplet in this dimension
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
                end else begin
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
                end
              end
            end

            // Use delayed frame start to create SOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[idx2d] && tplt_fftw_lasty[idx2d] && tplt_fftw_lastz[idx2d]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_fstart_d[idx2d][GMRBDELMSBITM1]) begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
                end
              end
            end

            // Use delayed lasty to create EOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[idx2d] && tplt_fftw_lasty[idx2d] && tplt_fftw_lastz[idx2d]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_lasty_d[idx2d][GMRBDELMSBITM1] && !tplt_fftc_lasty_d[idx2d][GMRBDELMSBIT]) begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
                end
              end
            end
          end
          FFTZNG, IFFTZ : begin
            // Valid should stay valid until last FFT data from tuplet0
            // is presented to FFT blocks
            //
            if (!fft_sink_valid[idx3d][idx2d][gii]) begin
              // Not previously valid
              if (tplt_fftc_fstart_d[idx3d][GMRBDELMSBITM1]) begin
                // FFT data is valid in this clock cycle
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
              end else begin
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end
            end else begin
              // Previous valid detected
              //
              // Need to keep fft_sink_valid in order for tplt_fft_source_valid to
              // remain valid
              if (last_fftw && !last_fftw_d1) begin
                // Last write in this FFT stage
                nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftw_lastx[idx3d] && tplt_fftw_lasty[idx3d] && tplt_fftw_lastz[idx3d]) begin
                  // Last write for this tuplet in this dimension
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
                end else begin
                  nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd1;
                end
              end
            end
            
            // Use delayed frame start to create SOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[idx3d] && tplt_fftw_lasty[idx3d] && tplt_fftw_lastz[idx3d]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_fstart_d[idx3d][GMRBDELMSBITM1]) begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_sop[idx3d][idx2d][gii] = 1'd0;
                end
              end    
            end

            // Use delayed lastz to create EOP
            if (last_fftw && !last_fftw_d1) begin
              // Last write in this FFT stage
              nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
            end else begin
              if (tplt_fftw_lastx[idx3d] && tplt_fftw_lasty[idx3d] && tplt_fftw_lastz[idx3d]) begin
                // Last write for this tuplet in this dimension
                nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
              end else begin
                if (tplt_fftc_lastz_d[idx3d][GMRBDELMSBITM1] && !tplt_fftc_lastz_d[idx3d][GMRBDELMSBIT]) begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd1;
                end else begin
                  nxt_fft_sink_eop[idx3d][idx2d][gii] = 1'd0;
                end
              end
            end
          end
          FCALC : begin
            nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_sop  [idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_eop  [idx3d][idx2d][gii] = 1'd0;
          end
          default : begin
            // Should never get here. Do something benign.
            nxt_fft_sink_valid[idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_sop  [idx3d][idx2d][gii] = 1'd0;
            nxt_fft_sink_eop  [idx3d][idx2d][gii] = 1'd0;
          end
        endcase
      end    
    end
  end  

  //////////////////////
  // Reset Generation //
  //////////////////////
  //
  // We have to keep pumping dummy data into the FFT blocks in order to get
  // valid FFT results out. When the last valid FFT data is sourced by the FFT
  // blocks, we are partially way through pumping in the dummy data. So when
  // we start pumping new valid data into the FFT IP blocks they get confused
  // about the incompleted frame. Generate a reset for the FFT IP blocks when
  // we start a new FFT direction

  always @(posedge clk) begin : fft_reset_seq
    if (rst) begin
      fft_reset_n <= 1'd0;
    end else begin
      fft_reset_n <= nxt_fft_reset_n;
    end
  end

  always @* begin : fft_reset_comb
    case (md_lr_seqr_state)
      INIT  : nxt_fft_reset_n = 1'd0;
      PGMAP : nxt_fft_reset_n = 1'd1;
      FFTX, FFTY, FFTZNG, IFFTX, IFFTY, IFFTZ: begin
        if (last_fftw && ! last_fftw_d1) begin
          nxt_fft_reset_n = 1'd0;
        end else begin
          nxt_fft_reset_n = 1'd1;
        end
      end
      FCALC   : nxt_fft_reset_n = 1'd0;
      default : nxt_fft_reset_n = 1'd0; // Should never get here!
    endcase
  end
  
  ////////////////////////
  // FFT Points Control //
  ////////////////////////
  //
  // Set number of points to size of the grid in a given FFT direction.
  // Always processed X then Y then Z.
  //
  always @(posedge clk) begin : fft_pts_seq
    if (rst) begin
      fft_pts_in <= GSIZE1DX[FFTPW:0];
    end else begin
      fft_pts_in <= nxt_fft_pts_in;
    end
  end

  always @* begin : fft_pts_comb
    case (md_lr_seqr_state)
      INIT  : nxt_fft_pts_in = fft_pts_in;
      PGMAP : nxt_fft_pts_in = fft_pts_in;

      FFTX, IFFTX : begin 
        if (last_fftw && !last_fftw_d1) begin
          nxt_fft_pts_in = GSIZE1DY[FFTPW:0];
        end else begin
          nxt_fft_pts_in = fft_pts_in;
        end
      end

      FFTY, IFFTY : begin 
        if (last_fftw && !last_fftw_d1) begin
          nxt_fft_pts_in = GSIZE1DZ[FFTPW:0];
        end else begin
          nxt_fft_pts_in = fft_pts_in;
        end
      end

      FFTZNG, IFFTZ : begin 
        if (last_fftw && !last_fftw_d1) begin
          nxt_fft_pts_in = GSIZE1DX[FFTPW:0];
        end else begin
          nxt_fft_pts_in = fft_pts_in;
        end
      end

      FCALC   : nxt_fft_pts_in = fft_pts_in;
      default : nxt_fft_pts_in = fft_pts_in; // Should never get here!
    endcase
  end

  // --------------------------------------------------------------------------
  // Green's Function ROM Control
  //
  // Address manipulation for FFT and IFFT is the most complex out of all
  // the phases. For FFT and IFFT operations, the block memories that make up
  // the grid memory are grouped into NNN1D tuplets of size NNN2D.
  //
  // Group control in the same manner to coding simplicity

  for (gii=0; gii<NNN1D; gii=gii+1) begin : grom_tuplet
      // Per-dimension, tuplet-based last coordinates
      //localparam TPLT_ZDLX = gii*NNN1D+((gii+NNN1D-32'd1)%NNN1D);
      localparam TPLT_ZDLX = (GSIZE1DX/NNN1D)*gii + (gii-1)%(GSIZE1DX/NNN1D);
      localparam TPLT_ZDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
      localparam TPLT_ZDLZ = 32'hFFFFFFFF;
    if (gii == 32'd0) begin : tuplet0
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;
        
        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;
        
        // Per-dimension, port-based start coordinates
        // Green's ROM is always enabled. Uniqify Z values to prevent contention
        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0-idx3d;
        
        always @(posedge clk) begin : ctrl_seq
          if (rst) begin
            grom_coordsz[idx3d][idx2d][gii] <= ZDZS[GADDRW1DZ-1:0];
            grom_coordsy[idx3d][idx2d][gii] <= ZDYS[GADDRW1DY-1:0];
            grom_coordsx[idx3d][idx2d][gii] <= ZDXS[GADDRW1DX-1:0];
          end else begin
            grom_coordsz[idx3d][idx2d][gii] <= nxt_grom_coordsz[idx3d][idx2d][gii];
            grom_coordsy[idx3d][idx2d][gii] <= nxt_grom_coordsy[idx3d][idx2d][gii];
            grom_coordsx[idx3d][idx2d][gii] <= nxt_grom_coordsx[idx3d][idx2d][gii];
          end
        end
  
        if (idx3d == 32'd0) begin : idx3deq0
          always @* begin : ctrl_comb
            if (md_lr_seqr_state == FFTZNG && md_lr_seqr_state_d1 == FFTZNG) begin
              // Inside FFTZNG after tplt_fft_source_valid signal assertions from
              // previous FFT state have been cleared
              if (update_grom_ctrl_tplt[0]) begin
                // FFT source is valid. Update ROM address for next valid
                //
                case ({grom_lastz[idx3d], grom_lasty[idx3d], grom_lastx[idx3d]})
                  3'b000 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end else begin
                nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii];
                nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
              end
            end else begin
              nxt_grom_coordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
              nxt_grom_coordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
              nxt_grom_coordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
            end
          end
        end else begin : idx3deqn
          always @* begin : ctrl_comb
            if (md_lr_seqr_state == FFTZNG && md_lr_seqr_state_d1 == FFTZNG) begin
              // Inside FFTZNG after tplt_fft_source_valid signal assertions from
              // previous FFT state have been cleared
              if (update_grom_ctrl_tplt[idx3d]) begin
                // FFT source is valid. Update ROM address for next valid
                //
                case ({grom_lastz[idx3d], grom_lasty[idx3d], grom_lastx[idx3d]})
                  3'b000 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end else begin
                if (update_grom_ctrl_tplt[0]) begin
                  nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                  nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                  nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                end else begin
                  nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii];
                  nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                  nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                end
              end
            end else begin
              nxt_grom_coordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
              nxt_grom_coordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
              nxt_grom_coordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
            end
          end     
        end
      end

      always @(posedge clk) begin : rom_ctrl_update
        if (rst) begin
          update_grom_ctrl_tplt[gii] <= 1'd0;
        end else begin
          update_grom_ctrl_tplt[gii] <= (cntr4rom == CNT4ROMMAX[CNT4ROMW-1:0]);
        end
      end
    end else begin : tupletn
      for (gjj=0; gjj<NNN2D; gjj=gjj+1) begin : member
        // Create index for 2nd dimension
        localparam idx2d = gjj >> NN1DIDW;
        
        // Create index for 3rd dimension
        localparam idx3d = gjj % NNN1D;
        
        // Per-dimension, port-based start coordinates
        // Green's ROM is always enabled. Uniqify Z values to prevent contention
        //localparam ZDXS = gii+NNN1D*idx3d;
        localparam ZDXS = gii + (GSIZE1DX/NNN1D)*idx3d;
        localparam ZDYS = gii*NNN1D+idx2d;
        localparam ZDZS = 32'd0-idx3d;
        
        always @(posedge clk) begin : ctrl_seq
          if (rst) begin
            grom_coordsz[idx3d][idx2d][gii] <= ZDZS[GADDRW1DZ-1:0];
            grom_coordsy[idx3d][idx2d][gii] <= ZDYS[GADDRW1DY-1:0];
            grom_coordsx[idx3d][idx2d][gii] <= ZDXS[GADDRW1DX-1:0];
          end else begin
            grom_coordsz[idx3d][idx2d][gii] <= nxt_grom_coordsz[idx3d][idx2d][gii];
            grom_coordsy[idx3d][idx2d][gii] <= nxt_grom_coordsy[idx3d][idx2d][gii];
            grom_coordsx[idx3d][idx2d][gii] <= nxt_grom_coordsx[idx3d][idx2d][gii];
          end
        end
  
        if (idx3d == 32'd0) begin : idx3deq0
          always @* begin : ctrl_comb
            if (md_lr_seqr_state == FFTZNG && md_lr_seqr_state_d1 == FFTZNG) begin
              // Inside FFTZNG after tplt_fft_source_valid signal assertions from
              // previous FFT state have been cleared
              if (update_grom_ctrl_tplt[0]) begin
                // FFT source is valid. Update ROM address for next valid
                //
                case ({grom_lastz[idx3d], grom_lasty[idx3d], grom_lastx[idx3d]})
                  3'b000 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end else begin
                nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii];
                nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
              end
            end else begin
              nxt_grom_coordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
              nxt_grom_coordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
              nxt_grom_coordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
            end
          end
        end else begin : idx3deqn
          always @* begin : ctrl_comb
            if (md_lr_seqr_state == FFTZNG && md_lr_seqr_state_d1 == FFTZNG) begin
              // Inside FFTZNG after tplt_fft_source_valid signal assertions from
              // previous FFT state have been cleared
              if (update_grom_ctrl_tplt[idx3d]) begin
                // FFT source is valid. Update ROM address for next valid
                //
                case ({grom_lastz[idx3d], grom_lasty[idx3d], grom_lastx[idx3d]})
                  3'b000 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b001 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b010 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b011 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b100 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b101 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                  end
                  3'b110 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                  3'b111 : begin
                    nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                    nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii] + NNN2D[GADDRW1DYM1:0];
                    nxt_grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW] = grom_coordsx[idx3d][idx2d][gii][GADDRW1DXM1:ZDXRANGEW];
                    nxt_grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] = grom_coordsx[idx3d][idx2d][gii][ZDXRANGEW-1:0] + {{ZDXRANGEWM1{1'b0}}, 1'd1};
                  end
                endcase
              end else begin
                if (update_grom_ctrl_tplt[0]) begin
                  nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii] + {{GADDRW1DZM1{1'd0}}, 1'd1};
                  nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                  nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                end else begin
                  nxt_grom_coordsz[idx3d][idx2d][gii] = grom_coordsz[idx3d][idx2d][gii];
                  nxt_grom_coordsy[idx3d][idx2d][gii] = grom_coordsy[idx3d][idx2d][gii];
                  nxt_grom_coordsx[idx3d][idx2d][gii] = grom_coordsx[idx3d][idx2d][gii];
                end
              end
            end else begin
              nxt_grom_coordsz[idx3d][idx2d][gii] = ZDZS[GADDRW1DZ-1:0];
              nxt_grom_coordsy[idx3d][idx2d][gii] = ZDYS[GADDRW1DY-1:0];
              nxt_grom_coordsx[idx3d][idx2d][gii] = ZDXS[GADDRW1DX-1:0];
            end
          end     
        end
      end

      always @(posedge clk) begin : rom_ctrl_update
        if (rst) begin
          update_grom_ctrl_tplt[gii] <= 1'd0;
        end else begin
          update_grom_ctrl_tplt[gii] <= update_grom_ctrl_tplt[gii-1];
        end
      end
    end

    always @* begin : grom_framing_z_comb
      if (grom_coordsz[gii][gii][gii] == TPLT_ZDLZ[GADDRW1DZ-1:0]) begin
        grom_lastz[gii] = 1'd1;
      end else begin
        grom_lastz[gii] = 1'd0;   
      end
    end

    always @* begin : grom_framing_y_comb
      if (grom_coordsy[gii][gii][gii] == TPLT_ZDLY[GADDRW1DZ-1:0]) begin
        grom_lasty[gii] = 1'd1;
      end else begin
        grom_lasty[gii] = 1'd0;
      end
    end

    always @* begin : grom_framing_x_comb
      if (grom_coordsx[gii][gii][gii] == TPLT_ZDLX[GADDRW1DZ-1:0]) begin
        grom_lastx[gii] = 1'd1;
      end else begin
        grom_lastx[gii] = 1'd0;
      end
    end
  end

  always @(posedge clk) begin : count4rom_seq
    if (rst) begin
      cntr4rom <= {CNT4ROMW{1'd0}};
    end else begin
      cntr4rom <= nxt_cntr4rom;
    end
  end

  always @* begin : count4rom_comb
    if (md_lr_seqr_state == FFTZNG) begin
      if (cntr4rom == CNT4ROMMAX[CNT4ROMW-1:0]) begin
        nxt_cntr4rom = cntr4rom;
      end else begin
        if (fft_sink_valid[0][0][0]) begin
          nxt_cntr4rom = cntr4rom + {{CNT4ROMWM1{1'd0}}, 1'd1};
        end else begin
          nxt_cntr4rom = cntr4rom;
        end
      end
    end else begin
      nxt_cntr4rom = {CNT4ROMW{1'd0}};
    end
  end

  // --------------------------------------------------------------------------
  // Coefficient Mapping Status
  //
  // Create status signal that signifies the clock cycle in which coefficient
  // mapping completes. 

  always @(posedge clk) begin : mapping_done_seq
    if (rst) begin
      mapping_done <= 1'd0;
    end else begin
      mapping_done <= nxt_mapping_done;
    end
  end
  
  always @* begin : mapping_done_comb
    if (md_lr_seqr_state == PGMAP) begin
      // In Mapping state
      if (mapcountw == pcount_plus_one) begin
        // Last particle
        nxt_mapping_done = 1'd1;
      end else begin
        // Not the last particle
        nxt_mapping_done = 1'd0;
      end
    end else begin
      // Not in mapping state
      nxt_mapping_done = 1'd0;
    end
  end

  // --------------------------------------------------------------------------
  // FFT Read Framing
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : fftr_tuplet
    // Per-dimension, tuplet-based last coordinates
    localparam TPLT_XDLX = 32'hFFFFFFFF;
    localparam TPLT_XDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_XDLZ = GSIZE1DZ-NNN1D+gii;

    //localparam TPLT_YDLX = (gii*NNN1D+gii+NNN1D-32'd1) % GSIZE1DX;
    localparam TPLT_YDLX = ((GSIZE1DX/NNN1D)*(gii+1) + gii - 1) % GSIZE1DX;
    localparam TPLT_YDLY = 32'hFFFFFFFF;
    localparam TPLT_YDLZ = GSIZE1DZ-NNN2D+gii*NNN1D+gii;

    //localparam TPLT_ZDLX = gii*NNN1D+((gii+NNN1D-32'd1)%NNN1D);
    localparam TPLT_ZDLX = (GSIZE1DX/NNN1D)*gii + (gii-1)%(GSIZE1DX/NNN1D);
    localparam TPLT_ZDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_ZDLZ = 32'hFFFFFFFF;

    /////////////////////////////////////
    // FFT Last Elements in Coordinate //
    /////////////////////////////////////
    //
    always @* begin : fend
      case (md_lr_seqr_state)
        FFTX : begin
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == TPLT_XDLX[GADDRW1DX-1:0];
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == TPLT_XDLY[GADDRW1DY-1:0];
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == TPLT_XDLZ[GADDRW1DZ-1:0];
        end
        
        FFTY : begin
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == TPLT_YDLX[GADDRW1DX-1:0];
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == TPLT_YDLY[GADDRW1DY-1:0];
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == TPLT_YDLZ[GADDRW1DZ-1:0];
        end
        
        FFTZNG : begin
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == TPLT_ZDLX[GADDRW1DX-1:0];
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == TPLT_ZDLY[GADDRW1DY-1:0];
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == TPLT_ZDLZ[GADDRW1DZ-1:0];
        end
        
        IFFTX : begin
          // Last lowest x coordinate is 1 because of ifft workaround using fft
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == {{GADDRW1DXM1{1'd0}}, 1'd1};
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == TPLT_XDLY[GADDRW1DY-1:0];
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == TPLT_XDLZ[GADDRW1DZ-1:0];
        end
        
        IFFTY : begin
          // Last lowest y coordinate is 1 because of ifft workaround using fft
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == TPLT_YDLX[GADDRW1DX-1:0];
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == {{GADDRW1DYM1{1'd0}}, 1'd1};
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == TPLT_YDLZ[GADDRW1DZ-1:0];
        end
        
        IFFTZ : begin
          // Last lowest z coordinate is 1 because of ifft workaround using fft
          tplt_fftr_lastx[gii] = gmem_rcoordsx[gii][gii][gii] == TPLT_ZDLX[GADDRW1DX-1:0];
          tplt_fftr_lasty[gii] = gmem_rcoordsy[gii][gii][gii] == TPLT_ZDLY[GADDRW1DY-1:0];
          tplt_fftr_lastz[gii] = gmem_rcoordsz[gii][gii][gii] == {{GADDRW1DZM1{1'd0}}, 1'd1};
        end
        
        default : begin
          tplt_fftr_lastx[gii] = 1'd0;
          tplt_fftr_lasty[gii] = 1'd0;
          tplt_fftr_lastz[gii] = 1'd0;
        end
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // FFT Control Framing
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : fftc_tuplet
    // Per-dimension, tuplet-based last coordinates
    localparam TPLT_XDLX = 32'hFFFFFFFF;
    localparam TPLT_XDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_XDLZ = GSIZE1DZ-NNN1D+gii;

    //localparam TPLT_YDLX = (gii*NNN1D+gii+NNN1D-32'd1) % GSIZE1DX;
    localparam TPLT_YDLX = ((GSIZE1DX/NNN1D)*(gii+1) + gii - 1) % GSIZE1DX;
    localparam TPLT_YDLY = 32'hFFFFFFFF;
    localparam TPLT_YDLZ = GSIZE1DZ-NNN2D+gii*NNN1D+gii;

    //localparam TPLT_ZDLX = gii*NNN1D+((gii+NNN1D-32'd1)%NNN1D);
    localparam TPLT_ZDLX = (GSIZE1DX/NNN1D)*gii + (gii-1)%(GSIZE1DX/NNN1D);
    localparam TPLT_ZDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_ZDLZ = 32'hFFFFFFFF;

    if (GMRBDEL == 32'd0) begin : fftc_lkhd
      /////////////////////
      // FFT Frame Start //
      /////////////////////
      //
      // Grid memory has no readback latency. Read data will be valid
      // within the first clock cycle of *FFT* states. Assert start 1 clock cycle
      // ahead of that.
      //
      always @* begin : fstart
        case (nxt_md_lr_seqr_state)
          FFTX, IFFTX : begin
            if ((nxt_gmem_rcoordsx[gii][gii][gii] == {GADDRW1DX{1'd0}}) &&
                (nxt_gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          FFTY, IFFTY : begin
            if ((nxt_gmem_rcoordsy[gii][gii][gii] == {GADDRW1DY{1'd0}}) &&
                (nxt_gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          FFTZNG, IFFTZ : begin
            if ((nxt_gmem_rcoordsz[gii][gii][gii] == {GADDRW1DZ{1'd0}}) &&
                (nxt_gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          default : tplt_fftc_fstart[gii] = 1'd0;
        endcase
      end

      ////////////////////////////////////
      // FFT Last Element in Coordinate //
      ////////////////////////////////////
      //
      // Grid memory has no readback latency. Read data will be valid shortly
      // after read controls are presnted but before next clock cycle.
      // Use next-state of read controls to determine lasts.
      //
      always @* begin : fend
        case (md_lr_seqr_state)
          FFTX, IFFTX : begin
            tplt_fftc_lastx[gii] = nxt_gmem_rcoordsx[gii][gii][gii] == TPLT_XDLX[GADDRW1DX-1:0];       
            tplt_fftc_lasty[gii] = nxt_gmem_rcoordsy[gii][gii][gii] == TPLT_XDLY[GADDRW1DY-1:0];
            tplt_fftc_lastz[gii] = nxt_gmem_rcoordsz[gii][gii][gii] == TPLT_XDLZ[GADDRW1DZ-1:0];        
          end
        
          FFTY, IFFTY : begin
            tplt_fftc_lastx[gii] = nxt_gmem_rcoordsx[gii][gii][gii] == TPLT_YDLX[GADDRW1DX-1:0];       
            tplt_fftc_lasty[gii] = nxt_gmem_rcoordsy[gii][gii][gii] == TPLT_YDLY[GADDRW1DY-1:0];
            tplt_fftc_lastz[gii] = nxt_gmem_rcoordsz[gii][gii][gii] == TPLT_YDLZ[GADDRW1DZ-1:0];        
          end
        
          FFTZNG, IFFTZ : begin
            tplt_fftc_lastx[gii] = nxt_gmem_rcoordsx[gii][gii][gii] == TPLT_ZDLX[GADDRW1DX-1:0];       
            tplt_fftc_lasty[gii] = nxt_gmem_rcoordsy[gii][gii][gii] == TPLT_ZDLY[GADDRW1DY-1:0];
            tplt_fftc_lastz[gii] = nxt_gmem_rcoordsz[gii][gii][gii] == TPLT_ZDLZ[GADDRW1DZ-1:0];        
          end
        
          default : begin
            tplt_fftc_lastx[gii] = 1'd0;
            tplt_fftc_lasty[gii] = 1'd0;
            tplt_fftc_lastz[gii] = 1'd0;
          end
        endcase
      end
    end else begin : no_fftc_lkhd
      /////////////////////
      // FFT Frame Start //
      /////////////////////
      //
      // Grid memory has readback latency so valid read data will be generated
      // after first clock cycle in *FFT* state. Assert start signal in first
      // clock cycle of *FFT* state.
      //
      always @* begin : fstart
        case (md_lr_seqr_state)
          FFTX, IFFTX : begin
            if ((gmem_rcoordsx[gii][gii][gii] == {GADDRW1DX{1'd0}}) &&
                (gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          FFTY, IFFTY : begin
            if ((gmem_rcoordsy[gii][gii][gii] == {GADDRW1DY{1'd0}}) &&
                (gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          FFTZNG, IFFTZ : begin
            if ((gmem_rcoordsz[gii][gii][gii] == {GADDRW1DZ{1'd0}}) &&
                (gmem_mer     [gii][gii][gii] == 1'd1)) begin
              tplt_fftc_fstart[gii] = 1'd1;
            end else begin
              tplt_fftc_fstart[gii] = 1'd0;
            end
          end
          default : tplt_fftc_fstart[gii] = 1'd0;
        endcase
      end
    
      ////////////////////////////////////
      // FFT Last Element in Coordinate //
      ////////////////////////////////////
      //
      // Grid memory has readback latency so valid read data will be generated
      // immediately following clock edge that samples read controls. Use
      // grid memory read control registers to determine lasts.
      always @* begin : tplt_fftc_fend
        tplt_fftc_lastx[gii] = tplt_fftr_lastx[gii];
        tplt_fftc_lasty[gii] = tplt_fftr_lasty[gii];
        tplt_fftc_lastz[gii] = tplt_fftr_lastz[gii];
      end
    end

    /////////////
    // Latency //
    /////////////
    //
    // Control data framing information is generated in the same clock cycle
    // where address and control informration is presented to the grid memory.
    //
    // Delay this control information in order to align it with the data that
    // will be presented to the FFT blocks
    //  
    // 'fstart' and 'fftc_last' signals are only used in FFT control logic, thus
    //  only requiring optional delay registers to account for readback timing of
    //  grid memory
    //
    // These signals are sampled by a FFT sink control registers.
    //
    if (GMRBDEL <= 32'd1) begin : no_start_fftc_dir_delay
      // No need to delay tplt0_fftc_fstart.
      //
      //
      // A grid memory readback latency of 0 means that grid memory data is valid
      // some time after read controls are presented, but before next clock cycle.
      //
      // A grid memory readback latency of 1 means that data is valid immediately
      // following clock edge that samples control signals
      always @* begin : start_fftc_dir_comb
        tplt_fftc_fstart_d[gii]  = tplt_fftc_fstart[gii];
        tplt_fftc_lastx_d [gii]  = tplt_fftc_lastx[gii];
        tplt_fftc_lasty_d [gii]  = tplt_fftc_lasty[gii];
        tplt_fftc_lastz_d [gii]  = tplt_fftc_lastz[gii];
      end
    end else begin : start_fftc_dir_delay
      always @(posedge clk) begin : del0
        if (rst) begin
          tplt_fftc_fstart_d[gii][0] <= 1'd0;
          tplt_fftc_lastx_d [gii][0] <= 1'd0;
          tplt_fftc_lasty_d [gii][0] <= 1'd0;
          tplt_fftc_lastz_d [gii][0] <= 1'd0;
        end else begin
          if (last_fftw && !last_fftw_d1) begin
            tplt_fftc_fstart_d[gii][0] <= 1'd0;
            tplt_fftc_lastx_d [gii][0] <= 1'd0;
            tplt_fftc_lasty_d [gii][0] <= 1'd0;
            tplt_fftc_lastz_d [gii][0] <= 1'd0;
          end else begin
            if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
              tplt_fftc_fstart_d[gii][0] <= 1'd0;
              tplt_fftc_lastx_d [gii][0] <= 1'd0;
              tplt_fftc_lasty_d [gii][0] <= 1'd0;
              tplt_fftc_lastz_d [gii][0] <= 1'd0;
            end else begin
              tplt_fftc_fstart_d[gii][0] <= tplt_fftc_fstart[gii];
              tplt_fftc_lastx_d [gii][0] <= tplt_fftc_lastx [gii];
              tplt_fftc_lasty_d [gii][0] <= tplt_fftc_lasty [gii];
              tplt_fftc_lastz_d [gii][0] <= tplt_fftc_lastz [gii];
            end
          end
        end
      end

      for (gjj=1; gjj<GMRBDELM1; gjj=gjj+1) begin : del
        always @(posedge clk) begin : seq
          if (rst) begin
            tplt_fftc_fstart_d[gii][gjj] <= 1'd0;
            tplt_fftc_lastx_d [gii][gjj] <= 1'd0;
            tplt_fftc_lasty_d [gii][gjj] <= 1'd0;
            tplt_fftc_lastz_d [gii][gjj] <= 1'd0;
          end else begin
            if (last_fftw && !last_fftw_d1) begin
              tplt_fftc_fstart_d[gii][gjj] <= 1'd0;
              tplt_fftc_lastx_d [gii][gjj] <= 1'd0;
              tplt_fftc_lasty_d [gii][gjj] <= 1'd0;
              tplt_fftc_lastz_d [gii][gjj] <= 1'd0;
            end else begin
              if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
                tplt_fftc_fstart_d[gii][gjj] <= 1'd0;
                tplt_fftc_lastx_d [gii][gjj] <= 1'd0;
                tplt_fftc_lasty_d [gii][gjj] <= 1'd0;
                tplt_fftc_lastz_d [gii][gjj] <= 1'd0;
              end else begin
                tplt_fftc_fstart_d[gii][gjj] <= tplt_fftc_fstart_d[gii][gjj-1];
                tplt_fftc_lastx_d [gii][gjj] <= tplt_fftc_lastx_d [gii][gjj-1];
                tplt_fftc_lasty_d [gii][gjj] <= tplt_fftc_lasty_d [gii][gjj-1];
                tplt_fftc_lastz_d [gii][gjj] <= tplt_fftc_lastz_d [gii][gjj-1];
              end
            end
          end
        end
      end

      always @(posedge clk) begin : delmsb
        if (rst) begin
          tplt_fftc_lastx_d[gii][GMRBDELM1] <= 1'd0;
          tplt_fftc_lasty_d[gii][GMRBDELM1] <= 1'd0;
          tplt_fftc_lastz_d[gii][GMRBDELM1] <= 1'd0;
        end else begin
          if (last_fftw && !last_fftw_d1) begin
            tplt_fftc_lastx_d[gii][GMRBDELM1] <= 1'd0;
            tplt_fftc_lasty_d[gii][GMRBDELM1] <= 1'd0;
            tplt_fftc_lastz_d[gii][GMRBDELM1] <= 1'd0;
          end else begin
            if (tplt_fftw_lastx[gii] && tplt_fftw_lasty[gii] && tplt_fftw_lastz[gii]) begin
              tplt_fftc_lastx_d[gii][GMRBDELM1] <= 1'd0;
              tplt_fftc_lasty_d[gii][GMRBDELM1] <= 1'd0;
              tplt_fftc_lastz_d[gii][GMRBDELM1] <= 1'd0;
            end else begin
              tplt_fftc_lastx_d[gii][GMRBDELM1] <= tplt_fftc_lastx_d[gii][GMRBDELM1-1];
              tplt_fftc_lasty_d[gii][GMRBDELM1] <= tplt_fftc_lasty_d[gii][GMRBDELM1-1];
              tplt_fftc_lastz_d[gii][GMRBDELM1] <= tplt_fftc_lastz_d[gii][GMRBDELM1-1];
            end
          end
        end
      end
    end
  end
                
  // --------------------------------------------------------------------------
  // FFT Write Framing
  //
  /////////////////////
  // FFT Frame Start //
  /////////////////////
  //
  // Can use FFT tplt_fft_source_sop to determine start of frame
  
  /////////////////////////////////////
  // FFT Last Elements in Coordinate //
  /////////////////////////////////////
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : fftw_tuplet
    // Per-dimension, tuplet-based last coordinates
    localparam TPLT_XDLX = 32'hFFFFFFFF;
    localparam TPLT_XDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_XDLZ = GSIZE1DZ-NNN1D+gii;

    //localparam TPLT_YDLX = (gii*NNN1D+gii+NNN1D-32'd1) % GSIZE1DX;
    localparam TPLT_YDLX = ((GSIZE1DX/NNN1D)*(gii+1) + gii - 1) % GSIZE1DX;
    localparam TPLT_YDLY = 32'hFFFFFFFF;
    localparam TPLT_YDLZ = GSIZE1DZ-NNN2D+gii*NNN1D+gii;

    //localparam TPLT_ZDLX = gii*NNN1D+((gii+NNN1D-32'd1)%NNN1D);
    localparam TPLT_ZDLX = (GSIZE1DX/NNN1D)*gii + (gii-1)%(GSIZE1DX/NNN1D);
    localparam TPLT_ZDLY = GSIZE1DY-NNN2D+gii*NNN1D+gii;
    localparam TPLT_ZDLZ = 32'hFFFFFFFF;

    always @* begin : fend
      case (md_lr_seqr_state)
        FFTX, IFFTX : begin
          tplt_fftw_lastx[gii] = gmem_wcoordsx[gii][gii][gii] == TPLT_XDLX[GADDRW1DX-1:0];       
          tplt_fftw_lasty[gii] = gmem_wcoordsy[gii][gii][gii] == TPLT_XDLY[GADDRW1DY-1:0];
          tplt_fftw_lastz[gii] = gmem_wcoordsz[gii][gii][gii] == TPLT_XDLZ[GADDRW1DZ-1:0];        
        end

        FFTY, IFFTY : begin
          tplt_fftw_lastx[gii] = gmem_wcoordsx[gii][gii][gii] == TPLT_YDLX[GADDRW1DX-1:0];       
          tplt_fftw_lasty[gii] = gmem_wcoordsy[gii][gii][gii] == TPLT_YDLY[GADDRW1DY-1:0];
          tplt_fftw_lastz[gii] = gmem_wcoordsz[gii][gii][gii] == TPLT_YDLZ[GADDRW1DZ-1:0];        
        end
        
        FFTZNG, IFFTZ : begin
          tplt_fftw_lastx[gii] = gmem_wcoordsx[gii][gii][gii] == TPLT_ZDLX[GADDRW1DX-1:0];       
          tplt_fftw_lasty[gii] = gmem_wcoordsy[gii][gii][gii] == TPLT_ZDLY[GADDRW1DY-1:0];
          tplt_fftw_lastz[gii] = gmem_wcoordsz[gii][gii][gii] == TPLT_ZDLZ[GADDRW1DZ-1:0];        
        end
        
        default : begin
          tplt_fftw_lastx[gii] = 1'd0;
          tplt_fftw_lasty[gii] = 1'd0;
          tplt_fftw_lastz[gii] = 1'd0;
        end
      endcase
    end
  end

  /////////////////////////////
  // Tuplet Validation Delay //
  /////////////////////////////
  //
  // Create:
  //  1) Delayed version of FFT source SOP ANDed with FFT source valid for
  //     each tuplet for grid memory writes during the FFTZNG
  //     state
  for(gii=0; gii<NNN1D; gii=gii+1) begin : fft_valid_src_start_tuplet
    always @(posedge clk) begin : delay0
      if (rst) begin
        tplt_fft_vld_src_start_d[gii][0] <= 1'd0;
      end else begin
        if (last_fftw && !last_fftw_d1) begin
          tplt_fft_vld_src_start_d[gii][0] <= 1'd0;
        end else begin
          tplt_fft_vld_src_start_d[gii][0] <= tplt_fft_source_valid[gii] & tplt_fft_source_sop[gii];
        end
      end
    end

    for(gjj=1; gjj<GRNDEL; gjj=gjj+1) begin : del
      always @(posedge clk) begin : delayn
        if (rst) begin
          tplt_fft_vld_src_start_d[gii][gjj] <= 1'd0;
        end else begin
          if (last_fftw && !last_fftw_d1) begin
            tplt_fft_vld_src_start_d[gii][gjj] <= 1'd0;
          end else begin
            tplt_fft_vld_src_start_d[gii][gjj] <= tplt_fft_vld_src_start_d[gii][gjj-1];
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // End of FFT Detection
  //
  assign last_fftw = &{tplt_fftw_lastx[NNN1D-1],
                       tplt_fftw_lasty[NNN1D-1],
                       tplt_fftw_lastz[NNN1D-1]};

  always @(posedge clk) begin : last_fftw_delay_seq
    if (rst) begin
      last_fftw_d1 <= 1'd0;
    end else begin
      last_fftw_d1 <= last_fftw;
    end
  end


  // --------------------------------------------------------------------------
  // Force Coefficient Generator Control
  //
  // Delay particle memory enable in force calculation to compensate for
  // variable particle memory readback delay
  //
  assign fcalc_pmem_me = pmem_me & (md_lr_seqr_state == FCALC);
   
  generate
    if (PMRBDEL == 32'd0) begin : no_fcalc_pmem_me_delay
      always @* begin : comb
        fcalc_pmem_me_d = fcalc_pmem_me;
      end
    end else begin : fcalc_pmem_me_delay
      always @(posedge clk) begin : del0
        if (rst) begin
          fcalc_pmem_me_d[0] <= 1'd0;
        end else begin
            if (fvalid && !fready) begin
              // Force calculation pipeline stalled
              fcalc_pmem_me_d[0] <= fcalc_pmem_me_d[0];
            end else begin
              fcalc_pmem_me_d[0] <= fcalc_pmem_me;
          end
        end
      end

      for (gii=1; gii<PMRBDEL; gii=gii+1) begin : del
        always @(posedge clk) begin : seq
          if (rst) begin
            fcalc_pmem_me_d[gii] <= 1'd0;
          end else begin
            if (fvalid && !fready) begin
              // Force calculation pipeline stalled
              fcalc_pmem_me_d[gii] <= fcalc_pmem_me_d[gii];
            end else begin
              fcalc_pmem_me_d[gii] <= fcalc_pmem_me_d[gii-1];
            end
          end
        end
      end
    end
  endgenerate

  assign fmap_en = fcalc_pmem_me_d[PMRBDELMSBIT];

  // Floating point needs to be combinational based on fready in order to stall
  // the force pipeline
  always @* begin : ffpen_comb
    if (md_lr_seqr_state == FCALC) begin
      if (!fvalid) begin
        // Force information not valid yet. It's still working its way out
        ffpen = 1'd1;
      end else begin
        // Force information valid
        if(!fready) begin
          // External not ready for force information
          ffpen = 1'd0;
          // External ready for force information
        end else begin
          ffpen = 1'd1;
        end
      end
    end else begin
      ffpen = 1'd0;
    end
  end

  // --------------------------------------------------------------------------
  // Force Tree Counter
  //
  // Count clock cycles after coefficient generator generates valid data in order
  // to know when data should be written back
  always @(posedge clk) begin : ftcount_seq
    if (rst) begin
      ftcount <= {FTCNTW{1'd0}};
    end else begin
      ftcount <= nxt_ftcount;
    end
  end
  
  always @* begin : ftcount_comb
    if (md_lr_seqr_state == FCALC) begin
      // In Force Calculation state
      if (ftcount == FTDELM1[FTCNTW-1:0]) begin
        // Force Tree calculation complete
        nxt_ftcount = ftcount;
      end else begin
        if (fcoeff_valid) begin
          // Coefficient (valid?) write enable (delayed)
          if (ftcount == FTDELM1[FTCNTW-1:0]) begin
            // Force Tree calculation complete
            nxt_ftcount = ftcount;
          end else begin
            // Force Tree calculation incomplete
            nxt_ftcount = ftcount + {{(FTCNTW-1){1'd0}}, 1'd1};
          end
        end else begin
          // Valid coefficients not generated yet.
          nxt_ftcount = ftcount;
        end
      end
    end else begin
      // Not in Force Calculation state
      nxt_ftcount = {FTCNTW{1'd0}};
    end
  end

  // --------------------------------------------------------------------------
  // Force Interface
  //
  always @(posedge clk) begin : fctrl_seq
    if (rst) begin
       fvalid <= 1'd0;
       flast  <= 1'd0;
    end else begin
       fvalid <= nxt_fvalid;
       flast  <= nxt_flast;
    end
  end

  always @* begin : fctrl_comb
    if (md_lr_seqr_state == FCALC) begin
      // In Force Calculation state
      if (fvalid && fready && flast) begin
        nxt_fvalid = 1'd0;
      end else begin
        if (ftcount == FTDELM1[FTCNTW-1:0]) begin
          // Force Tree calculation complete
          nxt_fvalid = 1'd1;
        end else begin
          nxt_fvalid = 1'd0;
        end
      end

      if (flast) begin
        if (fvalid && fready) begin
          nxt_flast = 1'd0;
        end else begin
          nxt_flast = 1'd1;
        end
      end else begin
        if ((faddr == (pcount + {PADDRW{1'd1}})) && fvalid && fready) begin
          nxt_flast = 1'd1;
        end else begin
          nxt_flast = 1'd0;
        end       
      end
    end else begin
      nxt_fvalid = 1'd0;
      nxt_flast  = 1'd0;
    end
  end

  // Address generation
  always @(posedge clk) begin : faddr_seq
    if (rst) begin
      faddr <= {PADDRW{1'd0}};
    end else begin
      faddr <= nxt_faddr;
    end
  end

  always @* begin : faddr_comb
    if (md_lr_seqr_state == FCALC) begin
      if (!fvalid) begin
        // Force information not valid yet. It's still working its way out
        nxt_faddr = faddr;
      end else begin
        // Force information valid
        if(!fready) begin
          // External not ready for force information
          nxt_faddr = faddr;
        end else begin
          // External ready for force information
          if (flast) begin
            // Last force transfer
            nxt_faddr = faddr;
          end else begin
            nxt_faddr = faddr + {{(PADDRW-1){1'd0}}, 1'd1};
          end
        end
      end
    end else begin
      nxt_faddr = {PADDRW{1'd0}};
    end
  end

  // --------------------------------------------------------------------------
  // Misc. Sequencer Control Logic
  //
  // Detect transfer of last particle data
  assign last_p_xfer = plast & pready & pvalid;
  
  // Delay detection of last particle data (used to end init phase)
  always @(posedge clk) begin : last_p_xfer_d1_seq
    if (rst) begin
      last_p_xfer_d1 <= 1'd0;
    end else begin
      last_p_xfer_d1 <= last_p_xfer;
    end
  end


  always @(posedge clk) begin : md_lr_seqr_state_d1_seq
    if (rst) begin
      md_lr_seqr_state_d1 <= INIT;
    end else begin
      md_lr_seqr_state_d1 <= md_lr_seqr_state;
    end
  end
endmodule
