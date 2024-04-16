// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : md_lr_top.sv
// Description    : Top-Level MD LR module
// 
// ============================================================================

module md_lr_top (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  clk,    // (I) Clock
`ifdef IS_AFU
  rst,    // (I) Reset
`endif

  // Particle Memory Interface
  pready, // (O) Particle Memory ready
  pvalid, // (I) Particle Memory control valid
  paddr,  // (I) Particle Memory address
  pwe,    // (I) Particle Memory write enable
  pwdata, // (I) Particle Memory write data
  plast,  // (I) Last particle data indicator
  
  // Force Memory Interface
  fready, // (I) Force ready
  fvalid, // (O) Force valid
  faddr,  // (O) Force address
  flast,  // (O) Last particle data indicator
  fdata   // (O) Force read data

);
  
  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // 1D Grid Dimensions
  parameter GSIZE1DX = 32'd16;
  parameter GSIZE1DY = 32'd16;
  parameter GSIZE1DZ = 32'd16;
  
  // Maximum number of particles
  parameter MAXNUMP = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Read delay timing of particle memory
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] PMRDTYPE = 2'd2;

  // Number of nearest neighbors along one dimension
  parameter NNN1D = 32'd4;
  
  // Read delay timing of grid mem blocks
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] GMRDTYPE = 2'd2;
  
  // Width of oi values
  parameter OIW = 32'd27;

  // Maximum number of FFT points that can be processed by FFT IP
  parameter MAXFFTP = 32'd32;

  // --------------------------------------------------------------------------
  // Local / Derived Parameters
  //
  // Width of 1D grid addresses
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);
    
  // Width of particle address bus
  localparam PADDRW = $clog2(MAXNUMP);

  // Particle Data Width
  localparam PDATAW = GADDRW1DZ + GADDRW1DY + GADDRW1DX + 32'd3*OIW + 32'd32;

  // Width of floating point values
  localparam FPVW = 32'd32;

  // Bit width of each grid element
  localparam GELEW = FPVW+FPVW;

  // Force Data Width
  localparam FDATAW = 32'd96;
  
  // Latency of floating point addition
  localparam FPADDDEL = 32'd3;

  // Latency of floating point multiplication
  localparam FPMULDEL = 32'd3;

  // Latency of conversion to floating point 
  localparam TOFPDEL = 32'd11;

  // Maximum number of FFT points that can be processed by FFT IP
  //localparam MAXFFTP = 32'd32;

  // Width of FFT points control
  localparam FFTPW = $clog2(MAXFFTP);

  // Grid Memory Readback Latency
  //  o Account for readback latency of block RAMs
  //  o Account for 3 stages of piplined control MUXing
  //  o Account for 3 stages of pipelined read data MUXing
  localparam GMRBDEL0 = (GMRDTYPE == 2'd0) ? 32'd0 :
                        (GMRDTYPE == 2'd1) ? 32'd1 :
                        (GMRDTYPE == 2'd2) ? 32'd1 : 32'd2;

  localparam GMRBDEL = GMRBDEL0 + 32'd6;

  // Latency of Green's function
  localparam GRNDEL = FPMULDEL;

  // Number of nearest neighbors in 3D
  localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // Grid size in 3D
  localparam GSIZE3D = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Number of nearest neighbors in 3D
  //localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // The size of the grid divided by the number of nearest neighbors will serve
  // as the depth of each memory block
  localparam BMEMD = GSIZE3D / NNN3D;

  // Address width of each block of memory
  localparam BADDRW = $clog2(BMEMD);

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input                 clk;
`ifdef IS_AFU
  input                 rst;
`endif  

  output                pready;
  input                 pvalid;
  input    [PADDRW-1:0] paddr;
  input                 pwe;
  input    [PDATAW-1:0] pwdata;
  input                 plast;

  input                   fready;
  output                  fvalid;
  output     [PADDRW-1:0] faddr;
  output                  flast;
  output reg [FDATAW-1:0] fdata;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar gii;
  genvar gjj;
  genvar gkk;
  genvar gll;

  // --------------------------------------------------------------------------
  // Internal Signals
  //
`ifndef IS_AFU
  wire       rst;
`endif

  // Particle Memory
  wire              pmem_me;
  wire [PADDRW-1:0] pmem_addr_seqr;
  reg  [PADDRW-1:0] pmem_addr_seqr_d1;
  wire [PADDRW-1:0] pmem_addr;
  wire              pmem_segwe;
  wire [PDATAW-1:0] pmem_wdata;
  wire [PDATAW-1:0] pmem_rdata;

  wire [GADDRW1DX-1:0] px;
  wire [GADDRW1DY-1:0] py;
  wire [GADDRW1DZ-1:0] pz;
  wire       [OIW-1:0] poix;
  wire       [OIW-1:0] poiy;
  wire       [OIW-1:0] poiz;
  wire          [31:0] pq;

  // split particle memory readout
  wire [GADDRW1DX-1:0] r_px;
  wire [GADDRW1DY-1:0] r_py;
  wire [GADDRW1DZ-1:0] r_pz;
  wire       [OIW-1:0] r_poix;
  wire       [OIW-1:0] r_poiy;
  wire       [OIW-1:0] r_poiz;
  wire          [31:0] r_pq;

  // Charge Mapping
  wire                                                  ccoeff_valid;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] ccoeff;
  wire                                                  ccoord_valid;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] ccoordsx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] ccoordsy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] ccoordsz;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                ccoord_en;
 
  // Grid Memory
  wire                                                  gmem_clr;
  wire                                     [BADDRW-1:0] gmem_clr_addr;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_mew;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] gmem_wcoordsx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] gmem_wcoordsy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] gmem_wcoordsz;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_we;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]    [GELEW-1:0] gmem_wdata;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                gmem_mer;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] gmem_rcoordsx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] gmem_rcoordsy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] gmem_rcoordsz;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]    [GELEW-1:0] gmem_rdata;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] gmem_force_data;

  // Charge Mapping Accumulators
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] accum_real;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] accum_imag;

  // FFT Array Control / Status
  wire                                             fft_reset_n;
  wire                                   [FFTPW:0] fft_pts_in;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_valid;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_sop;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]           fft_sink_eop;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_sink_real;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_sink_imag;
  wire [NNN1D-1:0]                                 tplt_fft_source_valid;
  wire [NNN1D-1:0]                                 tplt_fft_source_sop;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_source_real;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][FPVW-1:0] fft_source_imag;

  // Green's Function
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] grom_coordsx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] grom_coordsy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] grom_coordsz;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] grom_rdata;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] green_real;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] green_imag;

  // Force Coefficient Generation
  wire                                                  ffpen;
  wire                                                  fmap_en;
  wire                                                  fcoeff_valid;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] fxcoeff;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] fycoeff;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [FPVW-1:0] fzcoeff;
  wire                                                  fcoord_valid;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] fcoordsx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] fcoordsy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] fcoordsz;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                fcoord_en;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                fcoord_en_d;

  wire                                     [FDATAW-1:0] force_reduction_result;

  wire                                                  stall;

  // --------------------------------------------------------------------------
  // Reset Generation
  //
