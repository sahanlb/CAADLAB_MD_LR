// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : clustered_grid_mem_tb.sv
// Description    : Testbench for configurable grid memory
// 
// ============================================================================

module clustered_grid_mem_tb ();
  
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

  // Register nearest neighbor ports read data?
  parameter [0:0] RGRDATA = 1'd0;
  
  // --------------------------------------------------------------------------
  // Derived Parameters
  //
  // Grid size in 3D
  localparam GSIZE3D = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Width of grid address in one dimension
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);
  
  // Actual number of nearest neighbors: This will serve as the number of
  // individual single port memories
  localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // The size of the grid divided by the number of nearest neighbors will serve
  // as the depth of each memory block
  localparam BMEMD = GSIZE3D / NNN3D;
  
  // Address width of each block of memory
  localparam BADDRW = $clog2(BMEMD);

  // ID width of nearest neighbor in 3 dimensions
  localparam NN3DIDW = $clog2(NNN3D);
    
  // Address width of nearest neighbor in one dimension
  localparam NN1DIDW = $clog2(NNN1D);
  
  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar ii;
  genvar jj;
  genvar kk;

  integer loopnnx;
  integer loopnny;
  integer loopnnz;

  integer cloop;
 
  reg [NNN3D-1:0] [GADDRW1DX-1:0] xwrite;
  reg [NNN3D-1:0] [GADDRW1DY-1:0] ywrite;
  reg [NNN3D-1:0] [GADDRW1DZ-1:0] zwrite;

  reg [NNN3D-1:0] [GADDRW1DX-1:0] xread;
  reg [NNN3D-1:0] [GADDRW1DY-1:0] yread;
  reg [NNN3D-1:0] [GADDRW1DZ-1:0] zread;

  reg                                 clk;
  reg                                 mew;
  reg                                 we;

  reg                                 mer;

  wire [NNN3D-1:0][GADDRW1DX-1:0] wcoordsx;
  wire [NNN3D-1:0][GADDRW1DY-1:0] wcoordsy;
  wire [NNN3D-1:0][GADDRW1DZ-1:0] wcoordsz;
  wire [NNN3D-1:0]    [GELEW-1:0] wdata;

  wire [NNN3D-1:0][GADDRW1DX-1:0] rcoordsx;
  wire [NNN3D-1:0][GADDRW1DY-1:0] rcoordsy;
  wire [NNN3D-1:0][GADDRW1DZ-1:0] rcoordsz;
  wire [NNN3D-1:0]    [GELEW-1:0] rdata;

  // --------------------------------------------------------------------------
  // DUT
  //
  clustered_grid_mem #(
    .GSIZE1DX (GSIZE1DX), // Size of X dimension of the grid
    .GSIZE1DY (GSIZE1DY), // Size of Y dimension of the grid
    .GSIZE1DZ (GSIZE1DZ), // Size of Z dimension of the grid
    .NNN1D    (NNN1D),    // Number of nearest neighbors along one dimension
    .GELEW    (GELEW),    // Bit width of each grid element
    .BRDTYPE  (BRDTYPE),  // Read delay timing of grid mem blocks
    .RGRDATA  (RGRDATA)   // Register nearest neighbor ports read data?
  ) DUT (
    .clk      (clk),            // (I) Clock

    .mew      ({NNN3D{mew}}), // (I) Memory write port enable
    .wcoordsx (wcoordsx),     // (I) Memory write x coordinates
    .wcoordsy (wcoordsy),     // (I) Memory write y coordinates
    .wcoordsz (wcoordsz),     // (I) Memory write z coordinates
    .we       ({NNN3D{we}}),  // (I) Active high memory array entry segment write enable
    .wdata    (wdata),        // (I) Memory array entry write data

    .mer      ({NNN3D{mer}}), // (I) Memory read port enable
    .rcoordsx (rcoordsx),     // (I) Memory read x corrdinates
    .rcoordsy (rcoordsy),     // (I) Memory read y corrdinates
    .rcoordsz (rcoordsz),     // (I) Memory read z corrdinates
    .rdata    (rdata)         // (O) Memory array entry read data
  );
  
  // --------------------------------------------------------------------------
  // Stimulus Generation
  //
  for(ii=0;ii<NNN3D;ii=ii+1) begin : nnport
    assign wcoordsz[ii] = zwrite[ii];
    assign wcoordsy[ii] = ywrite[ii];
    assign wcoordsx[ii] = xwrite[ii];
    
    assign rcoordsz[ii] = zread[ii];
    assign rcoordsy[ii] = yread[ii];
    assign rcoordsx[ii] = xread[ii];
    
    assign wdata[ii] = {xwrite[ii], ywrite[ii], zwrite[ii]};
  end

  always @(clk) begin : clock_gen
    #5 clk <= ~clk;
  end

  initial begin      
    clk = 0;
    we = 1;
    mew = 1;
    mer = 0;

    for(loopnnx=0; loopnnx<NNN1D; loopnnx=loopnnx+1) begin
      for(loopnny=0; loopnny<NNN1D; loopnny=loopnny+1) begin
        for(loopnnz=0; loopnnz<NNN1D; loopnnz=loopnnz+1) begin
          xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] = loopnnx;
          ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] = ((loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz) / NNN1D) % NNN1D;
          zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] = (loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz) % NNN1D;
        end
      end
    end

    #10;
   
    mer = 1;
    
    for(loopnnx=0; loopnnx<NNN1D; loopnnx=loopnnx+1) begin
      for(loopnny=0; loopnny<NNN1D; loopnny=loopnny+1) begin
        for(loopnnz=0; loopnnz<NNN1D; loopnnz=loopnnz+1) begin
          xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 17;
          ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 17;
          zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 17;

          xread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
          yread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
          zread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
        end
      end
    end

    #10;
     
    for(loopnnx=0; loopnnx<NNN1D; loopnnx=loopnnx+1) begin
      for(loopnny=0; loopnny<NNN1D; loopnny=loopnny+1) begin
        for(loopnnz=0; loopnnz<NNN1D; loopnnz=loopnnz+1) begin
          xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 2;
          ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 2;
          zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] + 2;

          xread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= xwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
          yread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= ywrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
          zread[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz] <= zwrite[loopnnx*NNN1D*NNN1D+loopnny*NNN1D+loopnnz];
        end
      end
    end

    #10;
     
    $finish();
  end
endmodule
