// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : wrapped_md_lr_top.sv
// Description    : Top-Level MD LR module wrapped to have partile info in
//                  ROM and store force info in RAM.
// 
// ============================================================================

module wrapped_md_lr_top (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  clk,    // (I) Clock

  fxxor,
  fyxor,
  fzxor
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

  // Force Data Width
  localparam FDATAW = 32'd96;
  
  localparam MAXNUMPM1 = MAXNUMP - 32'd1;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input  clk;

  output fxxor;
  output fyxor;
  output fzxor;

  // --------------------------------------------------------------------------
  // Internals Signal Declarations
  //
  genvar gii;

  wire rst;

  reg  [PADDRW-1:0] prom_addr;

  //wire              pready;
  reg               pvalid;
  reg  [PADDRW-1:0] paddr;
  reg               pwe;
  wire [PDATAW-1:0] pwdata;
  wire              plast;

  //reg               fready;
  wire              fvalid;
  wire [PADDRW-1:0] faddr;
  //wire              flast;
  wire [FDATAW-1:0] fwdata;
  wire [FDATAW-1:0] frdata;

  reg [8:0] fx_rdata_xor;
  reg [8:0] fy_rdata_xor;
  reg [8:0] fz_rdata_xor;

  // --------------------------------------------------------------------------
  // Reset Generation
  //
  resetRelease u_resetRelease(.user_reset(rst), .user_clkgate());

  // --------------------------------------------------------------------------
  // Particle Information ROM
  //
  `include "../tb/include/particle_info.svh"

  cfg_sp_ro_mem #(
    .BLKS   (32'd1),    // One subblock per grid memory block
    .BDEPTH (MAXNUMP),  // Memory depth of all subblocks
    .SEGS   (1'd1),     // All entries of all subblocks are one segement wide
    .SEGW   (PDATAW),   // Segement width
    .RDTYPE (PMRDTYPE), // Readback timing type
    .ROMVAL (P_INFO)    // ROM bits

  ) u_pinfo_rom (
    .clk   (clk),       // (I) Clock
    .me    (1'd1),      // (I) Memory enable
    .addr  (prom_addr), // (I) Memory array address
    .rdata (pwdata)     // (O) Memory array entry read data
  );

  // --------------------------------------------------------------------------
  // Particle ROM Readout Logic
  //
  always @(posedge clk) begin : prom_ctrl_seq
    if (rst) begin
      prom_addr <= {PADDRW{1'd0}};
      paddr     <= {PADDRW{1'd0}};
      pvalid    <= 1'd0;
      pwe       <= 1'd0;
    end else begin
      prom_addr <= prom_addr + {{(PADDRW-1){1'd0}}, 1'd1};
      paddr     <= prom_addr;
      pvalid    <= 1'd1;
      pwe       <= 1'd1;
    end
  end

  assign plast = (paddr == MAXNUMPM1[PADDRW-1:0]);

  // --------------------------------------------------------------------------
  // Accellerator
  //
  md_lr_top #(
    .GSIZE1DX  (GSIZE1DX), // Size of the X dimension
    .GSIZE1DY  (GSIZE1DY), // Size of the Y dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of the Z dimension
    .MAXNUMP   (MAXNUMP),  // Maximum number of particles
    .PMRDTYPE  (PMRDTYPE), // Read delay timing of particle memory
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .GMRDTYPE  (GMRDTYPE)  // Read delay timing of grid mem blocks
  ) DUT (
    // Clocks and resets
    .clk (clk),    // (I) Clock

    // Particle Memory Interface
    .pready (), // (O) Particle Memory ready
    .pvalid (pvalid), // (I) Particle Memory control valid
    .paddr  (paddr),  // (I) Particle Memory address
    .pwe    (pwe),    // (I) Particle Memory write enable
    .pwdata (pwdata), // (I) Particle Memory write data
    .plast  (plast),  // (I) Last particle data indicator
  
    // Force Memory Interface
    .fready (1'd1),   // (I) Force ready
    .fvalid (fvalid), // (O) Force valid
    .faddr  (faddr),  // (O) Force address
    .flast  (),  // (O) Last particle data indicator
    .fdata  (fwdata)  // (O) Force read data
  );

  // --------------------------------------------------------------------------
  // Force RAM
  //
  cfg_sp_rw_mem #(
    .BLKS   (32'd1),   // One subblock per grid memory block
    .BDEPTH (MAXNUMP), // Memory depth of all subblocks
    .SEGS   (1'd1),    // All entries of all subblocks are one segment wide
    .SEGW   (FDATAW),  // Segment width
    .RDTYPE (PMRDTYPE) // Readback timing type
  ) u_force_mem (
    .clk   (clk),    // (I) Clock
    .me    (fvalid), // (I) Memory enable
    .addr  (faddr),  // (I) Memory array address
    .segwe (fvalid), // (I) Active high memory array entry segment write enable
    .wdata (fwdata), // (I) Memory array entry write data
    .rdata (frdata)  // (O) Memory array entry read data
  );

  // --------------------------------------------------------------------------
  // Force Result Reduction and Pipeline
  //
  always @* begin : force_redux_cmb
    fx_rdata_xor[0] = ^frdata[31:0];
    fy_rdata_xor[0] = ^frdata[63:32];
    fz_rdata_xor[0] = ^frdata[95:64];
  end

  for (gii=1; gii<9; gii=gii+1) begin : stage
    always @(posedge clk) begin
      if (rst) begin
        fx_rdata_xor[gii] <= 1'd0;
        fy_rdata_xor[gii] <= 1'd0;
        fz_rdata_xor[gii] <= 1'd0;
      end else begin
        fx_rdata_xor[gii] <= fx_rdata_xor[gii-1];
        fy_rdata_xor[gii] <= fy_rdata_xor[gii-1];
        fz_rdata_xor[gii] <= fz_rdata_xor[gii-1];
      end
    end
  end

  assign fxxor = fx_rdata_xor[8];
  assign fyxor = fy_rdata_xor[8];
  assign fzxor = fz_rdata_xor[8];  
endmodule