`ifndef IS_AFU
  resetRelease u_resetRelease(.user_reset(rst), .user_clkgate());
`endif

  // --------------------------------------------------------------------------
  // Particle Memory
  //
  cfg_sp_rw_mem #(
    .BLKS   (32'd1),   // One subblock per grid memory block
    .BDEPTH (MAXNUMP), // Memory depth of all subblocks
    .SEGS   (1'd1),    // All entries of all subblocks are one segment wide
    .SEGW   (PDATAW),  // Segment width
    .RDTYPE (PMRDTYPE) // Readback timing type
  ) u_particle_mem (
    .clk   (clk),        // (I) Clock
    .me    (pmem_me),    // (I) Memory enable
    .addr  (pmem_addr),  // (I) Memory array address
    .segwe (pmem_segwe), // (I) Active high memory array entry segment write enable
    .wdata (pmem_wdata), // (I) Memory array entry write data
    .rdata (pmem_rdata)  // (O) Memory array entry read data
  );

  assign pq   = pmem_wdata[0                                    +: 32];

  assign poix = pmem_wdata[32                                   +: OIW];
  assign px   = pmem_wdata[(32+OIW)                             +: GADDRW1DX];

  assign poiy = pmem_wdata[(32+OIW+GADDRW1DX)                   +: OIW];
  assign py   = pmem_wdata[(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY];

  assign poiz = pmem_wdata[(32+OIW+GADDRW1DX+OIW+GADDRW1DY)     +: OIW];
  assign pz   = pmem_wdata[(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ];


  assign r_pq   = pmem_rdata[0                                    +: 32];

  assign r_poix = pmem_rdata[32                                   +: OIW];
  assign r_px   = pmem_rdata[(32+OIW)                             +: GADDRW1DX];

  assign r_poiy = pmem_rdata[(32+OIW+GADDRW1DX)                   +: OIW];
  assign r_py   = pmem_rdata[(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY];

  assign r_poiz = pmem_rdata[(32+OIW+GADDRW1DX+OIW+GADDRW1DY)     +: OIW];
  assign r_pz   = pmem_rdata[(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ];



  always @(posedge clk) begin : addr_dly
    if (rst) begin
      pmem_addr_seqr_d1 <= {PADDRW{1'b0}};
    end else begin
      if (stall) begin
        // Force pipeline stalled
        pmem_addr_seqr_d1 <= pmem_addr_seqr_d1;
      end else begin
        pmem_addr_seqr_d1 <= pmem_addr_seqr;
      end
    end
  end

  assign pmem_addr = stall ? pmem_addr_seqr_d1 : pmem_addr_seqr;

  // --------------------------------------------------------------------------
  // MD LR Sequencer
  //
  md_lr_seqr #(
    .GSIZE1DX  (GSIZE1DX),  // Size of X dimension of the grid
    .GSIZE1DY  (GSIZE1DY),  // Size of Y dimension of the grid
    .GSIZE1DZ  (GSIZE1DZ),  // Size of Z dimension of the grid
    .MAXNUMP   (MAXNUMP),   // Maximum number of particles
    .PDATAW    (PDATAW),    // Particle data width
    .NNN1D     (NNN1D),     // Number of nearest neighbors along one dimension
    .PMRDTYPE  (PMRDTYPE),  // Read delay timing of particle memory
    .GMRDTYPE  (GMRDTYPE),  // Read delay timing of grid mem blocks
    .FPADDDEL  (FPADDDEL),  // Latency of floating point addition
    .FPMULDEL  (FPMULDEL),  // Latency of floating point multiplication
    .GRNDEL    (GRNDEL),    // Latency of Green's function
    .FPVW      (FPVW),      // Width of floating point values
    .MAXFFTP   (MAXFFTP)    // Maximum number of FFT points
  ) u_md_lr_seqr (
    // Clocks and resets
    .rst (rst), // (I) Active high reset
    .clk (clk), // (I) Clock

    // Particle Memory Interface
    .pready (pready), // (O) Particle Memory ready
    .pvalid (pvalid), // (I) Particle Memory control valid
    .paddr  (paddr),  // (I) Particle Memory address
    .pwe    (pwe),    // (I) Particle Memory write enable
    .pwdata (pwdata), // (I) Particle Memory write data
    .plast  (plast),  // (I) Last particle data indicator

    .pmem_me    (pmem_me),    // (O) Particle memory enable
    .pmem_addr  (pmem_addr_seqr),  // (O) Particle memory array address
    .pmem_segwe (pmem_segwe), // (O) Active high memory array entry segment write enable
    .pmem_wdata (pmem_wdata), // (O) Particle memory array entry write data

    // Force Interface
    .fready (fready), // (I) Ready
    .fvalid (fvalid), // (O) Valid
    .faddr  (faddr),  // (O) Address
    .flast  (flast),  // (O) Last force data indicator

    // Charge Mapping
    .ccoeff_valid (ccoeff_valid), // (I) Coefficient data validation indicator

    .ccoord_valid (ccoord_valid), // (I) Coordinate informaton valid
    .ccoord_en    (ccoord_en),    // (I) Coordinate access enable
    .ccoordsx     (ccoordsx),     // (I) Coefficient x-coordinate
    .ccoordsy     (ccoordsy),     // (I) Coefficient y-coordinate
    .ccoordsz     (ccoordsz),     // (I) Coefficient z-coordinate

    // Charge Mapping Accumulators
    .accum_real (accum_real), // (I)
    .accum_imag (accum_imag), // (I)

    // Grid Memory Control
    .gmem_clr      (gmem_clr),      // (O) Grid memory clear signal
    .gmem_clr_addr (gmem_clr_addr), // (O) Grid memory clear address
    .gmem_mew      (gmem_mew),      // (O) Grid Memory write port enable
    .gmem_wcoordsx (gmem_wcoordsx), // (O) Grid Memory write x coordinates
    .gmem_wcoordsy (gmem_wcoordsy), // (O) Grid Memory write y coordinates
    .gmem_wcoordsz (gmem_wcoordsz), // (O) Grid Memory write z coordinates
    .gmem_we       (gmem_we),       // (O) Grid Memory segment write enable
    .gmem_wdata    (gmem_wdata),    // (O) Grid Memory write data

    .gmem_mer      (gmem_mer),      // (O) Grid Memory read port enable
    .gmem_rcoordsx (gmem_rcoordsx), // (O) Grid Memory read x coordinates
    .gmem_rcoordsy (gmem_rcoordsy), // (O) Grid Memory read y coordinates
    .gmem_rcoordsz (gmem_rcoordsz), // (O) Grid Memory read z coordinates
  
    // FFT Array Control Status
    .fft_reset_n           (fft_reset_n),           // (O)
    .fft_pts_in            (fft_pts_in),            // (O)
    .fft_sink_valid        (fft_sink_valid),        // (O)
    .fft_sink_sop          (fft_sink_sop),          // (O)
    .fft_sink_eop          (fft_sink_eop),          // (O)
    .tplt_fft_source_valid (tplt_fft_source_valid), // (I)
    .tplt_fft_source_sop   (tplt_fft_source_sop),   // (I)
    .fft_source_real       (fft_source_real),       // (I)
    .fft_source_imag       (fft_source_imag),       // (I)

    // Green's Function
    .grom_coordsx (grom_coordsx), // (O) Memory x coordinates
    .grom_coordsy (grom_coordsy), // (O) Memory y coordinates
    .grom_coordsz (grom_coordsz), // (O) Memory z coordinates

    .green_real   (green_real), // (I)
    .green_imag   (green_imag), // (I)

    // Force Mapping
    .ffpen        (ffpen),        // (O) Floating-point block enable
    .fmap_en      (fmap_en),      // (O) Particle data validation indicator
    .fcoeff_valid (fcoeff_valid), // (I) Coefficient data validation indicator

    .fcoord_valid (fcoord_valid), // (I) Coordinate information valid
    .fcoord_en    (fcoord_en),    // (I) Coordinate access enable
    .fcoordsx     (fcoordsx),     // (I) Coefficient x-coordinate
    .fcoordsy     (fcoordsy),     // (I) Coefficient y-coordinate
    .fcoordsz     (fcoordsz)      // (I) Coefficient z-coordinate
  );
  
  assign stall = fvalid & ~fready;

  // --------------------------------------------------------------------------
  // Particle-to-Grid Generator
  //
  coeffgen_3rdo #(
    .GSIZE1DX  (GSIZE1DX), // Size of x-dimension
    .GSIZE1DY  (GSIZE1DY), // Size of y-dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of z-dimension
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .OIW       (OIW),      // Width of oi values
    .TOFPDEL   (TOFPDEL),  // Latency of to-floating-point conversion block
    .FPMULDEL  (FPMULDEL), // Latency of floating-point multiplication block
    .FPADDDEL  (FPADDDEL), // Latency of floating-point addition block
    .CTYPE     (2'b00),    // Generator type
    .GMRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_charge_coeff_gen (
    // Clocks and resets
    .rst (rst), // (I) Active high reset 
    .clk (clk), // (I) Clock

    // Floating point control
    .fp_en (1'd1), // (I) Floating-point block enable

    // Particle information
    .pvalid (pmem_me), // (I) Particle data validation indicator
    .px     (px),      // (I) X coordinate
    .poix   (poix),    // (I) X-dimension oi value
    .py     (py),      // (I) Y coordinate
    .poiy   (poiy),    // (I) Y-dimension oi value
    .pz     (pz),      // (I) Z coordinate
    .poiz   (poiz),    // (I) Z-dimension oi value
    .pq     (pq),      // (I) Charge

    // Coefficient Information
    .coeff_valid (ccoeff_valid), // (O) Coefficient data validation indicator
    .coeff_data  (ccoeff),       // (O) Coefficient data

    .coord_valid (ccoord_valid), // (O) Coordinate information valid
    .coord_en    (ccoord_en),    // (O) Coordinate access enable
    .coordx      (ccoordsx),     // (O) Coefficient x-coordinate
    .coordy      (ccoordsy),     // (O) Coefficient y-coordinate
    .coordz      (ccoordsz)      // (O) Coefficient z-coordinate
  );

  // --------------------------------------------------------------------------
  // Grid Memory
  //
  clustered_grid_mem #(
    .GSIZE1DX (GSIZE1DX), // Size of X dimension of the grid
    .GSIZE1DY (GSIZE1DY), // Size of Y dimension of the grid
    .GSIZE1DZ (GSIZE1DZ), // Size of Z dimension of the grid
    .NNN1D    (NNN1D),    // Number of nearest neighbors along one dimension
    .GELEW    (GELEW),    // Bit width of each grid element
    .BRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_grid_mem (
    .rst      (rst),           // (I) Active high reset
    .clk      (clk),           // (I) Clock

    .clr      (gmem_clr),      // (I) Clear
    .clr_addr (gmem_clr_addr), // (I) Clear address

    .stall    (stall),         // (I) Pipeline Stall

    .mew      (gmem_mew),      // (I) Memory write port enable
    .wcoordsx (gmem_wcoordsx), // (I) Memory write x coordinates
    .wcoordsy (gmem_wcoordsy), // (I) Memory write y coordinates
    .wcoordsz (gmem_wcoordsz), // (I) Memory write z coordinates
    .we       (gmem_we),       // (I) Active high memory array entry segment write enable
    .wdata    (gmem_wdata),    // (I) Memory array entry write data

    .mer      (gmem_mer),      // (I) Memory read port enable
    .rcoordsx (gmem_rcoordsx), // (I) Memory read x coordinates
    .rcoordsy (gmem_rcoordsy), // (I) Memory read y coordinates
    .rcoordsz (gmem_rcoordsz), // (I) Memory read z coordinates
    .rdata    (gmem_rdata)     // (O) Memory array entry read data
  );

  // --------------------------------------------------------------------------
  // Charge Mapping Accumulators
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : nnn_accum_d0
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : nnn_accum_d1
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : nnn_accum_d2
        FpAdd u_real (
          .areset (rst),                                   // (I) Active high reset
          .clk    (clk),                                   // (I) Clock
          .en     (1'd1),                                  // (I) Enable
          .a      (ccoeff    [gii][gjj][gkk]),             // (I) Addend
          .b      (gmem_rdata[gii][gjj][gkk][FPVW+:FPVW]), // (I) Addend
          .q      (accum_real[gii][gjj][gkk])              // (O) Sum
        );
                                 
        assign accum_imag[gii][gjj][gkk] = {FPVW{1'd0}};
      end
    end
  end

  // --------------------------------------------------------------------------
  // FFT Array
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : fft_array_d0
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : fft_array_d1
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : fft_array_d2
        if ((gii == gjj) && (gjj == gkk) && (gkk == gii)) begin : diag
          fftIP u_fftIP (
            .clk          (clk),                             // (I)
            .reset_n      (fft_reset_n),                     // (I)
            .sink_valid   (fft_sink_valid[gii][gjj][gkk]),   // (I)
            .sink_ready   (),                                // (O)
            .sink_error   (2'd0),                            // (I)
            .sink_sop     (fft_sink_sop[gii][gjj][gkk]),     // (I)
            .sink_eop     (fft_sink_eop[gii][gjj][gkk]),     // (I)
            .sink_real    (fft_sink_real[gii][gjj][gkk]),    // (I)
            .sink_imag    (fft_sink_imag[gii][gjj][gkk]),    // (I)
            .fftpts_in    (fft_pts_in),                      // (I)
            .source_valid (tplt_fft_source_valid[gii]),      // (O)
            .source_ready (1'd1),                            // (I)
            .source_error (),                                // (O)
            .source_sop   (tplt_fft_source_sop[gii]),        // (O)
            .source_eop   (),                                // (O)
            .source_real  (fft_source_real[gii][gjj][gkk]),  // (O)
            .source_imag  (fft_source_imag[gii][gjj][gkk]),  // (O)
            .fftpts_out   ()                                 // (O)
          );

          // Use unregistered version to reduce latency. May need to revist if
          // this is found to be on the critical path.
          assign fft_sink_imag[gii][gjj][gkk] = gmem_rdata[gii][gjj][gkk][   0+:FPVW];
          assign fft_sink_real[gii][gjj][gkk] = gmem_rdata[gii][gjj][gkk][FPVW+:FPVW];
        end else begin : non_diag
          fftIP u_fftIP (
            .clk          (clk),                             // (I)
            .reset_n      (fft_reset_n),                     // (I)
            .sink_valid   (fft_sink_valid[gii][gjj][gkk]),   // (I)
            .sink_ready   (),                                // (O)
            .sink_error   (2'd0),                            // (I)
            .sink_sop     (fft_sink_sop[gii][gjj][gkk]),     // (I)
            .sink_eop     (fft_sink_eop[gii][gjj][gkk]),     // (I)
            .sink_real    (fft_sink_real[gii][gjj][gkk]),    // (I)
            .sink_imag    (fft_sink_imag[gii][gjj][gkk]),    // (I)
            .fftpts_in    (fft_pts_in),                      // (I)
            .source_valid (),                                // (O)
            .source_ready (1'd1),                            // (I)
            .source_error (),                                // (O)
            .source_sop   (),                                // (O)
            .source_eop   (),                                // (O)
            .source_real  (fft_source_real[gii][gjj][gkk]),  // (O)
            .source_imag  (fft_source_imag[gii][gjj][gkk]),  // (O)
            .fftpts_out   ()                                 // (O)
          );

          // Use unregistered version to reduce latency. May need to revist if
          // this is found to be on the critical path.
          assign fft_sink_imag[gii][gjj][gkk] = gmem_rdata[gii][gjj][gkk][   0+:FPVW];
          assign fft_sink_real[gii][gjj][gkk] = gmem_rdata[gii][gjj][gkk][FPVW+:FPVW];
        end
      end
    end
  end
  
  // --------------------------------------------------------------------------
  // Green's Function
  //
  clustered_greens_rom #(
    .GSIZE1DX (GSIZE1DX), // Size of X dimension of the grid
    .GSIZE1DY (GSIZE1DY), // Size of Y dimension of the grid
    .GSIZE1DZ (GSIZE1DZ), // Size of Z dimension of the grid
    .NNN1D    (NNN1D),    // Number of nearest neighbors along one dimension
    .GELEW    (FPVW),     // Bit width of each grid element
    .BRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_greens_rom (
    .rst     (rst),           // (I) Active high reset
    .clk     (clk),           // (I) Clock
    .me      ({NNN3D{1'd1}}), // (I) Memory port enable
    .coordsx (grom_coordsx),  // (I) Memory x coordinates
    .coordsy (grom_coordsy),  // (I) Memory y coordinates
    .coordsz (grom_coordsz),  // (I) Memory z coordinates
    .rdata   (grom_rdata)     // (O) Memory array entry data
  );
  
  for (gii=0; gii<NNN1D; gii=gii+1) begin : green_nnn_d0
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : green_nnn_d1
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : green_nnn_d2

        FpMul u_mul_real (
          .areset (rst),                            // (I) Active high reset
          .clk    (clk),                            // (I) Clock
          .en     (1'd1),                           // (I) Enable
          .a      (grom_rdata[gii][gjj][gkk]),      // (I) Multiplicand
          .b      (fft_source_real[gii][gjj][gkk]), // (I) Multiplicand
          .q      (green_real[gii][gjj][gkk])       // (O) Product
        );
 
        FpMul u_mul_imag (
          .areset (rst),                            // (I) Active high reset
          .clk    (clk),                            // (I) Clock
          .en     (1'd1),                           // (I) Enable
          .a      (grom_rdata[gii][gjj][gkk]),      // (I) Multiplicand
          .b      (fft_source_imag[gii][gjj][gkk]), // (I) Multiplicand
          .q      (green_imag[gii][gjj][gkk])       // (O) Product
        );
      end
    end
  end

  // --------------------------------------------------------------------------
  // Force Coefficient Generators
  //
  // Separate coefficient generators for each dimension, but are sync'ed
  // together. Use only one set of validation, enable, and coordinate outputs.
  //
  coeffgen_3rdo #(
    .GSIZE1DX  (GSIZE1DX), // Size of x-dimension
    .GSIZE1DY  (GSIZE1DY), // Size of y-dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of z-dimension
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .OIW       (OIW),      // Width of oi values
    .TOFPDEL   (TOFPDEL),  // Latency of to-floating-point conversion block
    .FPMULDEL  (FPMULDEL), // Latency of floating-point multiplication block
    .FPADDDEL  (FPADDDEL), // Latency of floating-point addition block
    .CTYPE     (2'b01),    // Generator type
    .GMRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_fxcoeff_coeff_gen (
    // Clocks and resets
    .rst (rst), // (I) Active high reset 
    .clk (clk), // (I) Clock

    // Floating point control
    .fp_en (ffpen), // (I) Floating-point block enable

    // Particle information
    .pvalid (fmap_en), // (I) Particle data validation indicator
    .px     (r_px),      // (I) X coordinate
    .poix   (r_poix),    // (I) X-dimension oi value
    .py     (r_py),      // (I) Y coordinate
    .poiy   (r_poiy),    // (I) Y-dimension oi value
    .pz     (r_pz),      // (I) Z coordinate
    .poiz   (r_poiz),    // (I) Z-dimension oi value
    .pq     (32'd0),   // (I) Charge

    // Coefficient Information
    .coeff_valid (fcoeff_valid), // (O) Coefficient data validation indicator
    .coeff_data  (fxcoeff),      // (O) Coefficient data
 
    .coord_valid (fcoord_valid), // (O) Coordinate information valid
    .coord_en    (fcoord_en),    // (O) Coordinate access enable
    .coordx      (fcoordsx),     // (O) Coefficient x-coordinate
    .coordy      (fcoordsy),     // (O) Coefficient y-coordinate
    .coordz      (fcoordsz)      // (O) Coefficient z-coordinate
  );

  coeffgen_3rdo #(
    .GSIZE1DX  (GSIZE1DX), // Size of x-dimension
    .GSIZE1DY  (GSIZE1DY), // Size of y-dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of z-dimension
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .OIW       (OIW),      // Width of oi values
    .TOFPDEL   (TOFPDEL),  // Latency of to-floating-point conversion block
    .FPMULDEL  (FPMULDEL), // Latency of floating-point multiplication block
    .FPADDDEL  (FPADDDEL), // Latency of floating-point addition block
    .CTYPE     (2'b10),    // Generator type
    .GMRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_fycoeff_coeff_gen (
    // Clocks and resets
    .rst (rst), // (I) Active high reset 
    .clk (clk), // (I) Clock

    // Floating point control
    .fp_en (ffpen), // (I) Floating-point block enable

    // Particle information
    .pvalid (fmap_en), // (I) Particle data validation indicator
    .px     (r_px),      // (I) X coordinate
    .poix   (r_poix),    // (I) X-dimension oi value
    .py     (r_py),      // (I) Y coordinate
    .poiy   (r_poiy),    // (I) Y-dimension oi value
    .pz     (r_pz),      // (I) Z coordinate
    .poiz   (r_poiz),    // (I) Z-dimension oi value
    .pq     (32'd0),   // (I) Charge

    // Coefficient Information
    .coeff_valid (),        // (O) Coefficient data validation indicator
    .coeff_data  (fycoeff), // (O) Coefficient data

    .coord_valid (), // (O) Coordinate information valid
    .coord_en    (), // (O) Coordinate access enable
    .coordx      (), // (O) Coefficient x-coordinate
    .coordy      (), // (O) Coefficient y-coordinate
    .coordz      ()  // (O) Coefficient z-coordinate
  );

  coeffgen_3rdo #(
    .GSIZE1DX  (GSIZE1DX), // Size of x-dimension
    .GSIZE1DY  (GSIZE1DY), // Size of y-dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of z-dimension
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .OIW       (OIW),      // Width of oi values
    .TOFPDEL   (TOFPDEL),  // Latency of to-floating-point conversion block
    .FPMULDEL  (FPMULDEL), // Latency of floating-point multiplication block
    .FPADDDEL  (FPADDDEL), // Latency of floating-point addition block
    .CTYPE     (2'b11),    // Generator type
    .GMRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) u_fzcoeff_coeff_gen (
    // Clocks and resets
    .rst (rst), // (I) Active high reset 
    .clk (clk), // (I) Clock

    // Floating point control
    .fp_en (ffpen), // (I) Floating-point block enable

    // Particle information
    .pvalid (fmap_en), // (I) Particle data validation indicator
    .px     (r_px),      // (I) X coordinate
    .poix   (r_poix),    // (I) X-dimension oi value
    .py     (r_py),      // (I) Y coordinate
    .poiy   (r_poiy),    // (I) Y-dimension oi value
    .pz     (r_pz),      // (I) Z coordinate
    .poiz   (r_poiz),    // (I) Z-dimension oi value
    .pq     (32'd0),   // (I) Charge

    // Coefficient Information
    .coeff_valid (),        // (O) Coefficient data validation indicator
    .coeff_data  (fzcoeff), // (O) Coefficient data

    .coord_valid (), // (O) Coordinate information valid
    .coord_en    (), // (O) Coordinate access enable
    .coordx      (), // (O) Coefficient x-coordinate
    .coordy      (), // (O) Coefficient y-coordinate
    .coordz      ()  // (O) Coefficient z-coordinate
  );

  // --------------------------------------------------------------------------
  // Force Reduction Trees
  //
  // Grid memory still returns non-zero data even when read enables are
  // de-asserted.
  //
  // Delay fcoord_en by the time number of clock cyles it takes to get read
  // data out of the grid memory following the assertion of fcoord_en. Use the
  // delayed version as a mux select between zeros and the grid memory's read
  // data.
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : grid_force_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : grid_force_y
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : grid_force_x
        customdelay #(.DELAY(GMRBDEL+1), .WIDTH(32'd1)) u_delay (
          .clk   (clk),                        // (I) Clock
          .rst   (rst),                        // (I) Reset
          .stall (stall),                      // (I) Pipeline Stall
          .x     (fcoord_en  [gii][gjj][gkk]), // (I) Input to be delayed
          .y     (fcoord_en_d[gii][gjj][gkk])  // (O) Output
        );

        assign gmem_force_data[gii][gjj][gkk] = fcoord_en_d[gii][gjj][gkk] ?
                                                gmem_rdata[gii][gjj][gkk][FPVW+:FPVW] :
                                                {FPVW{1'b0}};
      end
    end
  end

  Reduction_Tree u_fx_tree (
    .clk      (clk),            // (I) Clock
    .rst      (rst),            // (I) Reset 
    .fp_en    (ffpen),          // (I) Floating point enable
    .out_port (force_reduction_result[31:0]),    // (O) 
    .in_port1 (fxcoeff),        // (I)
    .in_port2 (gmem_force_data) // (I)
  );
    
  Reduction_Tree u_fy_tree (
    .clk      (clk),            // (I) Clock
    .rst      (rst),            // (I) Reset 
    .fp_en    (ffpen),          // (I) Floating point enable
    .out_port (force_reduction_result[63:32]),   // (O) 
    .in_port1 (fycoeff),        // (I)
    .in_port2 (gmem_force_data) // (I)
  );
    
  Reduction_Tree u_fz_tree (
    .clk      (clk),            // (I) Clock
    .rst      (rst),            // (I) Reset 
    .fp_en    (ffpen),          // (I) Floating point enable
    .out_port (force_reduction_result[95:64]),   // (O) 
    .in_port1 (fzcoeff),        // (I)
    .in_port2 (gmem_force_data) // (I)
  );

  always @(posedge clk) begin : fdata_del_seq
    if (rst) begin
      fdata <= {FDATAW{1'd0}};
    end else begin
      if (stall) begin
        fdata <= fdata;
      end else begin
        fdata <= force_reduction_result;
      end
    end
  end

endmodule // md_lr_top
