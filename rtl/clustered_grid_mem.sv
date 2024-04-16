// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : clustered_grid_mem.sv
// Description    : Configurable grid memory
// 
// ============================================================================

module clustered_grid_mem (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  rst,      // (I) Active high Reset
  clk,      // (I) Clock

  clr,      // (I) clear memory contents
  clr_addr, // (I) clear address

  stall,    // (I) Pipeline Stall
  mew,      // (I) Memory write port enable
  wcoordsx, // (I) Memory write x coordinates
  wcoordsy, // (I) Memory write y coordinates
  wcoordsz, // (I) Memory write z coordinates
  we,       // (I) Active high memory array entry segment write enable
  wdata,    // (I) Memory array entry write data

  mer,      // (I) Memory read port enable
  rcoordsx, // (I) Memory read x coordinates
  rcoordsy, // (I) Memory read y coordinates
  rcoordsz, // (I) Memory read z coordinates
  rdata     // (O) Memory array entry read data
);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // 1D Grid Dimensions
  parameter GSIZE1DX = 32'd32;
  parameter GSIZE1DY = 32'd32;
  parameter GSIZE1DZ = 32'd32;
  
  // Number of nearest neighbors along one dimension
  parameter NNN1D = 32'd4;
  
  // Bit width of each grid element
  parameter GELEW = 32'd64;

  // Read delay timing of grid mem blocks
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] BRDTYPE = 2'd0;
  
  // --------------------------------------------------------------------------
  // Derived Parameters
  //
  // Grid size in 3D
  localparam GSIZE3D = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Width of grid address in one dimension
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);
  
  // Number of nearest neighbors in 3D
  localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // The size of the grid divided by the number of nearest neighbors will serve
  // as the depth of each memory block
  localparam BMEMD = GSIZE3D / NNN3D;
  
  // Address width of each block of memory
  localparam BADDRW = $clog2(BMEMD);
    
  // Address width of nearest neighbor in one dimension
  localparam NN1DIDW = $clog2(NNN1D);
  
  // Address widths of cluster location in 1D for each dimension
  localparam CIDXW = GADDRW1DY - NN1DIDW;
  localparam CIDYW = GADDRW1DY - NN1DIDW;
  localparam CIDZW = GADDRW1DZ - NN1DIDW;
  
  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input                                                        rst;
  input                                                        clk;

  input                                                        clr;
  input                                           [BADDRW-1:0] clr_addr;

  input                                                        stall;

  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                 mew;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DX-1:0] wcoordsx;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DY-1:0] wcoordsy;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DZ-1:0] wcoordsz;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                 we;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [GELEW-1:0] wdata;

  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                 mer;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DX-1:0] rcoordsx;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DY-1:0] rcoordsy;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [GADDRW1DZ-1:0] rcoordsz;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]     [GELEW-1:0] rdata;

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
  // Coordinate Reorganization
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] wcoordsx_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] wcoordsy_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] wcoordsz_msbs;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsx_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsy_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsz_lsbs;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] rcoordsx_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsy_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] rcoordsz_msbs;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsx_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs;

  // Memory Control Rotational Shifting X
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mew_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              we_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] wcoordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] wcoordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] wcoordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] wdata_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mer_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] rcoordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsx_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_d1;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mew_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_we_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_wcoordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_wcoordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_wcoordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_wcoordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_wcoordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] nxt_wdata_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mer_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_rcoordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_rcoordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_rcoordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsx_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsy_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsz_lsbs_d1;

  // Memory Control Rotational Shifting Y
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mew_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              we_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] wcoordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] wcoordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] wcoordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] wcoordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] wdata_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mer_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] rcoordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] rcoordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsx_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_d2;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mew_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_we_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_wcoordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_wcoordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_wcoordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_wcoordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] nxt_wdata_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mer_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_rcoordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_rcoordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_rcoordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsx_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsy_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsz_lsbs_d2;

  // Memory Control Rotational Shifting Z
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mew_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              we_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] wcoordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] wcoordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] wcoordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] wdata_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              mer_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] rcoordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] rcoordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] rcoordsx_msbs_rotxyz_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] rcoordsy_msbs_rotxyz_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] rcoordsz_msbs_rotxyz_d1;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsx_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_d3;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsx_lsbs_d3_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsy_lsbs_d3_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] rcoordsz_lsbs_d3_d1;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mew_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_we_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_wcoordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_wcoordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_wcoordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] nxt_wdata_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_mer_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_rcoordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_rcoordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_rcoordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsx_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsy_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_rcoordsz_lsbs_d3;

  // Grid Memory Blocks
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [BADDRW-1:0] block_waddr;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [BADDRW-1:0] block_raddr;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsx_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsy_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsz_lsbs;

  // Grid memory block write port signals
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [BADDRW-1:0] memblk_waddr;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] memblk_wdata;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              memblk_mew;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              memblk_we;

  // Register clear signals
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]               clear;
  reg                                    [BADDRW-1:0] clear_addr;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]               nxt_clear;
  reg                                    [BADDRW-1:0] nxt_clear_addr;

  // Memory Read Data Rotational Shifting
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata_rotz;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsx_lsbs_rotz;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsy_lsbs_rotz;

  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata_rotzy;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_rcoordsx_lsbs_rotzy;

