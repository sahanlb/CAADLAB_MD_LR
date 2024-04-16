// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : clustered_greens_rom.sv
// Description    : Configurable Green's Function Lookup ROM
// 
// ============================================================================

module clustered_greens_rom (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  rst,     // (I) Active high Reset
  clk,     // (I) Clock

  me,      // (I) Memory port enable
  coordsx, // (I) Memory x coordinates
  coordsy, // (I) Memory y coordinates
  coordsz, // (I) Memory z coordinates
  rdata    // (O) Memory array entry data
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
  // Derived / Local Parameters
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

  `include "clustered_greens_rom.svh"

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input                                                       rst;
  input                                                       clk;

  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                me;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] coordsx;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] coordsy;
  input      [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] coordsz;
  output reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]    [GELEW-1:0] rdata;

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
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] coordsx_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] coordsy_msbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] coordsz_msbs;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsx_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsy_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs;

  // Memory Control Rotational Shifting X
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              me_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] coordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] coordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] coordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsx_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsy_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs_d1;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_me_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_coordsx_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_coordsy_msbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_coordsz_msbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsy_lsbs_rotx;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsz_lsbs_rotx;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsx_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsy_lsbs_d1;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsz_lsbs_d1;

  // Memory Control Rotational Shifting Y
   reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              me_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] coordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] coordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] coordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsx_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsy_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs_d2;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_me_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_coordsx_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_coordsy_msbs_rotxy;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_coordsz_msbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsz_lsbs_rotxy;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsx_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsy_lsbs_d2;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsz_lsbs_d2;

  // Memory Control Rotational Shifting Z
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              me_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] coordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] coordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] coordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsx_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsy_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] coordsz_lsbs_d3;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]              nxt_me_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDXW-1:0] nxt_coordsx_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDYW-1:0] nxt_coordsy_msbs_rotxyz;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [CIDZW-1:0] nxt_coordsz_msbs_rotxyz;

  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsx_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsy_lsbs_d3;
  reg [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] nxt_coordsz_lsbs_d3;

  // Grid Memory Blocks
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] [BADDRW-1:0] block_raddr;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsx_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsy_lsbs;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsz_lsbs;

  // Memory Read Data Rotational Shifting
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata_rotz;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsx_lsbs_rotz;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsy_lsbs_rotz;

  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]  [GELEW-1:0] block_rdata_rotzy;
  reg  [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][NN1DIDW-1:0] block_coordsx_lsbs_rotzy;

`ifndef SYNTHESIS
  // Assertion disable
  reg disable_assert;
`endif

  // --------------------------------------------------------------------------
  // Coordinate Reorganization
  //
  // Split up coordinates into:
  //  o MSBs used to index into neighbor memories
  //  o LSBs used for routing to neighbor memory
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : coord_reorg_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : coord_reorg_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : coord_reorg_x
        assign coordsx_msbs[gkk][gjj][gii] = coordsx[gkk][gjj][gii][NN1DIDW+:CIDXW];
        assign coordsx_lsbs[gkk][gjj][gii] = coordsx[gkk][gjj][gii][NN1DIDW-1:0];

        assign coordsy_msbs[gkk][gjj][gii] = coordsy[gkk][gjj][gii][NN1DIDW+:CIDYW];
        assign coordsy_lsbs[gkk][gjj][gii] = coordsy[gkk][gjj][gii][NN1DIDW-1:0];

        assign coordsz_msbs[gkk][gjj][gii] = coordsz[gkk][gjj][gii][NN1DIDW+:CIDZW];
        assign coordsz_lsbs[gkk][gjj][gii] = coordsz[gkk][gjj][gii][NN1DIDW-1:0];

`ifndef SYNTHESIS
        genvar gmm;
        genvar gnn;
        
        wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0] nn_oh_dec;

        for (gnn=0; gnn<NNN1D; gnn=gnn+1) begin : nnportz
          for (gmm=0; gmm<NNN1D; gmm=gmm+1) begin : nnporty
            for (gll=0; gll<NNN1D; gll=gll+1) begin : nnportx
              assign nn_oh_dec[gnn][gmm][gll] = ((gkk[NN1DIDW-1:0] == coordsz_lsbs[gnn][gmm][gll]) &&
                                                 (gjj[NN1DIDW-1:0] == coordsy_lsbs[gnn][gmm][gll]) &&
                                                 (gii[NN1DIDW-1:0] == coordsx_lsbs[gnn][gmm][gll])) &
                                                 me[gnn][gmm][gll];

            end
          end
        end

      ASSERT_INVALID_CLUSTER_COORDS: assert property (
        @(negedge clk)
        disable iff(disable_assert)
        $onehot0(nn_oh_dec)
      )
      else
        $error("nn_oh_dec == %0b", nn_oh_dec);
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
        wire [NNN1D-1:0] nn_oh_decx;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportx
          assign nn_oh_decx[gll] = (gii[NN1DIDW-1:0] == coordsx_lsbs[gkk][gjj][gll]) & me[gkk][gjj][gll];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_COORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_decx))
        )
        else
          $error("nn_oh_decx == %0b", nn_oh_decx);
