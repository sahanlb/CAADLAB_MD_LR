module coeffgen_3rdo (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  // Clocks and resets
  rst, // (I) Active high reset 
  clk, // (I) Clock

  // Floating point control
  fp_en, // (I) Floating-point block enable

  // Particle information
  pvalid, // (I) Data validation indicator
  px,     // (I) X coordinate
  poix,   // (I) X-dimension oi value
  py,     // (I) Y coordinate
  poiy,   // (I) Y-dimension oi value
  pz,     // (I) Z coordinate
  poiz,   // (I) Z-dimension oi value
  pq,     // (I) Charge

  // Coefficient Information
  coeff_valid, // (O) Coefficient data validation indicator
  coeff_data,  // (O) Coefficient data

  coord_valid, // (O) Coordinate information valid
  coord_en,    // (O) Coordinate access enable
  coordx,      // (O) Coefficient x-coordinate
  coordy,      // (O) Coefficient y-coordinate
  coordz       // (O) Coefficient z-coordinate
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
  
  // Width of oi values
  parameter OIW = 32'd27;

  // Floating point block latencies
  parameter TOFPDEL  = 32'd3;
  parameter FPMULDEL = 32'd3;
  parameter FPADDDEL = 32'd3;

  // Generator Type:
  // 2'b00 : Charge
  // 2'b01 : Force X
  // 2'b10 : Force Y
  // 2'b11 : Force Z
  parameter [1:0] CTYPE = 2'b00;
   
  // Read delay timing of grid mem blocks
  // 2'd0 : Read data asynchronously flows through based on controls
  // 2'd1 : Control information is sampled on a clock edge, read data follows that
  //        edge
  // 2'd2 : Read data asynchronusly flows through based on controls but read data is
  //        registered at the ports of the memory
  // 2'd3 : 1 and 2 combined
  parameter [1:0] GMRDTYPE = 2'd2;

  // --------------------------------------------------------------------------
  // Derived / Local Parameters
  //
  // Width of 1D grid addresses
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);

  // OI Value Pad width
  localparam OIPW = 32'd32-OIW;
  
  // Order of basis Function
  localparam ORDER = 32'd3;

  // Single-precision floating point values in binary
  localparam FP_m2     = 32'b11000000000000000000000000000000;
  localparam FP_m1p5   = 32'b10111111110000000000000000000000;
  localparam FP_m1     = 32'b10111111100000000000000000000000;
  localparam FP_m0p5   = 32'b10111111000000000000000000000000;
  localparam FP_m1div6 = 32'b10111110001010101010101010101011;
  localparam FP_0      = 32'b00000000000000000000000000000000;
  localparam FP_1div6  = 32'b00111110001010101010101010101011;
  localparam FP_0p5    = 32'b00111111000000000000000000000000;
  localparam FP_2div3  = 32'b00111111001010101010101010101011;
  localparam FP_1      = 32'b00111111100000000000000000000000;
  localparam FP_1p5    = 32'b00111111110000000000000000000000;

  // 1-D Basis Function Polynomial Coeffiecients
  localparam [3:0][ORDER:0][31:0] PHI = {
    FP_1div6,  FP_0,   FP_0,    FP_0,
    FP_m0p5,   FP_0p5, FP_0p5,  FP_1div6,
    FP_0p5,    FP_m1,  FP_0,    FP_2div3,
    FP_m1div6, FP_0p5, FP_m0p5, FP_1div6
  };

  // 1-D Basis Function Deriavative Polynomial Coeffiecients
  localparam [3:0][ORDER:0][31:0] DPHI = {
    FP_0, FP_0p5,  FP_0,  FP_0,
    FP_0, FP_m1p5, FP_1,  FP_0p5,
    FP_0, FP_1p5,  FP_m2, FP_0,
    FP_0, FP_m0p5, FP_1,  FP_m0p5
  };

  // Type-based basis function polynomial coefficients
  localparam [3:0][ORDER:0][31:0] BFCP_X = (CTYPE == 2'b01) ? DPHI : PHI;
  localparam [3:0][ORDER:0][31:0] BFCP_Y = (CTYPE == 2'b10) ? DPHI : PHI;
  localparam [3:0][ORDER:0][31:0] BFCP_Z = (CTYPE == 2'b11) ? DPHI : PHI;
  
  // Grid Memory Readback Latency:
  //  o Account for readback latency of block RAMs
  //  o Account for 3 stages of piplined control MUXing
  //  o Account for 3 stages of pipelined read data MUXing
  localparam GMRBDEL0 = (GMRDTYPE == 2'd0) ? 32'd0 :
                        (GMRDTYPE == 2'd1) ? 32'd1 :
                        (GMRDTYPE == 2'd2) ? 32'd1 : 32'd2;

  localparam GMRBDEL = GMRBDEL0 + 32'd6;

  // Coeffcient generation latency
  localparam COEFFGENLAT = TOFPDEL + 32'd5*FPMULDEL + 32'd2*FPADDDEL;

  // Coordinate generation latency:
  // Generate coordinates ahead of coefficients appropriately:
  //  o Account for readback latenct of grid memory
  //  o Account for 1 clock cycle to generate grid memory address
  localparam COORDGENLAT = COEFFGENLAT - GMRBDEL - 32'd1;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  // Clocks and resets
  input clk;
  input rst;

  // Floating point control
  input fp_en;

  // Particle information
  input                 pvalid;
  input [GADDRW1DX-1:0] px;
  input       [OIW-1:0] poix;
  input [GADDRW1DY-1:0] py;
  input       [OIW-1:0] poiy;
  input [GADDRW1DZ-1:0] pz;
  input       [OIW-1:0] poiz;
  input          [31:0] pq;

  // Coefficient Information
  output                                                  coeff_valid;
  output [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]         [31:0] coeff_data;

  output                                                  coord_valid;
  output [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                coord_en;
  output [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] coordx;
  output [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] coordy;
  output [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] coordz;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar gii;
  genvar gjj;
  genvar gkk;

  wire stall = ~fp_en;

  // --------------------------------------------------------------------------
  // Internal Signals
  //
  reg [COORDGENLAT-2:0][GADDRW1DX-1:0] i_px;   // Particle's x-coordinate
  reg [COORDGENLAT-2:0][GADDRW1DY-1:0] i_py;   // Particle's y-coordinate
  reg [COORDGENLAT-2:0][GADDRW1DZ-1:0] i_pz;   // Particle's z-coordinate

  wire [2:0]         [31:0] i_poix; // Particle's x-dimension oi value
  wire [2:0]         [31:0] i_poiy; // Particle's y-dimension oi value
  wire [2:0]         [31:0] i_poiz; // Particle's z-dimension oi value

  wire [5:0]         [31:0] i_pq;   // Particle's charge value

  wire [2:1]         [31:0] poix2; // Particle's x-dimension oi^2
  wire [2:1]         [31:0] poiy2; // Particle's y-dimension oi^2
  wire [2:1]         [31:0] poiz2; // Particle's z-dimension oi^2

  wire [2:2]         [31:0] poix3; // Particle's x-dimension oi^3
  wire [2:2]         [31:0] poiy3; // Particle's y-dimension oi^3
  wire [2:2]         [31:0] poiz3; // Particle's z-dimension oi^3

  reg [COEFFGENLAT-1:0] ctrl_pv; // particle valid

  wire [NNN1D-1:0][ORDER:1][31:0] oi_poly_x;
  wire [NNN1D-1:0][ORDER:1][31:0] oi_poly_y;
  wire [NNN1D-1:0][ORDER:1][31:0] oi_poly_z;

  wire [NNN1D-1:0][ORDER:1][31:0] scaled_oi_poly_x;
  wire [NNN1D-1:0][ORDER:1][31:0] scaled_oi_poly_y;
  wire [NNN1D-1:0][ORDER:1][31:0] scaled_oi_poly_z;
  
  wire [NNN1D-1:0][(ORDER+1)/2-1:0][31:0] oi_poly_psum_x;
  wire [NNN1D-1:0][(ORDER+1)/2-1:0][31:0] oi_poly_psum_y;
  wire [NNN1D-1:0][(ORDER+1)/2-1:0][31:0] oi_poly_psum_z;

  wire [NNN1D-1:0][31:0] oi_poly_sum_x;
  wire [NNN1D-1:0][31:0] oi_poly_sum_y;
  wire [NNN1D-1:0][31:0] oi_poly_sum_z;

  wire [NNN1D-1:0][NNN1D-1:0][31:0] yx;
  wire [NNN1D-1:0]           [31:0] qz;
  wire [NNN1D-1:0]           [31:0] z1;

  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0]                i_coord_en;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DX-1:0] i_coordx;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DY-1:0] i_coordy;
  wire [NNN1D-1:0][NNN1D-1:0][NNN1D-1:0][GADDRW1DZ-1:0] i_coordz;

  // --------------------------------------------------------------------------
  // Stage 0: Fixed-to-Floating-Point Conversion
  //
  toFp u_stage0_oix (
    .clk    (clk),                  // (I) Clock
    .areset (rst),                  // (I) Reset
    .en     (fp_en),                // (I) Enable
    .a      ({{OIPW{1'd0}}, poix}), // (I) Fixed-point input
    .q      (i_poix[0])             // (O) Floating-point output
  );

  toFp u_stage0_oiy (
    .clk    (clk),                  // (I) Clock
    .areset (rst),                  // (I) Reset
    .en     (fp_en),                // (I) Enable
    .a      ({{OIPW{1'd0}}, poiy}), // (I) Fixed-point input
    .q      (i_poiy[0])             // (O) Floating-point output
  );

  toFp u_stage0_oiz (
    .clk    (clk),                  // (I) Clock
    .areset (rst),                  // (I) Reset
    .en     (fp_en),                // (I) Enable
    .a      ({{OIPW{1'd0}}, poiz}), // (I) Fixed-point input
    .q      (i_poiz[0])             // (O) Floating-point output
  );

  generate
    if (CTYPE == 2'b00) begin : s0q_cmap
      // Charge coefficients require Q
      toFp u_toFp (
        .clk    (clk),     // (I) Clock
        .areset (rst),     // (I) Reset
        .en     (fp_en),   // (I) Enable
        .a      (pq),      // (I) Fixed-point input
        .q      (i_pq[0])  // (O) Floating-point output
      );
    end else begin : s0q_fmap
      // Force coefficients do not require Q
      assign i_pq[0] = 32'd0;

      wire unused_ok = |{pq, 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 1: Generate oi^2
  //
  FpMul u_stage1_oix2 (
    .clk    (clk),       // (I) Clock
    .areset (rst),       // (I) Reset
    .en     (fp_en),     // (I) Enable
    .a      (i_poix[0]), // (I) Multiplicand
    .b      (i_poix[0]), // (I) Multiplicand
    .q      (poix2[1])  // (O) Product
  );

  FpMul u_stage1_oiy2 (
    .clk    (clk),       // (I) Clock
    .areset (rst),       // (I) Reset
    .en     (fp_en),     // (I) Enable
    .a      (i_poiy[0]), // (I) Multiplicand
    .b      (i_poiy[0]), // (I) Multiplicand
    .q      (poiy2[1])   // (O) Product
  );

  FpMul u_stage1_oiz2 (
    .clk    (clk),       // (I) Clock
    .areset (rst),       // (I) Reset
    .en     (fp_en),     // (I) Enable
    .a      (i_poiz[0]), // (I) Multiplicand
    .b      (i_poiz[0]), // (I) Multiplicand
    .q      (poiz2[1])   // (O) Product
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage1_oix (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poix[0]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poix[1])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage1_oiy (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poiy[0]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poiy[1])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage1_oiz (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poiz[0]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poiz[1])  // (O) Output
  );

  generate
    if (CTYPE == 2'b00) begin : s1q_cmap
      // Charge coefficients require Q
      customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
        .clk   (clk),     // (I) Clock
        .rst   (rst),     // (I) Reset
        .x     (i_pq[0]), // (I) Input to be delayed
        .stall (stall),   // (I) Pipeline Stall
        .y     (i_pq[1])  // (O) Output
      );
    end else begin : s1q_fmap
      // Force coefficients do not require Q
      assign i_pq[1] = 32'd0;

      wire unused_ok = | {i_pq[0], 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 2: Generate oi^3
  //
  generate
    if (CTYPE == 2'b01) begin : oix3_coeff_zero
      // Coefficient of oix^3 is 0, no need to generate oix^3
      assign poix3[2] = 32'd0;
    end else begin : non_zero_oix3_coeff
      // Coefficient of oix^3 is non-zero, generate oix^3
      FpMul u_stage2_oix3 (
        .clk    (clk),       // (I) Clock
        .areset (rst),       // (I) Reset
        .en     (fp_en),     // (I) Enable
        .a      (i_poix[1]), // (I) Multiplicand
        .b      (poix2[1]), // (I) Multiplicand
        .q      (poix3[2])  // (O) Product
      );
    end

    if (CTYPE == 2'b10) begin : oiy3_coeff_zero
      // Coefficient of oiy^3 is 0, no need to generare oiy^3
      assign poiy3[2] = 32'd0;
    end else begin : non_zero_oiy3_coeff
      FpMul u_stage2_oiy3 (
        .clk    (clk),       // (I) Clock
        .areset (rst),       // (I) Reset
        .en     (fp_en),     // (I) Enable
        .a      (i_poiy[1]),  // (I) Multiplicand
        .b      (poiy2[1]), // (I) Multiplicand
        .q      (poiy3[2])  // (O) Product
      );
    end

    if (CTYPE == 2'b11) begin : oiz3_coeff_zero
      // Coefficient of oiz^3 is 0, no need to generare oiz^3
      assign poiz3[2] = 32'd0;
    end else begin : non_zero_oiz3_coeff
      FpMul u_stage2_oiz3 (
        .clk    (clk),       // (I) Clock
        .areset (rst),       // (I) Reset
        .en     (fp_en),     // (I) Enable
        .a      (i_poiz[1]), // (I) Multiplicand
        .b      (poiz2[1]),  // (I) Multiplicand
        .q      (poiz3[2])   // (O) Product
      );
    end
  endgenerate

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oix2 (
    .clk   (clk),      // (I) Clock
    .rst   (rst),      // (I) Reset
    .x     (poix2[1]), // (I) Input to be delayed
    .stall (stall),    // (I) Pipeline Stall
    .y     (poix2[2])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oiy2 (
    .clk   (clk),      // (I) Clock
    .rst   (rst),      // (I) Reset
    .x     (poiy2[1]), // (I) Input to be delayed
    .stall (stall),    // (I) Pipeline Stall
    .y     (poiy2[2])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oiz2 (
    .clk   (clk),      // (I) Clock
    .rst   (rst),      // (I) Reset
    .x     (poiz2[1]), // (I) Input to be delayed
    .stall (stall),    // (I) Pipeline Stall
    .y     (poiz2[2])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oix (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poix[1]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poix[2])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oiy (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poiy[1]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poiy[2])  // (O) Output
  );

  customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_stage2_oiz (
    .clk   (clk),       // (I) Clock
    .rst   (rst),       // (I) Reset
    .x     (i_poiz[1]), // (I) Input to be delayed
    .stall (stall),     // (I) Pipeline Stall
    .y     (i_poiz[2])  // (O) Output
  );

  generate
    if (CTYPE == 2'b00) begin : s2q_cmap
      // Charge coefficients require Q
      customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
        .clk   (clk),     // (I) Clock
        .rst   (rst),     // (I) Reset
        .x     (i_pq[1]), // (I) Input to be delayed
        .stall (stall),   // (I) Pipeline Stall
        .y     (i_pq[2])  // (O) Output
      );
    end else begin : s2q_fmap
      // Force coefficients do not require Q
      assign i_pq[2] = 32'd0;

      wire unused_ok = | {i_pq[1], 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 3: Multiply powers of oi by basis function polynomial coefficients
  //
  assign oi_poly_x = {NNN1D{poix3[2], poix2[2], i_poix[2]}};
  assign oi_poly_y = {NNN1D{poiy3[2], poiy2[2], i_poiy[2]}};
  assign oi_poly_z = {NNN1D{poiz3[2], poiz2[2], i_poiz[2]}};

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s3nnnx
    for (gjj=1; gjj<=ORDER; gjj=gjj+1) begin : oi_power
      if (BFCP_X[gii][gjj] == FP_0) begin : mulby0
        assign scaled_oi_poly_x[gii][gjj] = 32'd0;

        wire unused_ok  = |{oi_poly_x[gii][gjj], 1'd1};
      end else begin : mulby_nonzero
        if (BFCP_X[gii][gjj] == FP_1) begin : mulby1
          customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
            .clk   (clk),                       // (I) Clock
            .rst   (rst),                       // (I) Reset
            .x     (oi_poly_x[gii][gjj]),       // (I) Input to be delayed
            .stall (stall),                     // (I) Pipeline Stall
            .y     (scaled_oi_poly_x[gii][gjj]) // (O) Output
          );
        end else begin : mulby_nonone
          FpMul u_FpMul (
            .clk    (clk),                       // (I) Clock
            .areset (rst),                       // (I) Reset
            .en     (fp_en),                     // (I) Enable
            .a      (oi_poly_x[gii][gjj]),       // (I) Multiplicand
            .b      (BFCP_X[gii][gjj]),          // (I) Multiplicand
            .q      (scaled_oi_poly_x[gii][gjj]) // (O) Product
          );        
        end
      end
    end
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s3nnny
    for (gjj=1; gjj<=ORDER; gjj=gjj+1) begin : oi_power
      if (BFCP_Y[gii][gjj] == FP_0) begin : mulby0
        assign scaled_oi_poly_y[gii][gjj] = 32'd0;

        wire unused_ok  = |{oi_poly_y[gii][gjj], 1'd1};
      end else begin : mulby_nonzero
        if (BFCP_Y[gii][gjj] == FP_1) begin : mulby1
          customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
            .clk   (clk),                       // (I) Clock
            .rst   (rst),                       // (I) Reset
            .x     (oi_poly_y[gii][gjj]),       // (I) Input to be delayed
            .stall (stall),                     // (I) Pipeline Stall
            .y     (scaled_oi_poly_y[gii][gjj]) // (O) Output
          );
        end else begin : mulby_nonone
          FpMul u_FpMul (
            .clk    (clk),                       // (I) Clock
            .areset (rst),                       // (I) Reset
            .en     (fp_en),                     // (I) Enable
            .a      (oi_poly_y[gii][gjj]),       // (I) Multiplicand
            .b      (BFCP_Y[gii][gjj]),          // (I) Multiplicand
            .q      (scaled_oi_poly_y[gii][gjj]) // (O) Product
          );        
        end
      end
    end
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s3nnnz
    for (gjj=1; gjj<=ORDER; gjj=gjj+1) begin : oi_power
      if (BFCP_Z[gii][gjj] == FP_0) begin : mulby0
        assign scaled_oi_poly_z[gii][gjj] = 32'd0;

        wire unused_ok  = |{oi_poly_z[gii][gjj], 1'd1};
      end else begin : mulby_nonzero
        if (BFCP_Z[gii][gjj] == FP_1) begin : mulby1
          customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
            .clk   (clk),                       // (I) Clock
            .rst   (rst),                       // (I) Reset
            .x     (oi_poly_z[gii][gjj]),       // (I) Input to be delayed
            .stall (stall),                     // (I) Pipeline Stall
            .y     (scaled_oi_poly_z[gii][gjj]) // (O) Output
          );
        end else begin : mulby_nonone
          FpMul u_FpMul (
            .clk    (clk),                       // (I) Clock
            .areset (rst),                       // (I) Reset
            .en     (fp_en),                     // (I) Enable
            .a      (oi_poly_z[gii][gjj]),       // (I) Multiplicand
            .b      (BFCP_Z[gii][gjj]),          // (I) Multiplicand
            .q      (scaled_oi_poly_z[gii][gjj]) // (O) Product
          );        
        end
      end
    end
  end

  generate
    if (CTYPE == 2'b00) begin : s3q_cmap
      // Charge coefficients require Q
      customdelay #(.DELAY(FPMULDEL), .WIDTH(32'd32)) u_delay (
        .clk   (clk),     // (I) Clock
        .rst   (rst),     // (I) Reset
        .x     (i_pq[2]), // (I) Input to be delayed
        .stall (stall),   // (I) Pipeline Stall
        .y     (i_pq[3])  // (O) Output
      );
    end else begin : s3q_fmap
      // Force coefficients do not require Q
      assign i_pq[3] = 32'd0;

      wire unused_ok = | {i_pq[2], 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 4: Partially sum up basis function for each nearest neighbor in each
  //          dimension
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : s4nnnx
    case ({(BFCP_X[gii][1] == FP_0), (BFCP_X[gii][0] == FP_0)})
      2'b00 : begin : add_oi_to_oi0
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_x[gii][1]), // (I) Multiplicand
          .b      (BFCP_X[gii][0]),           // (I) Multiplicand
          .q      (oi_poly_psum_x[gii][0])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_x[gii][1]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_x[gii][0])    // (O) Output
        );
      end
      2'b10 : begin : add_0_to_oi0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                   // (I) Clock
          .rst   (rst),                   // (I) Reset
          .x     (BFCP_X[gii][0]),        // (I) Input to be delayed
          .stall (stall),                 // (I) Pipeline Stall
          .y     (oi_poly_psum_x[gii][0]) // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_x[gii][1], 1'd1};
      end
      2'b11 : begin : psum_0_add_0_to_0
        assign oi_poly_psum_x[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_x[gii][1], 1'd1};
      end
    endcase

    case ({(BFCP_X[gii][3] == FP_0), (BFCP_X[gii][2] == FP_0)})
      2'b00 : begin : add_oi3_to_oi2
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_x[gii][3]), // (I) Multiplicand
          .b      (scaled_oi_poly_x[gii][2]), // (I) Multiplicand
          .q      (oi_poly_psum_x[gii][1])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi3_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_x[gii][3]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_x[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_x[gii][2], 1'd1};
      end
      2'b10 : begin : add_0_to_oi2
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_x[gii][2]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_x[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_x[gii][3], 1'd1};
      end
      2'b11 : begin : psum_1_add_0_to_0
        assign oi_poly_psum_x[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_x[gii][3:2], 1'd1};
      end
    endcase
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s4nnny
    case ({(BFCP_Y[gii][1] == FP_0), (BFCP_Y[gii][0] == FP_0)})
      2'b00 : begin : add_oi_to_oi0
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_y[gii][1]), // (I) Multiplicand
          .b      (BFCP_Y[gii][0]),           // (I) Multiplicand
          .q      (oi_poly_psum_y[gii][0])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_y[gii][1]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_y[gii][0])    // (O) Output
        );
      end
      2'b10 : begin : add_0_to_oi0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                   // (I) Clock
          .rst   (rst),                   // (I) Reset
          .x     (BFCP_Y[gii][0]),        // (I) Input to be delayed
          .stall (stall),                 // (I) Pipeline Stall
          .y     (oi_poly_psum_y[gii][0]) // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_y[gii][1], 1'd1};
      end
      2'b11 : begin : psum_0_add_0_to_0
        assign oi_poly_psum_y[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_y[gii][1], 1'd1};
      end
    endcase

    case ({(BFCP_Y[gii][3] == FP_0), (BFCP_Y[gii][2] == FP_0)})
      2'b00 : begin : add_oi3_to_oi2
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_y[gii][3]), // (I) Multiplicand
          .b      (scaled_oi_poly_y[gii][2]), // (I) Multiplicand
          .q      (oi_poly_psum_y[gii][1])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi3_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_y[gii][3]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_y[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_y[gii][2], 1'd1};
      end
      2'b10 : begin : add_0_to_oi2
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_y[gii][2]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_y[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_y[gii][3], 1'd1};
      end
      2'b11 : begin : psum_1_add_0_to_0
        assign oi_poly_psum_y[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_y[gii][3:2], 1'd1};
      end
    endcase
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s4nnnz
    case ({(BFCP_Z[gii][1] == FP_0), (BFCP_Z[gii][0] == FP_0)})
      2'b00 : begin : add_oi_to_oi0
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_z[gii][1]), // (I) Multiplicand
          .b      (BFCP_Z[gii][0]),           // (I) Multiplicand
          .q      (oi_poly_psum_z[gii][0])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_z[gii][1]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_z[gii][0])    // (O) Output
        );
      end
      2'b10 : begin : add_0_to_oi0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                   // (I) Clock
          .rst   (rst),                   // (I) Reset
          .x     (BFCP_Z[gii][0]),        // (I) Input to be delayed
          .stall (stall),                 // (I) Pipeline Stall
          .y     (oi_poly_psum_z[gii][0]) // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_z[gii][1], 1'd1};
      end
      2'b11 : begin : psum_0_add_0_to_0
        assign oi_poly_psum_z[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_z[gii][1], 1'd1};
      end
    endcase

    case ({(BFCP_Z[gii][3] == FP_0), (BFCP_Z[gii][2] == FP_0)})
      2'b00 : begin : add_oi3_to_oi2
        FpAdd u_FpAdd (
          .clk    (clk),                      // (I) Clock
          .areset (rst),                      // (I) Reset
          .en     (fp_en),                    // (I) Enable
          .a      (scaled_oi_poly_z[gii][3]), // (I) Multiplicand
          .b      (scaled_oi_poly_z[gii][2]), // (I) Multiplicand
          .q      (oi_poly_psum_z[gii][1])    // (O) Product
        );        
      end
      2'b01 : begin : add_oi3_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_z[gii][3]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_z[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_z[gii][2], 1'd1};
      end
      2'b10 : begin : add_0_to_oi2
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                      // (I) Clock
          .rst   (rst),                      // (I) Reset
          .x     (scaled_oi_poly_z[gii][2]), // (I) Input to be delayed
          .stall (stall),                    // (I) Pipeline Stall
          .y     (oi_poly_psum_z[gii][1])    // (O) Output
        );

        wire unused_ok = |{scaled_oi_poly_z[gii][3], 1'd1};
      end
      2'b11 : begin : psum_1_add_0_to_0
        assign oi_poly_psum_z[gii][0] = 32'd0;

        wire unused_ok = |{scaled_oi_poly_z[gii][3:2], 1'd1};
      end
    endcase
  end

  generate
    if (CTYPE == 2'b00) begin : s4q_cmap
      // Charge coefficients require Q
      customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
        .clk   (clk),     // (I) Clock
        .rst   (rst),     // (I) Reset
        .x     (i_pq[3]), // (I) Input to be delayed
        .stall (stall),   // (I) Pipeline Stall
        .y     (i_pq[4])  // (O) Output
      );
    end else begin : s4q_fmap
      // Force coefficients do not require Q
      assign i_pq[4] = 32'd0;

      wire unused_ok = | {i_pq[3], 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 5: Sum up basis function for each nearest neighbor in each
  //          dimension
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : s5nnnx
    case ({((BFCP_X[gii][3] == FP_0) && (BFCP_X[gii][2] == FP_0)), 
           ((BFCP_X[gii][1] == FP_0) && (BFCP_X[gii][0] == FP_0))})
      2'b00 : begin : add_ps1_to_ps0
        FpAdd u_FpAdd (
          .clk    (clk),                    // (I) Clock
          .areset (rst),                    // (I) Reset
          .en     (fp_en),                  // (I) Enable
          .a      (oi_poly_psum_x[gii][1]), // (I) Multiplicand
          .b      (oi_poly_psum_x[gii][0]), // (I) Multiplicand
          .q      (oi_poly_sum_x[gii])      // (O) Product
        );        
      end
      2'b01 : begin : add_ps1_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_x[gii][1]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_x[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_x[gii][0], 1'd1};
      end
      2'b10 : begin : add_0_to_ps0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_x[gii][0]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_x[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_x[gii][1], 1'd1};
      end
      2'b11 : begin : add_0_to_0
        assign oi_poly_sum_x[gii] = 32'd0;

        wire unused_ok = |{oi_poly_psum_x[gii], 1'd1};
      end
    endcase
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s5nnny
    case ({((BFCP_Y[gii][3] == FP_0) && (BFCP_Y[gii][2] == FP_0)),
           ((BFCP_Y[gii][1] == FP_0) && (BFCP_Y[gii][0] == FP_0))})
      2'b00 : begin : add_ps1_to_ps0
        FpAdd u_FpAdd (
          .clk    (clk),                    // (I) Clock
          .areset (rst),                    // (I) Reset
          .en     (fp_en),                  // (I) Enable
          .a      (oi_poly_psum_y[gii][1]), // (I) Multiplicand
          .b      (oi_poly_psum_y[gii][0]), // (I) Multiplicand
          .q      (oi_poly_sum_y[gii])      // (O) Product
        );        
        end
      2'b01 : begin : add_ps1_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_y[gii][1]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_y[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_y[gii][0], 1'd1};
      end
      2'b10 : begin : add_0_to_ps0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_y[gii][0]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_y[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_y[gii][1], 1'd1};
      end
      2'b11 : begin : add_0_to_0
        assign oi_poly_sum_y[gii] = 32'd0;

        wire unused_ok = |{oi_poly_psum_y[gii], 1'd1};
      end
    endcase
  end

  for (gii=0; gii<NNN1D; gii=gii+1) begin : s5nnnz
    case ({((BFCP_Z[gii][3] == FP_0) && (BFCP_Z[gii][2] == FP_0)),
           ((BFCP_Z[gii][1] == FP_0) && (BFCP_Z[gii][0] == FP_0))})
      2'b00 : begin : add_ps1_to_ps0
        FpAdd u_FpAdd (
          .clk    (clk),                    // (I) Clock
          .areset (rst),                    // (I) Reset
          .en     (fp_en),                  // (I) Enable
          .a      (oi_poly_psum_z[gii][1]), // (I) Multiplicand
          .b      (oi_poly_psum_z[gii][0]), // (I) Multiplicand
          .q      (oi_poly_sum_z[gii])      // (O) Product
        );        
        end
      2'b01 : begin : add_ps1_to_0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_z[gii][1]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_z[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_z[gii][0], 1'd1};
      end
      2'b10 : begin : add_0_to_ps0
        customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
          .clk   (clk),                    // (I) Clock
          .rst   (rst),                    // (I) Reset
          .x     (oi_poly_psum_z[gii][0]), // (I) Input to be delayed
          .stall (stall),                  // (I) Pipeline Stall
          .y     (oi_poly_sum_z[gii])      // (O) Output
        );

        wire unused_ok = |{oi_poly_psum_z[gii][1], 1'd1};
      end
      2'b11 : begin : add_0_to_0
        assign oi_poly_sum_z[gii] = 32'd0;

        wire unused_ok = |{oi_poly_psum_z[gii], 1'd1};
      end
    endcase
  end

  generate
    if (CTYPE == 2'b00) begin : s5q_cmap
      // Charge coefficients require Q
      customdelay #(.DELAY(FPADDDEL), .WIDTH(32'd32)) u_delay (
        .clk   (clk),     // (I) Clock
        .rst   (rst),     // (I) Reset
        .x     (i_pq[4]), // (I) Input to be delayed
        .stall (stall),   // (I) Pipeline Stall
        .y     (i_pq[5])  // (O) Output
      );
    end else begin : s5q_fmap
      // Force coefficients do not require Q
      assign i_pq[5] = 32'd0;

      wire unused_ok = | {i_pq[4], 1'b1};
    end
  endgenerate

  // --------------------------------------------------------------------------
  // Stage 6: Generate 16 combinations of y*z and 4 combinations of q*z
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : s6nnny
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : s6nnnx
      FpMul u_FpMul (
        .clk    (clk),                // (I) Clock
        .areset (rst),                // (I) Reset
        .en     (fp_en),              // (I) Enable
        .a      (oi_poly_sum_y[gii]), // (I) Multiplicand
        .b      (oi_poly_sum_x[gjj]), // (I) Multiplicand
        .q      (yx[gii][gjj])        // (O) Product
      );        
    end
  end
  
  for (gii=0; gii<NNN1D; gii=gii+1) begin : s6nnnz
    if (CTYPE == 2'b00) begin : mul_z_by_q
      FpMul u_FpMul (
        .clk    (clk),                // (I) Clock
        .areset (rst),                // (I) Reset
        .en     (fp_en),              // (I) Enable
        .a      (oi_poly_sum_z[gii]), // (I) Multiplicand
        .b      (i_pq[5]),            // (I) Multiplicand
        .q      (qz[gii])             // (O) Product
      );        
      
      assign z1[gii] = 32'd0;
    end else begin : mul_z_by_1
      customdelay #(.DELAY(FPMULDEL), .WIDTH(32)) u_delay (
        .clk   (clk),                // (I) Clock
        .rst   (rst),                // (I) Reset
        .x     (oi_poly_sum_z[gii]), // (I) Input to be delayed
        .stall (stall),              // (I) Pipeline Stall
        .y     (z1[gii])             // (O) Output
      );
      
      assign qz[gii] = 32'd0;

      wire unused_ok = |{i_pq[5], 1'b1};
    end
  end

  // --------------------------------------------------------------------------
  // Stage 7: Generate 64 Combinations of q*x*y*z
  //
  for (gii=0; gii<NNN1D; gii=gii+1) begin : s7nnnz
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : s7nnny
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : s7nnnx
        if (CTYPE == 2'b00) begin : mul_xy_by_qz
          FpMul u_FpMul (
            .clk    (clk),                      // (I) Clock
            .areset (rst),                      // (I) Reset
            .en     (fp_en),                    // (I) Enable
            .a      (yx[gjj][gkk]),             // (I) Multiplicand
            .b      (qz[gii]),                  // (I) Multiplicand
            .q      (coeff_data[gii][gjj][gkk]) // (O) Product
          );

          wire unused_ok = |{z1[gii], 1'd1};
        end else begin : mul_xy_by_z
          FpMul u_FpMul (
            .clk    (clk),                      // (I) Clock
            .areset (rst),                      // (I) Reset
            .en     (fp_en),                    // (I) Enable
            .a      (yx[gjj][gkk]),             // (I) Multiplicand
            .b      (z1[gii]),                  // (I) Multiplicand
            .q      (coeff_data[gii][gjj][gkk]) // (O) Product
          );

          wire unused_ok = |{qz[gii], 1'd1};
        end
      end
    end
  end

  // Generate Coefficient validation signal
  always @(posedge clk) begin : coeff_del0
    if (rst) begin
      ctrl_pv[0] <= 1'd0;
    end else begin
      if (stall) begin
        ctrl_pv[0] <= ctrl_pv[0];
      end else begin
        ctrl_pv[0] <= pvalid;
      end
    end
  end

  for (gii=1; gii<COEFFGENLAT; gii=gii+1) begin : coeff_del
    always @(posedge clk) begin : seq
      if (rst) begin
        ctrl_pv[gii] <= 1'd0;
      end else begin
        if (stall) begin
          ctrl_pv[gii] <= ctrl_pv[gii];
        end else begin
          ctrl_pv[gii] <= ctrl_pv[gii-1];
        end
      end
    end
  end

  assign coeff_valid = ctrl_pv[COEFFGENLAT-1];
  
  // --------------------------------------------------------------------------
  // Coordinate Generation
  //
  always @(posedge clk) begin : coord_del0
    if (rst) begin
      i_px[0] <= {GADDRW1DX{1'd0}};
      i_py[0] <= {GADDRW1DY{1'd0}};
      i_pz[0] <= {GADDRW1DZ{1'd0}};
    end else begin
      if (stall) begin
        i_px[0] <= i_px[0];
        i_py[0] <= i_py[0];
        i_pz[0] <= i_pz[0];
      end else begin
        i_px[0] <= px;
        i_py[0] <= py;
        i_pz[0] <= pz;
      end
    end
  end

  for (gii=1; gii<COORDGENLAT-1; gii=gii+1) begin : coord_del
    always @(posedge clk) begin : seq
      if (rst) begin
        i_px[gii] <= {GADDRW1DX{1'd0}};
        i_py[gii] <= {GADDRW1DY{1'd0}};
        i_pz[gii] <= {GADDRW1DZ{1'd0}};
      end else begin
        if (stall) begin
          i_px[gii] <= i_px[gii];
          i_py[gii] <= i_py[gii];
          i_pz[gii] <= i_pz[gii];
        end else begin
          i_px[gii] <= i_px[gii-1];
          i_py[gii] <= i_py[gii-1];
          i_pz[gii] <= i_pz[gii-1];
        end
      end
    end
  end

  // Generate NNN3D coordinates from singular (x,y,z) coordinate which
  // represents center (min(x)+1, min(y)+1, min(z)+1) coordinate of nearest
  // neighborhood cluster
  for (gii=0; gii<NNN1D; gii=gii+1) begin : gen_coord_z
    for (gjj=0; gjj<NNN1D; gjj=gjj+1) begin : gen_coord_y
      for (gkk=0; gkk<NNN1D; gkk=gkk+1) begin : gen_coord_x
        // Create index minus one using parameters
        localparam giim1 = gii - 32'd1;
        localparam gjjm1 = gjj - 32'd1;
        localparam gkkm1 = gkk - 32'd1;

        // Assign the index-1 to a wire first then add it to pgm_*.
        // Some tools, when adding an appropriately sized constant of zero, do not
        // require an extra bit of width for the sum which triggers warnings
        // about unequal sized variables on opposite sides of = in an
        // assignment
        //
        wire signed [GADDRW1DZ:0] z_add = $signed(giim1[GADDRW1DZ:0]);
        wire signed [GADDRW1DY:0] y_add = $signed(gjjm1[GADDRW1DY:0]);
        wire signed [GADDRW1DX:0] x_add = $signed(gkkm1[GADDRW1DX:0]);

        wire signed [GADDRW1DZ+1:0] z_plus = $signed({1'd0, i_pz[COORDGENLAT-2]}) + z_add;
        wire signed [GADDRW1DY+1:0] y_plus = $signed({1'd0, i_py[COORDGENLAT-2]}) + y_add;
        wire signed [GADDRW1DX+1:0] x_plus = $signed({1'd0, i_px[COORDGENLAT-2]}) + x_add;

        assign i_coordz[gii][gjj][gkk] = z_plus[GADDRW1DZ-1:0];
        assign i_coordy[gii][gjj][gkk] = y_plus[GADDRW1DY-1:0];
        assign i_coordx[gii][gjj][gkk] = x_plus[GADDRW1DX-1:0];

        assign i_coord_en[gii][gjj][gkk] = ctrl_pv[COORDGENLAT-2];

        // Generate valid coordinates ahead of time so that valid read data from grid
        // is aligned with valid coefficient data
        customdelay #(.DELAY(32'd1), .WIDTH(1)) u_coord_en_gen (
          .clk   (clk),                       // (I) Clock
          .rst   (rst),                       // (I) Reset
          .x     (i_coord_en[gii][gjj][gkk]), // (I) Input to be delayed
          .stall (stall),                     // (I) Pipeline Stall
          .y     (coord_en[gii][gjj][gkk])    // (I) Output
        );

        customdelay #(.DELAY(1), .WIDTH(GADDRW1DX)) u_coordx_gen (
          .clk   (clk),                     // (I) Clock
          .rst   (rst),                     // (I) Reset
          .x     (i_coordx[gii][gjj][gkk]), // (I) Input to be delayed
          .stall (stall),                   // (I) Pipeline Stall
          .y     (coordx[gii][gjj][gkk])    // (I) Output
        );

        customdelay #(.DELAY(1), .WIDTH(GADDRW1DY)) u_coordy_gen (
          .clk   (clk),                     // (I) Clock
          .rst   (rst),                     // (I) Reset
          .x     (i_coordy[gii][gjj][gkk]), // (I) Input to be delayed
          .stall (stall),                   // (I) Pipeline Stall
          .y     (coordy[gii][gjj][gkk])    // (I) Output
        );

        customdelay #(.DELAY(1), .WIDTH(GADDRW1DZ)) u_coordz_gen (
          .clk   (clk),                     // (I) Clock
          .rst   (rst),                     // (I) Reset
          .x     (i_coordz[gii][gjj][gkk]), // (I) Input to be delayed
          .stall (stall),                   // (I) Pipeline Stall
          .y     (coordz[gii][gjj][gkk])    // (I) Output
        );

        wire unused_ok = |{x_plus[GADDRW1DX+1-:2], y_plus[GADDRW1DY+1-:2], z_plus[GADDRW1DZ+1-:2], 1'b1};
      end
    end
  end

  assign coord_valid = ctrl_pv[COORDGENLAT-1];


endmodule