`ifndef SYNTHESIS
  // Assertion disable
  reg disable_assert;
`endif


  // --------------------------------------------------------------------------
  // Register clear signals
  //
  always @(posedge clk)begin: reg_clear_sig_seq
    if(rst)begin
      clear      <= 1'b0;
      clear_addr <= {BADDRW{1'b0}};
    end
    else begin
      clear      <= nxt_clear;
      clear_addr <= nxt_clear_addr;
    end
  end 

  always @(*)begin: reg_clear_sig_comb
    if(clr)begin
      nxt_clear      <= 1'b1;
      nxt_clear_addr <= clr_addr;
    end
    else begin
      nxt_clear      <= 1'b0;
      nxt_clear_addr <= {BADDRW{1'b0}};
    end
  end


  // --------------------------------------------------------------------------
  // Coordinate Reorganization
  //
  // Split up coordinates into:
  //  o MSBs used to index into neighbor memories
  //  o LSBs used for routing to neighbor memory
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : coord_reorg_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : coord_reorg_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : coord_reorg_x
        assign wcoordsx_msbs[gkk][gjj][gii] = wcoordsx[gkk][gjj][gii][NN1DIDW+:CIDXW];
        assign wcoordsx_lsbs[gkk][gjj][gii] = wcoordsx[gkk][gjj][gii][NN1DIDW-1:0];

        assign wcoordsy_msbs[gkk][gjj][gii] = wcoordsy[gkk][gjj][gii][NN1DIDW+:CIDYW];
        assign wcoordsy_lsbs[gkk][gjj][gii] = wcoordsy[gkk][gjj][gii][NN1DIDW-1:0];

        assign wcoordsz_msbs[gkk][gjj][gii] = wcoordsz[gkk][gjj][gii][NN1DIDW+:CIDZW];
        assign wcoordsz_lsbs[gkk][gjj][gii] = wcoordsz[gkk][gjj][gii][NN1DIDW-1:0];

        assign rcoordsx_msbs[gkk][gjj][gii] = rcoordsx[gkk][gjj][gii][NN1DIDW+:CIDXW];
        assign rcoordsx_lsbs[gkk][gjj][gii] = rcoordsx[gkk][gjj][gii][NN1DIDW-1:0];

        assign rcoordsy_msbs[gkk][gjj][gii] = rcoordsy[gkk][gjj][gii][NN1DIDW+:CIDYW];
        assign rcoordsy_lsbs[gkk][gjj][gii] = rcoordsy[gkk][gjj][gii][NN1DIDW-1:0];

        assign rcoordsz_msbs[gkk][gjj][gii] = rcoordsz[gkk][gjj][gii][NN1DIDW+:CIDZW];
        assign rcoordsz_lsbs[gkk][gjj][gii] = rcoordsz[gkk][gjj][gii][NN1DIDW-1:0];

`ifndef SYNTHESIS
        genvar gmm;
        genvar gnn;
        
        wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] nn_oh_wdec;
        wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] nn_oh_rdec;

        for (gnn=0; gnn<NNN1D; gnn=gnn+1) begin : nnportz
          for (gmm=0; gmm<NNN1D; gmm=gmm+1) begin : nnporty
            for (gll=0; gll<NNN1D; gll=gll+1) begin : nnportx
              assign nn_oh_wdec[gnn][gmm][gll] = ((gkk[NN1DIDW-1:0] == wcoordsz_lsbs[gnn][gmm][gll]) &&
                                                  (gjj[NN1DIDW-1:0] == wcoordsy_lsbs[gnn][gmm][gll]) &&
                                                  (gii[NN1DIDW-1:0] == wcoordsx_lsbs[gnn][gmm][gll])) &
                                                 mew[gnn][gmm][gll];

              assign nn_oh_rdec[gnn][gmm][gll] = ((gkk[NN1DIDW-1:0] == rcoordsz_lsbs[gnn][gmm][gll]) &&
                                                  (gjj[NN1DIDW-1:0] == rcoordsy_lsbs[gnn][gmm][gll]) &&
                                                  (gii[NN1DIDW-1:0] == rcoordsx_lsbs[gnn][gmm][gll])) &
                                                 mer[gnn][gmm][gll];

            end
          end
        end

      ASSERT_INVALID_CLUSTER_WCOORDS: assert property (
        @(negedge clk)
        disable iff(disable_assert)
        $onehot0(nn_oh_wdec)
      )
      else
        $error("nn_oh_wdec == %0b", nn_oh_wdec);

      ASSERT_INVALID_CLUSTER_RCOORDS: assert property (
        @(negedge clk)
        disable iff(disable_assert)
        $onehot0(nn_oh_rdec)
      )
      else
        $error("nn_oh_rdec == %0b", nn_oh_rdec);
`endif
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Control Rotational Shifting X
  //
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mcrsx_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mcrsx_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mcrsx_x
        wire [NNN1D-1:0] nn_oh_wdecx;
        wire [NNN1D-1:0] nn_oh_rdecx;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportx
          assign nn_oh_wdecx[gll] = (gii[NN1DIDW-1:0] == wcoordsx_lsbs[gkk][gjj][gll]) & mew[gkk][gjj][gll];
          assign nn_oh_rdecx[gll] = (gii[NN1DIDW-1:0] == rcoordsx_lsbs[gkk][gjj][gll]) & mer[gkk][gjj][gll];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_WCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_wdecx))
        )
        else
          $error("nn_oh_wdecx == %0b", nn_oh_wdecx);

        ASSERT_INVALID_CLUSTER_RCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_rdecx))
        )
        else
          $error("nn_oh_rdecx == %0b", nn_oh_rdecx);