`endif

        always @(posedge clk) begin : ctrl_mux_seq
          if (rst) begin
            me_rotx[gkk][gjj][gii] <= 1'd0;
            
            coordsx_msbs_rotx[gkk][gjj][gii] <= {CIDXW{1'd0}};
            coordsy_msbs_rotx[gkk][gjj][gii] <= {CIDYW{1'd0}};
            coordsz_msbs_rotx[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            coordsy_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsz_lsbs_rotx[gkk][gjj][gii] <= {NN1DIDW{1'd0}};

            coordsx_lsbs_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsy_lsbs_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsz_lsbs_d1[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            me_rotx[gkk][gjj][gii] <= nxt_me_rotx[gkk][gjj][gii];
            
            coordsx_msbs_rotx[gkk][gjj][gii] <= nxt_coordsx_msbs_rotx[gkk][gjj][gii];
            coordsy_msbs_rotx[gkk][gjj][gii] <= nxt_coordsy_msbs_rotx[gkk][gjj][gii];
            coordsz_msbs_rotx[gkk][gjj][gii] <= nxt_coordsz_msbs_rotx[gkk][gjj][gii];
            
            coordsy_lsbs_rotx[gkk][gjj][gii] <= nxt_coordsy_lsbs_rotx[gkk][gjj][gii];
            coordsz_lsbs_rotx[gkk][gjj][gii] <= nxt_coordsz_lsbs_rotx[gkk][gjj][gii];

            coordsx_lsbs_d1[gkk][gjj][gii] <= nxt_coordsx_lsbs_d1[gkk][gjj][gii];
            coordsy_lsbs_d1[gkk][gjj][gii] <= nxt_coordsy_lsbs_d1[gkk][gjj][gii];
            coordsz_lsbs_d1[gkk][gjj][gii] <= nxt_coordsz_lsbs_d1[gkk][gjj][gii];
          end
        end

        always @* begin : ctrl_mux_comb
          nxt_me_rotx[gkk][gjj][gii] = 1'd0;
            
          nxt_coordsx_msbs_rotx[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_coordsy_msbs_rotx[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_coordsz_msbs_rotx[gkk][gjj][gii] = {CIDZW{1'd0}};
            
          nxt_coordsy_lsbs_rotx[gkk][gjj][gii] = {NN1DIDW{1'd0}};
          nxt_coordsz_lsbs_rotx[gkk][gjj][gii] = {NN1DIDW{1'd0}};

          nxt_coordsx_lsbs_d1[gkk][gjj][gii] = coordsx_lsbs[gkk][gjj][gii];
          nxt_coordsy_lsbs_d1[gkk][gjj][gii] = coordsy_lsbs[gkk][gjj][gii];
          nxt_coordsz_lsbs_d1[gkk][gjj][gii] = coordsz_lsbs[gkk][gjj][gii];

          for (integer iii=0; iii<NNN1D; iii=iii+1) begin
            if (nn_oh_decx[iii]) begin
              nxt_me_rotx[gkk][gjj][gii] = me[gkk][gjj][iii];
                
              nxt_coordsx_msbs_rotx[gkk][gjj][gii] = coordsx_msbs[gkk][gjj][iii];
              nxt_coordsy_msbs_rotx[gkk][gjj][gii] = coordsy_msbs[gkk][gjj][iii];
              nxt_coordsz_msbs_rotx[gkk][gjj][gii] = coordsz_msbs[gkk][gjj][iii];
              
              nxt_coordsy_lsbs_rotx[gkk][gjj][gii] = coordsy_lsbs[gkk][gjj][iii];
              nxt_coordsz_lsbs_rotx[gkk][gjj][gii] = coordsz_lsbs[gkk][gjj][iii];
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
        wire [NNN1D-1:0] nn_oh_decy;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportx
          assign nn_oh_decy[gll] = (gjj[NN1DIDW-1:0] == coordsy_lsbs_rotx[gkk][gll][gii]) & me_rotx[gkk][gll][gii];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_COORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_decy))
        )
        else
          $error("nn_oh_decy == %0b", nn_oh_decy);
`endif

        always @(posedge clk) begin : ctrl_mux_seq
          if (rst) begin
            me_rotxy[gkk][gjj][gii] <= 1'd0;
            
            coordsx_msbs_rotxy[gkk][gjj][gii] <= {CIDXW{1'd0}};
            coordsy_msbs_rotxy[gkk][gjj][gii] <= {CIDYW{1'd0}};
            coordsz_msbs_rotxy[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            coordsz_lsbs_rotxy[gkk][gjj][gii] <= {NN1DIDW{1'd0}};

            coordsx_lsbs_d2[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsy_lsbs_d2[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsz_lsbs_d2[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            me_rotxy[gkk][gjj][gii] <= nxt_me_rotxy[gkk][gjj][gii];
            
            coordsx_msbs_rotxy[gkk][gjj][gii] <= nxt_coordsx_msbs_rotxy[gkk][gjj][gii];
            coordsy_msbs_rotxy[gkk][gjj][gii] <= nxt_coordsy_msbs_rotxy[gkk][gjj][gii];
            coordsz_msbs_rotxy[gkk][gjj][gii] <= nxt_coordsz_msbs_rotxy[gkk][gjj][gii];
            
            coordsz_lsbs_rotxy[gkk][gjj][gii] <= nxt_coordsz_lsbs_rotxy[gkk][gjj][gii];

            coordsx_lsbs_d2[gkk][gjj][gii] <= nxt_coordsx_lsbs_d2[gkk][gjj][gii];
            coordsy_lsbs_d2[gkk][gjj][gii] <= nxt_coordsy_lsbs_d2[gkk][gjj][gii];
            coordsz_lsbs_d2[gkk][gjj][gii] <= nxt_coordsz_lsbs_d2[gkk][gjj][gii];
          end
        end

        always @* begin : ctrl_mux_comb
          nxt_me_rotxy[gkk][gjj][gii] = 1'd0;
            
          nxt_coordsx_msbs_rotxy[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_coordsy_msbs_rotxy[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_coordsz_msbs_rotxy[gkk][gjj][gii] = {CIDZW{1'd0}};
            
          nxt_coordsz_lsbs_rotxy[gkk][gjj][gii] = {NN1DIDW{1'd0}};

          nxt_coordsx_lsbs_d2[gkk][gjj][gii] = coordsx_lsbs_d1[gkk][gjj][gii];
          nxt_coordsy_lsbs_d2[gkk][gjj][gii] = coordsy_lsbs_d1[gkk][gjj][gii];
          nxt_coordsz_lsbs_d2[gkk][gjj][gii] = coordsz_lsbs_d1[gkk][gjj][gii];

          for (integer ijj=0; ijj<NNN1D; ijj=ijj+1) begin
            if (nn_oh_decy[ijj]) begin
              nxt_me_rotxy[gkk][gjj][gii] = me_rotx[gkk][ijj][gii];
              
              nxt_coordsx_msbs_rotxy[gkk][gjj][gii] = coordsx_msbs_rotx[gkk][ijj][gii];
              nxt_coordsy_msbs_rotxy[gkk][gjj][gii] = coordsy_msbs_rotx[gkk][ijj][gii];
              nxt_coordsz_msbs_rotxy[gkk][gjj][gii] = coordsz_msbs_rotx[gkk][ijj][gii];
              
              nxt_coordsz_lsbs_rotxy[gkk][gjj][gii] = coordsz_lsbs_rotx[gkk][ijj][gii];
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
        wire [NNN1D-1:0] nn_oh_decz;

        for (gll=0; gll<NNN1D; gll=gll+1) begin : nnnportx
          assign nn_oh_decz[gll] = (gkk[NN1DIDW-1:0] == coordsz_lsbs_rotxy[gll][gjj][gii]) & me_rotxy[gll][gjj][gii];
        end

`ifndef SYNTHESIS
        ASSERT_INVALID_CLUSTER_COORDS: assert property (
          @(negedge clk)
          disable iff(disable_assert || rst)
          ($onehot0(nn_oh_decz))
        )
        else
          $error("nn_oh_decz == %0b", nn_oh_decz);
`endif

        always @(posedge clk) begin : ctrl_mux_seq
          if (rst) begin
            me_rotxyz[gkk][gjj][gii] <= 1'd0;
            
            coordsx_msbs_rotxyz[gkk][gjj][gii] <= {CIDXW{1'd0}};
            coordsy_msbs_rotxyz[gkk][gjj][gii] <= {CIDYW{1'd0}};
            coordsz_msbs_rotxyz[gkk][gjj][gii] <= {CIDZW{1'd0}};
            
            coordsx_lsbs_d3[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsy_lsbs_d3[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            coordsz_lsbs_d3[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            me_rotxyz[gkk][gjj][gii] <= nxt_me_rotxyz[gkk][gjj][gii];
            
            coordsx_msbs_rotxyz[gkk][gjj][gii] <= nxt_coordsx_msbs_rotxyz[gkk][gjj][gii];
            coordsy_msbs_rotxyz[gkk][gjj][gii] <= nxt_coordsy_msbs_rotxyz[gkk][gjj][gii];
            coordsz_msbs_rotxyz[gkk][gjj][gii] <= nxt_coordsz_msbs_rotxyz[gkk][gjj][gii];
            
            coordsx_lsbs_d3[gkk][gjj][gii] <= nxt_coordsx_lsbs_d3[gkk][gjj][gii];
            coordsy_lsbs_d3[gkk][gjj][gii] <= nxt_coordsy_lsbs_d3[gkk][gjj][gii];
            coordsz_lsbs_d3[gkk][gjj][gii] <= nxt_coordsz_lsbs_d3[gkk][gjj][gii];
          end
        end

        always @* begin : ctrl_mux_comb
          nxt_me_rotxyz[gkk][gjj][gii] = 1'd0;
            
          nxt_coordsx_msbs_rotxyz[gkk][gjj][gii] = {CIDXW{1'd0}};
          nxt_coordsy_msbs_rotxyz[gkk][gjj][gii] = {CIDYW{1'd0}};
          nxt_coordsz_msbs_rotxyz[gkk][gjj][gii] = {CIDZW{1'd0}};
            
          nxt_coordsx_lsbs_d3[gkk][gjj][gii] = coordsx_lsbs_d2[gkk][gjj][gii];
          nxt_coordsy_lsbs_d3[gkk][gjj][gii] = coordsy_lsbs_d2[gkk][gjj][gii];
          nxt_coordsz_lsbs_d3[gkk][gjj][gii] = coordsz_lsbs_d2[gkk][gjj][gii];

          for (integer ikk=0; ikk<NNN1D; ikk=ikk+1) begin
            if (nn_oh_decz[ikk]) begin
              nxt_me_rotxyz[gkk][gjj][gii] = me_rotxy[ikk][gjj][gii];
              
              nxt_coordsx_msbs_rotxyz[gkk][gjj][gii] = coordsx_msbs_rotxy[ikk][gjj][gii];
              nxt_coordsy_msbs_rotxyz[gkk][gjj][gii] = coordsy_msbs_rotxy[ikk][gjj][gii];
              nxt_coordsz_msbs_rotxyz[gkk][gjj][gii] = coordsz_msbs_rotxy[ikk][gjj][gii];
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
  
  for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : nmem_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : nmem_y
      for (gii=0; gii<NNN1D; gii=gii+1) begin : nmem_x
        assign block_raddr[gkk][gjj][gii] = {coordsz_msbs_rotxyz[gkk][gjj][gii], coordsy_msbs_rotxyz[gkk][gjj][gii], coordsx_msbs_rotxyz[gkk][gjj][gii]};
                
        cfg_sp_ro_mem #(
          .BLKS   (32'd1),                // One subblock per grid memory block
          .BDEPTH (BMEMD),                // Memory depth of all subblocks
          .SEGS   (1'd1),                 // All entries of all subblocks are one segement wide
          .SEGW   (GELEW),                // Segement width
          .RDTYPE (BRDTYPE),              // Readback timing type
          .ROMVAL (ROMVAL[gkk][gjj][gii]) // ROM bits
        ) u_cluster_block (
          .clk   (clk),                        // (I) Clock
          .me    (me_rotxyz[gkk][gjj][gii]),   // (I) Memory enable
          .addr  (block_raddr[gkk][gjj][gii]), // (I) Memory array address
          .rdata (block_rdata[gkk][gjj][gii])  // (O) Memory array entry read data
        );

        // Preserve read coordinate LSBs for read data shift MUXing
        case (BRDTYPE)
          2'd0 : begin : async_read
            assign block_coordsx_lsbs[gkk][gjj][gii] = coordsx_lsbs_d3[gkk][gjj][gii];
            assign block_coordsy_lsbs[gkk][gjj][gii] = coordsy_lsbs_d3[gkk][gjj][gii];
            assign block_coordsz_lsbs[gkk][gjj][gii] = coordsz_lsbs_d3[gkk][gjj][gii];
          end

          2'd1 : begin : sync_ctrl_rd
            reg [NN1DIDW-1:0] coordsx_lsbs_d4;
            reg [NN1DIDW-1:0] coordsy_lsbs_d4;
            reg [NN1DIDW-1:0] coordsz_lsbs_d4;
            
            always @(posedge clk) begin : raddr_bits_seq
              if (rst) begin
                coordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsz_lsbs_d4 <= {NN1DIDW{1'd0}};
              end else begin
                coordsx_lsbs_d4 <= coordsx_lsbs_d3[gkk][gjj][gii];
                coordsy_lsbs_d4 <= coordsy_lsbs_d3[gkk][gjj][gii];
                coordsz_lsbs_d4 <= coordsz_lsbs_d3[gkk][gjj][gii];
              end
            end
  
            assign block_coordsx_lsbs[gkk][gjj][gii] = coordsx_lsbs_d4;
            assign block_coordsy_lsbs[gkk][gjj][gii] = coordsy_lsbs_d4;
            assign block_coordsz_lsbs[gkk][gjj][gii] = coordsz_lsbs_d4;
          end

          2'd2 : begin : sync_data_read
            reg [NN1DIDW-1:0] coordsx_lsbs_d4;
            reg [NN1DIDW-1:0] coordsy_lsbs_d4;
            reg [NN1DIDW-1:0] coordsz_lsbs_d4;
            
            always @(posedge clk) begin : raddr_bits_seq
              if (rst) begin
                coordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsz_lsbs_d4 <= {NN1DIDW{1'd0}};
              end else begin
                coordsx_lsbs_d4 <= coordsx_lsbs_d3[gkk][gjj][gii];
                coordsy_lsbs_d4 <= coordsy_lsbs_d3[gkk][gjj][gii];
                coordsz_lsbs_d4 <= coordsz_lsbs_d3[gkk][gjj][gii];
              end
            end
  
            assign block_coordsx_lsbs[gkk][gjj][gii] = coordsx_lsbs_d4;
            assign block_coordsy_lsbs[gkk][gjj][gii] = coordsy_lsbs_d4;
            assign block_coordsz_lsbs[gkk][gjj][gii] = coordsz_lsbs_d4;
          end

          2'd3 : begin : sync_ctrl_data_read
            reg [NN1DIDW-1:0] coordsx_lsbs_d4;
            reg [NN1DIDW-1:0] coordsy_lsbs_d4;
            reg [NN1DIDW-1:0] coordsz_lsbs_d4;

            reg [NN1DIDW-1:0] coordsx_lsbs_d5;
            reg [NN1DIDW-1:0] coordsy_lsbs_d5;
            reg [NN1DIDW-1:0] coordsz_lsbs_d5;
 
            always @(posedge clk) begin : addr_bits_seq
              if (rst) begin
                coordsx_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsy_lsbs_d4 <= {NN1DIDW{1'd0}};
                coordsz_lsbs_d4 <= {NN1DIDW{1'd0}};

                coordsx_lsbs_d5 <= {NN1DIDW{1'd0}};
                coordsy_lsbs_d5 <= {NN1DIDW{1'd0}};
                coordsz_lsbs_d5 <= {NN1DIDW{1'd0}};
              end else begin
                coordsx_lsbs_d4 <= coordsx_lsbs_d3[gkk][gjj][gii];
                coordsy_lsbs_d4 <= coordsy_lsbs_d3[gkk][gjj][gii];
                coordsz_lsbs_d4 <= coordsz_lsbs_d3[gkk][gjj][gii];

                coordsx_lsbs_d5 <= coordsx_lsbs_d4;
                coordsy_lsbs_d5 <= coordsy_lsbs_d4;
                coordsz_lsbs_d5 <= coordsz_lsbs_d4;
              end
            end

            assign block_coordsx_lsbs[gkk][gjj][gii] = coordsx_lsbs_d5;
            assign block_coordsy_lsbs[gkk][gjj][gii] = coordsy_lsbs_d5;
            assign block_coordsz_lsbs[gkk][gjj][gii] = coordsz_lsbs_d5;
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
        wire [NN1DIDW-1:0] muxsel = block_coordsz_lsbs[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            block_rdata_rotz[gkk][gjj][gii] <= {GELEW{1'd0}};

            block_coordsx_lsbs_rotz[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
            block_coordsy_lsbs_rotz[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            block_rdata_rotz[gkk][gjj][gii] <= block_rdata[muxsel][gjj][gii];

            // Preserve X and Y coordinate LSBits for futher dimensional rotations
            block_coordsx_lsbs_rotz[gkk][gjj][gii] <= block_coordsx_lsbs[gkk][gjj][gii];
            block_coordsy_lsbs_rotz[gkk][gjj][gii] <= block_coordsy_lsbs[gkk][gjj][gii];
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
        // Generate MUX select from preserved dimensional LSBits
        wire [NN1DIDW-1:0] muxsel = block_coordsy_lsbs_rotz[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            block_rdata_rotzy[gkk][gjj][gii] <= {GELEW{1'd0}};

            block_coordsx_lsbs_rotzy[gkk][gjj][gii] <= {NN1DIDW{1'd0}};
          end else begin
            block_rdata_rotzy[gkk][gjj][gii] <= block_rdata_rotz[gkk][muxsel][gii];

            // Preserve X coordinate LSBits for futher dimensional rotations
            block_coordsx_lsbs_rotzy[gkk][gjj][gii] <= block_coordsx_lsbs_rotz[gkk][gjj][gii];
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
        // Generate MUX select from preserved dimensional LSBits
        wire [NN1DIDW-1:0] muxsel = block_coordsx_lsbs_rotzy[gkk][gjj][gii];
        
        always @(posedge clk) begin : pipe_shift_mux
          if (rst) begin
            rdata[gkk][gjj][gii] <= {GELEW{1'd0}};
          end else begin
            // Each port is accessing unique Z, rotate
            rdata[gkk][gjj][gii] <= block_rdata_rotzy[gkk][gjj][muxsel];
          end
        end
      end
    end
  end
endmodule