`endif

        always @(posedge clk) begin : wctrl_mux_seq
          if (rst) begin
            mew_rotx[gkk][gjj][gii]           <= 1'd0;
            we_rotx[gkk][gjj][gii]            <= 1'd0;

            wcoordsx_msbs_rotx[gkk][gjj][gii] <= {CIDXW{1'd0}};
            wcoordsy_msbs_rotx[gkk][gjj][gii] <= {CIDYW{1'd0}};
            wcoordsz_msbs_rotx[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            wcoordsy_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            wcoordsz_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            
            wdata_rotx[gkk][gjj][gii]         <= {GELEW{1'd0}};
          end else begin
            mew_rotx[gkk][gjj][gii]           <= nxt_mew_rotx[gkk][gjj][gii];
            we_rotx[gkk][gjj][gii]            <= nxt_we_rotx[gkk][gjj][gii];

            wcoordsx_msbs_rotx[gkk][gjj][gii] <= nxt_wcoordsx_msbs_rotx[gkk][gjj][gii];
            wcoordsy_msbs_rotx[gkk][gjj][gii] <= nxt_wcoordsy_msbs_rotx[gkk][gjj][gii];
            wcoordsz_msbs_rotx[gkk][gjj][gii] <= nxt_wcoordsz_msbs_rotx[gkk][gjj][gii];
            
            wcoordsy_lsbs_rotx[gkk][gjj][gii] <= nxt_wcoordsy_lsbs_rotx[gkk][gjj][gii];
            wcoordsz_lsbs_rotx[gkk][gjj][gii] <= nxt_wcoordsz_lsbs_rotx[gkk][gjj][gii];
            
            wdata_rotx[gkk][gjj][gii]         <= nxt_wdata_rotx[gkk][gjj][gii];
          end
        end

        always @* begin : wctrl_mux_comb
          nxt_mew_rotx[gkk][gjj][gii]           = 1'd0;
          nxt_we_rotx[gkk][gjj][gii]            = 1'd0;

          nxt_wcoordsx_msbs_rotx[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_wcoordsy_msbs_rotx[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_wcoordsz_msbs_rotx[gkk][gjj][gii] = {CIDZW{1'd0}};
            
          nxt_wcoordsy_lsbs_rotx[gkk][gjj][gii] = {NN1DIDW{1'd0}};
          nxt_wcoordsz_lsbs_rotx[gkk][gjj][gii] = {NN1DIDW{1'd0}};
            
          nxt_wdata_rotx[gkk][gjj][gii]         = {GELEW{1'd0}};

          for (integer iii=0; iii<NNN1D; iii=iii+1) begin
            if (nn_oh_wdecx[iii]) begin
              nxt_mew_rotx[gkk][gjj][gii]           = mew[gkk][gjj][iii];
              nxt_we_rotx[gkk][gjj][gii]            = we[gkk][gjj][iii];
              
              nxt_wcoordsx_msbs_rotx[gkk][gjj][gii] = wcoordsx_msbs[gkk][gjj][iii];
              nxt_wcoordsy_msbs_rotx[gkk][gjj][gii] = wcoordsy_msbs[gkk][gjj][iii];
              nxt_wcoordsz_msbs_rotx[gkk][gjj][gii] = wcoordsz_msbs[gkk][gjj][iii];
              
              nxt_wcoordsy_lsbs_rotx[gkk][gjj][gii] = wcoordsy_lsbs[gkk][gjj][iii];
              nxt_wcoordsz_lsbs_rotx[gkk][gjj][gii] = wcoordsz_lsbs[gkk][gjj][iii];
              
              nxt_wdata_rotx[gkk][gjj][gii]         = wdata[gkk][gjj][iii];
            end
          end
        end

        always @(posedge clk) begin : rctrl_mux_seq
          if (rst) begin
            mer_rotx[gkk][gjj][gii]           <= 1'd0;
            
            rcoordsx_msbs_rotx[gkk][gjj][gii] <= {CIDXW{1'd0}};
            rcoordsy_msbs_rotx[gkk][gjj][gii] <= {CIDYW{1'd0}};
            rcoordsz_msbs_rotx[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            rcoordsy_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            rcoordsz_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};

            rcoordsx_lsbs_d1[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsy_lsbs_d1[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsz_lsbs_d1[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
          end else begin
            mer_rotx[gkk][gjj][gii]           <= nxt_mer_rotx[gkk][gjj][gii];
            
            rcoordsx_msbs_rotx[gkk][gjj][gii] <= nxt_rcoordsx_msbs_rotx[gkk][gjj][gii];
            rcoordsy_msbs_rotx[gkk][gjj][gii] <= nxt_rcoordsy_msbs_rotx[gkk][gjj][gii];
            rcoordsz_msbs_rotx[gkk][gjj][gii] <= nxt_rcoordsz_msbs_rotx[gkk][gjj][gii];
            
            rcoordsy_lsbs_rotx[gkk][gjj][gii] <= nxt_rcoordsy_lsbs_rotx[gkk][gjj][gii];
            rcoordsz_lsbs_rotx[gkk][gjj][gii] <= nxt_rcoordsz_lsbs_rotx[gkk][gjj][gii];

            rcoordsx_lsbs_d1[gkk][gjj][gii]   <= nxt_rcoordsx_lsbs_d1[gkk][gjj][gii];
            rcoordsy_lsbs_d1[gkk][gjj][gii]   <= nxt_rcoordsy_lsbs_d1[gkk][gjj][gii];
            rcoordsz_lsbs_d1[gkk][gjj][gii]   <= nxt_rcoordsz_lsbs_d1[gkk][gjj][gii];
          end
        end

        always @* begin : rctrl_mux_comb
          if (stall) begin
            nxt_mer_rotx[gkk][gjj][gii]           = mer_rotx[gkk][gjj][gii];
            
            nxt_rcoordsx_msbs_rotx[gkk][gjj][gii] = rcoordsx_msbs_rotx[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotx[gkk][gjj][gii] = rcoordsy_msbs_rotx[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotx[gkk][gjj][gii] = rcoordsz_msbs_rotx[gkk][gjj][gii];
            
            nxt_rcoordsy_lsbs_rotx[gkk][gjj][gii] = rcoordsy_lsbs_rotx[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_rotx[gkk][gjj][gii] = rcoordsz_lsbs_rotx[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d1[gkk][gjj][gii]   = rcoordsx_lsbs_d1[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d1[gkk][gjj][gii]   = rcoordsy_lsbs_d1[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d1[gkk][gjj][gii]   = rcoordsz_lsbs_d1[gkk][gjj][gii];
          end else begin
            nxt_mer_rotx[gkk][gjj][gii]           = 1'd0;
            
            nxt_rcoordsx_msbs_rotx[gkk][gjj][gii] = rcoordsx_msbs_rotx[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotx[gkk][gjj][gii] = rcoordsy_msbs_rotx[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotx[gkk][gjj][gii] = rcoordsz_msbs_rotx[gkk][gjj][gii];
            
            nxt_rcoordsy_lsbs_rotx[gkk][gjj][gii] = rcoordsy_lsbs_rotx[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_rotx[gkk][gjj][gii] = rcoordsz_lsbs_rotx[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d1[gkk][gjj][gii]   = rcoordsx_lsbs[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d1[gkk][gjj][gii]   = rcoordsy_lsbs[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d1[gkk][gjj][gii]   = rcoordsz_lsbs[gkk][gjj][gii];
 
            for (integer iii=0; iii<NNN1D; iii=iii+1) begin
              if (nn_oh_rdecx[iii]) begin
                nxt_mer_rotx[gkk][gjj][gii]           = mer[gkk][gjj][iii];
              
                nxt_rcoordsx_msbs_rotx[gkk][gjj][gii] = rcoordsx_msbs[gkk][gjj][iii];
                nxt_rcoordsy_msbs_rotx[gkk][gjj][gii] = rcoordsy_msbs[gkk][gjj][iii];
                nxt_rcoordsz_msbs_rotx[gkk][gjj][gii] = rcoordsz_msbs[gkk][gjj][iii];
              
                nxt_rcoordsy_lsbs_rotx[gkk][gjj][gii] = rcoordsy_lsbs[gkk][gjj][iii];
                nxt_rcoordsz_lsbs_rotx[gkk][gjj][gii] = rcoordsz_lsbs[gkk][gjj][iii];                
              end
            end
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Control Rotational Shifting Y
  //
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mcrsy_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mcrsy_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mcrsy_x
        wire [NNN1D-1:0] nn_oh_wdecy;
        wire [NNN1D-1:0] nn_oh_rdecy;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnporty
          assign nn_oh_wdecy[gll] = (gjj[NN1DIDW-1:0] == wcoordsy_lsbs_rotx[gkk][gll][gii]) & mew_rotx[gkk][gll][gii];
          assign nn_oh_rdecy[gll] = (gjj[NN1DIDW-1:0] == rcoordsy_lsbs_rotx[gkk][gll][gii]) & mer_rotx[gkk][gll][gii];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_WCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_wdecy))
        )
        else
          $error("nn_oh_wdecy == %0b", nn_oh_wdecy);

        ASSERT_INVALID_CLUSTER_RCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_rdecy))
        )
        else
          $error("nn_oh_rdecy == %0b", nn_oh_rdecy);
`endif

        always @(posedge clk) begin : wctrl_mux_seq
          if (rst) begin
            mew_rotxy[gkk][gjj][gii]           <= 1'd0;
            we_rotxy[gkk][gjj][gii]            <= 1'd0;

            wcoordsx_msbs_rotxy[gkk][gjj][gii] <= {CIDXW{1'd0}};
            wcoordsy_msbs_rotxy[gkk][gjj][gii] <= {CIDYW{1'd0}};
            wcoordsz_msbs_rotxy[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            wcoordsz_lsbs_rotxy[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            
            wdata_rotxy[gkk][gjj][gii]         <= {GELEW{1'd0}};
          end else begin
            mew_rotxy[gkk][gjj][gii]           <= nxt_mew_rotxy[gkk][gjj][gii];
            we_rotxy[gkk][gjj][gii]            <= nxt_we_rotxy[gkk][gjj][gii];

            wcoordsx_msbs_rotxy[gkk][gjj][gii] <= nxt_wcoordsx_msbs_rotxy[gkk][gjj][gii];
            wcoordsy_msbs_rotxy[gkk][gjj][gii] <= nxt_wcoordsy_msbs_rotxy[gkk][gjj][gii];
            wcoordsz_msbs_rotxy[gkk][gjj][gii] <= nxt_wcoordsz_msbs_rotxy[gkk][gjj][gii];
            
            wcoordsz_lsbs_rotxy[gkk][gjj][gii] <= nxt_wcoordsz_lsbs_rotxy[gkk][gjj][gii];
            
            wdata_rotxy[gkk][gjj][gii]         <= nxt_wdata_rotxy[gkk][gjj][gii];
          end
        end

        always @* begin : wctrl_mux_comb
          nxt_mew_rotxy[gkk][gjj][gii]           = 1'd0;
          nxt_we_rotxy[gkk][gjj][gii]            = 1'd0;

          nxt_wcoordsx_msbs_rotxy[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_wcoordsy_msbs_rotxy[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_wcoordsz_msbs_rotxy[gkk][gjj][gii] = {CIDZW{1'd0}};
            
          nxt_wcoordsz_lsbs_rotxy[gkk][gjj][gii] = {NN1DIDW{1'd0}};
            
          nxt_wdata_rotxy[gkk][gjj][gii]         = {GELEW{1'd0}};

          // Each port is accessing unique Y, rotate
          for (integer ijj=0; ijj<NNN1D; ijj=ijj+1) begin
            if (nn_oh_wdecy[ijj]) begin
              nxt_mew_rotxy[gkk][gjj][gii]           = mew_rotx[gkk][ijj][gii];
              nxt_we_rotxy[gkk][gjj][gii]            = we_rotx[gkk][ijj][gii];
              
              nxt_wcoordsx_msbs_rotxy[gkk][gjj][gii] = wcoordsx_msbs_rotx[gkk][ijj][gii];
              nxt_wcoordsy_msbs_rotxy[gkk][gjj][gii] = wcoordsy_msbs_rotx[gkk][ijj][gii];
              nxt_wcoordsz_msbs_rotxy[gkk][gjj][gii] = wcoordsz_msbs_rotx[gkk][ijj][gii];
              
              nxt_wcoordsz_lsbs_rotxy[gkk][gjj][gii] = wcoordsz_lsbs_rotx[gkk][ijj][gii];
              
              nxt_wdata_rotxy[gkk][gjj][gii]         = wdata_rotx[gkk][ijj][gii];
            end
          end
        end

        always @(posedge clk) begin : rctrl_mux_seq
          if (rst) begin
            mer_rotxy[gkk][gjj][gii]           <= 1'd0;
            
            rcoordsx_msbs_rotxy[gkk][gjj][gii] <= {CIDXW{1'd0}};
            rcoordsy_msbs_rotxy[gkk][gjj][gii] <= {CIDYW{1'd0}};
            rcoordsz_msbs_rotxy[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            rcoordsz_lsbs_rotxy[gkk][gjj][gii] <= {NN1DIDW{1'd0}};

            rcoordsx_lsbs_d2[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsy_lsbs_d2[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsz_lsbs_d2[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
          end else begin
            mer_rotxy[gkk][gjj][gii]           <= nxt_mer_rotxy[gkk][gjj][gii];
            
            rcoordsx_msbs_rotxy[gkk][gjj][gii] <= nxt_rcoordsx_msbs_rotxy[gkk][gjj][gii];
            rcoordsy_msbs_rotxy[gkk][gjj][gii] <= nxt_rcoordsy_msbs_rotxy[gkk][gjj][gii];
            rcoordsz_msbs_rotxy[gkk][gjj][gii] <= nxt_rcoordsz_msbs_rotxy[gkk][gjj][gii];
            
            rcoordsz_lsbs_rotxy[gkk][gjj][gii] <= nxt_rcoordsz_lsbs_rotxy[gkk][gjj][gii];

            rcoordsx_lsbs_d2[gkk][gjj][gii]   <= nxt_rcoordsx_lsbs_d2[gkk][gjj][gii];
            rcoordsy_lsbs_d2[gkk][gjj][gii]   <= nxt_rcoordsy_lsbs_d2[gkk][gjj][gii];
            rcoordsz_lsbs_d2[gkk][gjj][gii]   <= nxt_rcoordsz_lsbs_d2[gkk][gjj][gii];
          end
        end

        always @* begin : rctrl_mux_comb
          if (stall) begin
            nxt_mer_rotxy[gkk][gjj][gii]           = mer_rotxy[gkk][gjj][gii];
            
            nxt_rcoordsx_msbs_rotxy[gkk][gjj][gii] = rcoordsx_msbs_rotxy[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotxy[gkk][gjj][gii] = rcoordsy_msbs_rotxy[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotxy[gkk][gjj][gii] = rcoordsz_msbs_rotxy[gkk][gjj][gii];
            
            nxt_rcoordsz_lsbs_rotxy[gkk][gjj][gii] = rcoordsz_lsbs_rotxy[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d2[gkk][gjj][gii]   = rcoordsx_lsbs_d2[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d2[gkk][gjj][gii]   = rcoordsy_lsbs_d2[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d2[gkk][gjj][gii]   = rcoordsz_lsbs_d2[gkk][gjj][gii];
          end else begin
            nxt_mer_rotxy[gkk][gjj][gii]           = 1'd0;
          
            nxt_rcoordsx_msbs_rotxy[gkk][gjj][gii] = rcoordsx_msbs_rotxy[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotxy[gkk][gjj][gii] = rcoordsy_msbs_rotxy[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotxy[gkk][gjj][gii] = rcoordsz_msbs_rotxy[gkk][gjj][gii];
            
            nxt_rcoordsz_lsbs_rotxy[gkk][gjj][gii] = rcoordsz_lsbs_rotxy[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d2[gkk][gjj][gii]   = rcoordsx_lsbs_d1[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d2[gkk][gjj][gii]   = rcoordsy_lsbs_d1[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d2[gkk][gjj][gii]   = rcoordsz_lsbs_d1[gkk][gjj][gii];

            // Each port is accessing unique Y, rotate
            for (integer ijj=0; ijj<NNN1D; ijj=ijj+1) begin
              if (nn_oh_rdecy[ijj]) begin
                nxt_mer_rotxy[gkk][gjj][gii]           = mer_rotx[gkk][ijj][gii];
              
                nxt_rcoordsx_msbs_rotxy[gkk][gjj][gii] = rcoordsx_msbs_rotx[gkk][ijj][gii];
                nxt_rcoordsy_msbs_rotxy[gkk][gjj][gii] = rcoordsy_msbs_rotx[gkk][ijj][gii];
                nxt_rcoordsz_msbs_rotxy[gkk][gjj][gii] = rcoordsz_msbs_rotx[gkk][ijj][gii];
              
                nxt_rcoordsz_lsbs_rotxy[gkk][gjj][gii] = rcoordsz_lsbs_rotx[gkk][ijj][gii];
              end
            end
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Control Rotational Shifting Z
  //
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mcrsz_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mcrsz_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mcrsz_x
        wire [NNN1D-1:0] nn_oh_wdecz;
        wire [NNN1D-1:0] nn_oh_rdecz;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportz
          assign nn_oh_wdecz[gll] = (gkk[NN1DIDW-1:0] == wcoordsz_lsbs_rotxy[gll][gjj][gii]) & mew_rotxy[gll][gjj][gii];
          assign nn_oh_rdecz[gll] = (gkk[NN1DIDW-1:0] == rcoordsz_lsbs_rotxy[gll][gjj][gii]) & mer_rotxy[gll][gjj][gii];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_WCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_wdecz))
        )
        else
          $error("nn_oh_wdecz == %0b", nn_oh_wdecz);

        ASSERT_INVALID_CLUSTER_RCOORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_rdecz))
        )
        else
          $error("nn_oh_rdecz == %0b", nn_oh_rdecz);
`endif

        always @(posedge clk) begin : wctrl_mux_seq
          if (rst) begin
            mew_rotxyz[gkk][gjj][gii]           <= 1'd0;
            we_rotxyz[gkk][gjj][gii]            <= 1'd0;

            wcoordsx_msbs_rotxyz[gkk][gjj][gii] <= {CIDXW{1'd0}};
            wcoordsy_msbs_rotxyz[gkk][gjj][gii] <= {CIDYW{1'd0}};
            wcoordsz_msbs_rotxyz[gkk][gjj][gii] <= {CIDZW{1'd0}};
                        
            wdata_rotxyz[gkk][gjj][gii]         <= {GELEW{1'd0}};
          end else begin
            mew_rotxyz[gkk][gjj][gii]           <= nxt_mew_rotxyz[gkk][gjj][gii];
            we_rotxyz[gkk][gjj][gii]            <= nxt_we_rotxyz[gkk][gjj][gii];

            wcoordsx_msbs_rotxyz[gkk][gjj][gii] <= nxt_wcoordsx_msbs_rotxyz[gkk][gjj][gii];
            wcoordsy_msbs_rotxyz[gkk][gjj][gii] <= nxt_wcoordsy_msbs_rotxyz[gkk][gjj][gii];
            wcoordsz_msbs_rotxyz[gkk][gjj][gii] <= nxt_wcoordsz_msbs_rotxyz[gkk][gjj][gii];
                        
            wdata_rotxyz[gkk][gjj][gii]         <= nxt_wdata_rotxyz[gkk][gjj][gii];
          end
        end

        always @* begin : wctrl_mux_comb
          nxt_mew_rotxyz[gkk][gjj][gii]           = 1'd0;
          nxt_we_rotxyz[gkk][gjj][gii]            = 1'd0;

          nxt_wcoordsx_msbs_rotxyz[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_wcoordsy_msbs_rotxyz[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_wcoordsz_msbs_rotxyz[gkk][gjj][gii] = {CIDZW{1'd0}};
                        
          nxt_wdata_rotxyz[gkk][gjj][gii]         = {GELEW{1'd0}};

          // Each port is accessing unique Z, rotate
          for (integer ikk=0; ikk<NNN1D; ikk=ikk+1) begin
            if (nn_oh_wdecz[ikk]) begin
              nxt_mew_rotxyz[gkk][gjj][gii]           = mew_rotxy[ikk][gjj][gii];
              nxt_we_rotxyz[gkk][gjj][gii]            = we_rotxy[ikk][gjj][gii];
              
              nxt_wcoordsx_msbs_rotxyz[gkk][gjj][gii] = wcoordsx_msbs_rotxy[ikk][gjj][gii];
              nxt_wcoordsy_msbs_rotxyz[gkk][gjj][gii] = wcoordsy_msbs_rotxy[ikk][gjj][gii];
              nxt_wcoordsz_msbs_rotxyz[gkk][gjj][gii] = wcoordsz_msbs_rotxy[ikk][gjj][gii];
              
              nxt_wdata_rotxyz[gkk][gjj][gii]         = wdata_rotxy[ikk][gjj][gii];
            end
          end
        end

        always @(posedge clk) begin : rctrl_mux_seq
          if (rst) begin
            mer_rotxyz[gkk][gjj][gii]           <= 1'd0;
            
            rcoordsx_msbs_rotxyz[gkk][gjj][gii] <= {CIDXW{1'd0}};
            rcoordsy_msbs_rotxyz[gkk][gjj][gii] <= {CIDYW{1'd0}};
            rcoordsz_msbs_rotxyz[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            rcoordsx_lsbs_d3[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsy_lsbs_d3[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
            rcoordsz_lsbs_d3[gkk][gjj][gii]   <= {NN1DIDW{1'd0}};
          end else begin
            mer_rotxyz[gkk][gjj][gii]           <= nxt_mer_rotxyz[gkk][gjj][gii];
            
            rcoordsx_msbs_rotxyz[gkk][gjj][gii] <= nxt_rcoordsx_msbs_rotxyz[gkk][gjj][gii];
            rcoordsy_msbs_rotxyz[gkk][gjj][gii] <= nxt_rcoordsy_msbs_rotxyz[gkk][gjj][gii];
            rcoordsz_msbs_rotxyz[gkk][gjj][gii] <= nxt_rcoordsz_msbs_rotxyz[gkk][gjj][gii];
            
            rcoordsx_lsbs_d3[gkk][gjj][gii]   <= nxt_rcoordsx_lsbs_d3[gkk][gjj][gii];
            rcoordsy_lsbs_d3[gkk][gjj][gii]   <= nxt_rcoordsy_lsbs_d3[gkk][gjj][gii];
            rcoordsz_lsbs_d3[gkk][gjj][gii]   <= nxt_rcoordsz_lsbs_d3[gkk][gjj][gii];
          end
        end

        always @* begin : rctrl_mux_comb
          if (stall) begin
            nxt_mer_rotxyz[gkk][gjj][gii]           = mer_rotxyz[gkk][gjj][gii];
            
            nxt_rcoordsx_msbs_rotxyz[gkk][gjj][gii] = rcoordsx_msbs_rotxyz[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotxyz[gkk][gjj][gii] = rcoordsy_msbs_rotxyz[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotxyz[gkk][gjj][gii] = rcoordsz_msbs_rotxyz[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d3[gkk][gjj][gii]   = rcoordsx_lsbs_d3[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d3[gkk][gjj][gii]   = rcoordsy_lsbs_d3[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d3[gkk][gjj][gii]   = rcoordsz_lsbs_d3[gkk][gjj][gii];
          end else begin
            nxt_mer_rotxyz[gkk][gjj][gii]           = 1'd0;
            
            nxt_rcoordsx_msbs_rotxyz[gkk][gjj][gii] = rcoordsx_msbs_rotxyz[gkk][gjj][gii];
            nxt_rcoordsy_msbs_rotxyz[gkk][gjj][gii] = rcoordsy_msbs_rotxyz[gkk][gjj][gii];
            nxt_rcoordsz_msbs_rotxyz[gkk][gjj][gii] = rcoordsz_msbs_rotxyz[gkk][gjj][gii];

            nxt_rcoordsx_lsbs_d3[gkk][gjj][gii]   = rcoordsx_lsbs_d2[gkk][gjj][gii];
            nxt_rcoordsy_lsbs_d3[gkk][gjj][gii]   = rcoordsy_lsbs_d2[gkk][gjj][gii];
            nxt_rcoordsz_lsbs_d3[gkk][gjj][gii]   = rcoordsz_lsbs_d2[gkk][gjj][gii];

            for (integer ikk=0; ikk<NNN1D; ikk=ikk+1) begin
              if (nn_oh_rdecz[ikk]) begin
                nxt_mer_rotxyz[gkk][gjj][gii]           = mer_rotxy[ikk][gjj][gii];
              
                nxt_rcoordsx_msbs_rotxyz[gkk][gjj][gii] = rcoordsx_msbs_rotxy[ikk][gjj][gii];
                nxt_rcoordsy_msbs_rotxyz[gkk][gjj][gii] = rcoordsy_msbs_rotxy[ikk][gjj][gii];
                nxt_rcoordsz_msbs_rotxyz[gkk][gjj][gii] = rcoordsz_msbs_rotxy[ikk][gjj][gii];
              end
            end
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Grid Memory Blocks
  //
  // Always want to access cluster of nearest neighbors at a one time.
  //
  // Architect grid memory to be comprised of a number of memory blocks equal
  // to the number of nearest neighbors in a cluster. The depth of each block
  // is equal to the maximum number of nearest neighbors clusters that can fit
  // into the grid.
  //
  // Only need to add pipline stall capabilities for read paths as only read
  // path is active during force computation.

  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : nmem_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : nmem_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : nmem_x
        always @(posedge clk) begin : raddr_bits_seq
          if (rst) begin
            rcoordsz_msbs_rotxyz_d1[gkk][gjj][gii] <= {CIDZW{1'd0}};
            rcoordsy_msbs_rotxyz_d1[gkk][gjj][gii] <= {CIDYW{1'd0}};
            rcoordsx_msbs_rotxyz_d1[gkk][gjj][gii] <= {CIDXW{1'd0}};

            rcoordsz_lsbs_d3_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            rcoordsy_lsbs_d3_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            rcoordsx_lsbs_d3_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            if (stall) begin
              rcoordsz_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsz_msbs_rotxyz_d1[gkk][gjj][gii];
              rcoordsy_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsy_msbs_rotxyz_d1[gkk][gjj][gii];
              rcoordsx_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsx_msbs_rotxyz_d1[gkk][gjj][gii];

              rcoordsz_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsz_lsbs_d3_d1[gkk][gjj][gii];
              rcoordsy_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsy_lsbs_d3_d1[gkk][gjj][gii];
              rcoordsx_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsx_lsbs_d3_d1[gkk][gjj][gii];
            end else begin            
              rcoordsz_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsz_msbs_rotxyz[gkk][gjj][gii];
              rcoordsy_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsy_msbs_rotxyz[gkk][gjj][gii];
              rcoordsx_msbs_rotxyz_d1[gkk][gjj][gii] <= rcoordsx_msbs_rotxyz[gkk][gjj][gii];

              rcoordsz_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsz_lsbs_d3[gkk][gjj][gii];
              rcoordsy_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsy_lsbs_d3[gkk][gjj][gii];
              rcoordsx_lsbs_d3_d1[gkk][gjj][gii] <= rcoordsx_lsbs_d3[gkk][gjj][gii];
            end
          end
        end

        assign block_waddr[gkk][gjj][gii] = {wcoordsz_msbs_rotxyz[gkk][gjj][gii], wcoordsy_msbs_rotxyz[gkk][gjj][gii], wcoordsx_msbs_rotxyz[gkk][gjj][gii]};
        assign block_raddr[gkk][gjj][gii]
          = stall ? {rcoordsz_msbs_rotxyz_d1[gkk][gjj][gii], rcoordsy_msbs_rotxyz_d1[gkk][gjj][gii], rcoordsx_msbs_rotxyz_d1[gkk][gjj][gii]}
                  : {rcoordsz_msbs_rotxyz   [gkk][gjj][gii], rcoordsy_msbs_rotxyz   [gkk][gjj][gii], rcoordsx_msbs_rotxyz   [gkk][gjj][gii]};

        assign memblk_we   [gkk][gjj][gii] = clear ? 1'b1          : we_rotxyz[gkk][gjj][gii];
        assign memblk_mew  [gkk][gjj][gii] = clear ? 1'b1          : mew_rotxyz[gkk][gjj][gii];
        assign memblk_waddr[gkk][gjj][gii] = clear ? clear_addr    : block_waddr[gkk][gjj][gii];
        assign memblk_wdata[gkk][gjj][gii] = clear ? {GELEW{1'b0}} : wdata_rotxyz[gkk][gjj][gii];
         
        cfg_2p_1r1w_mem #(
          .BLKS   (32'd1),  // One subblock per grid memory block
          .BDEPTH (BMEMD),  // Memory depth of all subblocks
          .SEGS   (1'd1),   // All entries of all subblocks are one segement wide
          .SEGW   (GELEW),  // Segement width
          .RDTYPE (BRDTYPE) // Readback timing type
        ) u_cluster_block (
          // Shared
          .clk   (clk),                        // (I) Clock

          // Read Port
          .mer   (mer_rotxyz[gkk][gjj][gii]),  // (I) Memory enable
          .raddr (block_raddr[gkk][gjj][gii]), // (I) Memory array address
          .rdata (block_rdata[gkk][gjj][gii]), // (O) Memory array entry read data

          // Write Port
          .mew   (memblk_mew[gkk][gjj][gii]),   // (I) Memory enable
          .segwe (memblk_we[gkk][gjj][gii]),    // (I) Active high memory array entry segment write enable
          .waddr (memblk_waddr[gkk][gjj][gii]), // (I) Memory array address
          .wdata (memblk_wdata[gkk][gjj][gii])  // (I) Memory array entry write data
        );

        // Preserve read coordinate LSBs for read data shift MUXing
        case (BRDTYPE)
          2'd0 : begin : async_read
            assign block_rcoordsx_lsbs[gkk][gjj][gii] = rcoordsx_lsbs_d3[gkk][gjj][gii];
            assign block_rcoordsy_lsbs[gkk][gjj][gii] = rcoordsy_lsbs_d3[gkk][gjj][gii];
            assign block_rcoordsz_lsbs[gkk][gjj][gii] = rcoordsz_lsbs_d3[gkk][gjj][gii];
          end

          2'd1 : begin : sync_ctrl_rd
            reg [NN1DIDW-1:0] rcoordsx_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsy_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsz_lsbs_d4;
            
            always @(posedge clk) begin : raddr_bits_seq
              if (rst) begin
                rcoordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsz_lsbs_d4 <= {NN1DIDW{1'd0}};
              end else begin
                if (stall) begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3_d1[gkk][gjj][gii];
                end else begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3[gkk][gjj][gii];
                end
              end
            end
  
            assign block_rcoordsx_lsbs[gkk][gjj][gii] = rcoordsx_lsbs_d4;
            assign block_rcoordsy_lsbs[gkk][gjj][gii] = rcoordsy_lsbs_d4;
            assign block_rcoordsz_lsbs[gkk][gjj][gii] = rcoordsz_lsbs_d4;
          end

          2'd2 : begin : sync_data_read
            reg [NN1DIDW-1:0] rcoordsx_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsy_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsz_lsbs_d4;
            
            always @(posedge clk) begin : raddr_bits_seq
              if (rst) begin
                rcoordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsz_lsbs_d4 <= {NN1DIDW{1'd0}};
              end else begin
                if (stall) begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3_d1[gkk][gjj][gii];
                end else begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3[gkk][gjj][gii];
                end
              end
            end  

            assign block_rcoordsx_lsbs[gkk][gjj][gii] = rcoordsx_lsbs_d4;
            assign block_rcoordsy_lsbs[gkk][gjj][gii] = rcoordsy_lsbs_d4;
            assign block_rcoordsz_lsbs[gkk][gjj][gii] = rcoordsz_lsbs_d4;
          end

          2'd3 : begin : sync_ctrl_data_read
            reg [NN1DIDW-1:0] rcoordsx_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsy_lsbs_d4;
            reg [NN1DIDW-1:0] rcoordsz_lsbs_d4;

            reg [NN1DIDW-1:0] rcoordsx_lsbs_d5;
            reg [NN1DIDW-1:0] rcoordsy_lsbs_d5;
            reg [NN1DIDW-1:0] rcoordsz_lsbs_d5;
 
            always @(posedge clk) begin : addr_bits_seq
              if (rst) begin
                rcoordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                rcoordsz_lsbs_d4 <= {NN1DIDW{1'd0}};

                rcoordsx_lsbs_d5 <= {NN1DIDW{1'd0}};
                rcoordsy_lsbs_d5 <= {NN1DIDW{1'd0}};
                rcoordsz_lsbs_d5 <= {NN1DIDW{1'd0}};
              end else begin
                if (stall) begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3_d1[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3_d1[gkk][gjj][gii];

                  rcoordsx_lsbs_d5 <= rcoordsx_lsbs_d5;
                  rcoordsy_lsbs_d5 <= rcoordsy_lsbs_d5;
                  rcoordsz_lsbs_d5 <= rcoordsz_lsbs_d5;
                end else begin
                  rcoordsx_lsbs_d4 <= rcoordsx_lsbs_d3[gkk][gjj][gii];
                  rcoordsy_lsbs_d4 <= rcoordsy_lsbs_d3[gkk][gjj][gii];
                  rcoordsz_lsbs_d4 <= rcoordsz_lsbs_d3[gkk][gjj][gii];

                  rcoordsx_lsbs_d5 <= rcoordsx_lsbs_d4;
                  rcoordsy_lsbs_d5 <= rcoordsy_lsbs_d4;
                  rcoordsz_lsbs_d5 <= rcoordsz_lsbs_d4;
                end
              end
            end

            assign block_rcoordsx_lsbs[gkk][gjj][gii] = rcoordsx_lsbs_d5;
            assign block_rcoordsy_lsbs[gkk][gjj][gii] = rcoordsy_lsbs_d5;
            assign block_rcoordsz_lsbs[gkk][gjj][gii] = rcoordsz_lsbs_d5;
          end
        endcase
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Data Rotational Shifting Z
  //
  // Use preserved coordinate LSBits to rotate data back
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mdrsz_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mdrsz_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mdrsz_x
        // Generate MUX select from preserved dimensional LSBits
        wire [NN1DIDW-1:0] muxsel = block_rcoordsz_lsbs[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            block_rdata_rotz[gkk][gjj][gii] <= {GELEW{1'd0}};

            block_rcoordsx_lsbs_rotz[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            block_rcoordsy_lsbs_rotz[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            if (stall) begin
              block_rdata_rotz[gkk][gjj][gii] <= block_rdata_rotz[gkk][gjj][gii];

              block_rcoordsx_lsbs_rotz[gkk][gjj][gii] <= block_rcoordsx_lsbs_rotz[gkk][gjj][gii];
              block_rcoordsy_lsbs_rotz[gkk][gjj][gii] <= block_rcoordsy_lsbs_rotz[gkk][gjj][gii];
            end else begin
              block_rdata_rotz[gkk][gjj][gii] <= block_rdata[muxsel][gjj][gii];

              // Preserve X and Y coordinate LSBits for futher dimensional rotations
              block_rcoordsx_lsbs_rotz[gkk][gjj][gii] <= block_rcoordsx_lsbs[gkk][gjj][gii];
              block_rcoordsy_lsbs_rotz[gkk][gjj][gii] <= block_rcoordsy_lsbs[gkk][gjj][gii];
            end
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Data Rotational Shifting Y
  //
  // Use preserved coordinate LSBits to rotate data back
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mdrszy_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mdrszy_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mdrszy_x
        wire [NNN1D-1:0] nn_oh_rdecy;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnporty
          assign nn_oh_rdecy[gll] = (gjj[NN1DIDW-1:0] == block_rcoordsy_lsbs_rotz[gkk][gll][gii]);
        end

        // Generate MUX select from preserved dimensional LSBits
        wire [NN1DIDW-1:0] muxsel = block_rcoordsy_lsbs_rotz[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            block_rdata_rotzy[gkk][gjj][gii] <= {GELEW{1'd0}};

            block_rcoordsx_lsbs_rotzy[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            if (stall) begin
              block_rdata_rotzy[gkk][gjj][gii] <= block_rdata_rotzy[gkk][gjj][gii];

              block_rcoordsx_lsbs_rotzy[gkk][gjj][gii] <= block_rcoordsx_lsbs_rotzy[gkk][gjj][gii];
            end else begin
              block_rdata_rotzy[gkk][gjj][gii] <= block_rdata_rotz[gkk][muxsel][gii];

              // Preserve X coordinate LSBits for futher dimensional rotations
              block_rcoordsx_lsbs_rotzy[gkk][gjj][gii] <= block_rcoordsx_lsbs_rotz[gkk][gjj][gii];
            end
          end
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Memory Data Rotational Shifting X
  //
  // Use preserved coordinate LSBits to rotate data back
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : mdrszyx_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : mdrszyx_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : mdrszyx_x
        wire [NNN1D-1:0] nn_oh_rdecx;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportx
          assign nn_oh_rdecx[gll] = (gii[NN1DIDW-1:0] == block_rcoordsx_lsbs_rotzy[gkk][gjj][gll]);
        end

        // Generate MUX select from preserved dimensional LSBits
        wire [NN1DIDW-1:0] muxsel = block_rcoordsx_lsbs_rotzy[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            rdata[gkk][gjj][gii] <= {GELEW{1'd0}};
          end else begin
            if (stall) begin
              rdata[gkk][gjj][gii] <= rdata[gkk][gjj][gii];
            end else begin
              rdata[gkk][gjj][gii] <= block_rdata_rotzy[gkk][gjj][muxsel];
            end
          end
        end
      end
    end
  end
endmodule
