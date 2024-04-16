// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : md_lr_top_tb.sv
// Description    : Testbench for md_lr_top
// 
// ============================================================================

module md_lr_top_tb ();
  
  // --------------------------------------------------------------------------
  // Package Imports
  //
  import md_lr_pkg::*;

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // 1D Grid Dimensions
  parameter GSIZE1DX = 32'd32;
  parameter GSIZE1DY = 32'd32;
  parameter GSIZE1DZ = 32'd32;
  
  // Maximum number of particles
  parameter MAXNUMP = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Number of lines in the particle info file.
  parameter NUMLINES = 34429;
  

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
  // Grid size in 3D
  localparam GSIZE3D = GSIZE1DX*GSIZE1DY*GSIZE1DZ;

  // Width of 1D grid addresses
  localparam GADDRW1DX = $clog2(GSIZE1DX);
  localparam GADDRW1DY = $clog2(GSIZE1DY);
  localparam GADDRW1DZ = $clog2(GSIZE1DZ);
  
  // Particle Data Width
  localparam PDATAW = GADDRW1DZ + GADDRW1DY + GADDRW1DX + 32'd3*OIW + 32'd32;

  // Width of grid address in 3D
  localparam GADDRW3D = $clog2(GSIZE3D);
  
  // Number of nearest neighbors in 3D
  localparam NNN3D = NNN1D*NNN1D*NNN1D;

  // Address width of nearest neighbor in one dimension
  localparam NN1DIDW = $clog2(NNN1D);
  
  // Width of particle address bus
  localparam PADDRW = $clog2(MAXNUMP);

  // Width of line address for input data
  localparam LINEADDRW = $clog2(NUMLINES);

  // Width of floating point values
  localparam FPVW = 32'd32;

  // Bit width of each grid element
  localparam GELEW = FPVW+FPVW;

  // Force Data Width
  localparam FDATAW = 32'd96;

  // Latency of Green's function
  localparam GRNDEL = 32'd5;
  
  // Grid Memory Readback Latency
  localparam GMRBDEL0 = (GMRDTYPE == 2'd0) ? 32'd0 :
                        (GMRDTYPE == 2'd1) ? 32'd1 :
                        (GMRDTYPE == 2'd2) ? 32'd1 : 32'd2;

  localparam GMRBDEL = GMRBDEL0 + 32'd6;

  localparam GMRBDELMSBIT = (GMRBDEL == 32'd0) ? 32'd0 : GMRBDEL - 32'd2;

  // Output file
  int fd;

  initial begin
    fd = $fopen("./rtl_sim_values.txt", "w");
    if(!fd)begin
      $display("Failed to open output file.\n");
      $finish();
    end
  end

  // --------------------------------------------------------------------------
  // Includes
  //
  //`include "particle_info.svh"
  `include "particle_info_new.svh"
  `include "particle_info_old.svh"
  `include "gmem_map_check_values.svh"
  `include "gmem_fftx_check_values.svh"
  `include "gmem_ffty_check_values.svh"
  `include "gmem_fftzng_check_values.svh"
  `include "gmem_ifftx_check_values.svh"
  `include "gmem_iffty_check_values.svh"
  `include "gmem_ifftz_check_values.svh"
  `include "force_info.svh"

  // --------------------------------------------------------------------------
  // Internal Signals
  //
  reg                   clk;
  
  wire                  pready;
  reg                   pvalid;
  reg      [PADDRW-1:0] paddr;
  reg                   pwe;
  reg      [PDATAW-1:0] pwdata;
  reg                   plast;
  reg   [LINEADDRW-1:0] plineaddr;

  reg                   fready;
  wire                  fvalid;
  wire     [PADDRW-1:0] faddr;
  wire                  flast;
  wire     [FDATAW-1:0] fdata;

  reg                   pvaliden;

  reg [6:0] fvalidcount;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  integer iii;
  integer ijj;

  genvar  gii;
  genvar  gjj;
  genvar  gkk;
  
  shortreal exper [1:0];
  shortreal theor [1:0];
  shortreal error [1:0];

  // --------------------------------------------------------------------------
  // DUT
  //
  md_lr_top #(
    .GSIZE1DX  (GSIZE1DX), // Size of the X dimension
    .GSIZE1DY  (GSIZE1DY), // Size of the Y dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of the Z dimension
    .MAXNUMP   (MAXNUMP),  // Maximum number of particles
    .PMRDTYPE  (PMRDTYPE), // Read delay timing of particle memory
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .GMRDTYPE  (GMRDTYPE), // Read delay timing of grid mem blocks
    .MAXFFTP   (MAXFFTP)   // Maximum input data points for the FFT IP
  ) DUT (
    // Clocks and resets
    .clk (clk),    // (I) Clock

    // Particle Memory Interface
    .pready (pready), // (O) Particle Memory ready
    .pvalid (pvalid), // (I) Particle Memory control valid
    .paddr  (paddr),  // (I) Particle Memory address
    .pwe    (pwe),    // (I) Particle Memory write enable
    .pwdata (pwdata), // (I) Particle Memory write data
    .plast  (plast),  // (I) Last particle data indicator
  
    // Force Memory Interface
    .fready (fready), // (I) Force ready
    .fvalid (fvalid), // (O) Force valid
    .faddr  (faddr),  // (O) Force address
    .flast  (flast),  // (O) Last particle data indicator
    .fdata  (fdata)  // (O) Force read data
  );

  // --------------------------------------------------------------------------
  // Stimulus Generation
  //
  always @(clk) begin : clock_gen
    #5 clk <= ~clk;
  end

  // Toggle pvalid and fready to test qualification of data and back-pressure
  // on system
  // always @(posedge clk) begin
  //   if (fvalid) begin
  //     if (fvalidcount == 100) begin
  //       fvalidcount <= fvalidcount;
  //       fready <= $random % 2;
  //     end else begin
  //       fvalidcount <= fvalidcount + 1;
  //       fready <= 0;
  //     end
  //   end else begin
  //       fvalidcount <= 0;
  //       fready <= 0;
  //   end 
  // end

  always @(posedge clk) begin
    if (fvalid) begin
      fvalidcount <= fvalidcount;
      fready      <= 1;
    end else begin
        fvalidcount <= 0;
        fready      <= 0;
    end 
  end

  //always @(*)begin
  //   pvalid = pvaliden;
  //end

  initial begin
    plineaddr = 0;
    force DUT.rst = 1;
     
    for(iii=0; iii<MAXNUMP; iii=iii+1) begin
      DUT.u_particle_mem.block[0].mem_array[iii] = 0;
    end

    fvalidcount = 0;

    // Initialize clock
    clk = 1'd0;
    
    // Start off being ready for force values
    fready = 1'd1;

    // Start at address 0
    paddr = 0;

    // Start off invalid
    pvalid = 0;
    pvaliden = 0;

    if (NUMP == 1) begin
      plast = 1;
    end else begin
      plast = 0;
    end

    // Start off with write asserted
    pwe = 1;

    // Data = Address
    pwdata = P_INFO_NEW[plineaddr][PDATAW-1:0];

    #40;
    force DUT.rst = 0;

    // Wait for reset de-assertion synchronization before doing anything
    #60;

    // Wait for the pready signal
    wait(DUT.pready);

    @(posedge clk)begin
      pvalid <= P_INFO_NEW[plineaddr][PDATAW]; // Valid bit is the MSB of P_INFO_NEW
    end

    repeat(NUMLINES-1) @(posedge clk)begin
      plineaddr <= plineaddr + 1;
      pwdata    <= P_INFO_NEW[plineaddr+1][PDATAW-1:0];
      pvalid    <= P_INFO_NEW[plineaddr+1][PDATAW];
      if(pvalid)begin
        paddr <= paddr + 1;
      end
      if(plineaddr == NUMLINES-2)begin
        plast <= 1'b1;
      end
    end

    @(posedge clk)begin
      pvalid <= 1'b0;
      plast  <= 1'b0;
    end


    wait (fvalid == 1'b1 && fready == 1'b1 && flast == 1'b1);
    #50;
    $fclose(fd);
    $finish();
    
  end

  for (gii=0; gii<GSIZE1DZ; gii=gii+1) begin : z
    for (gjj=0; gjj<GSIZE1DY; gjj=gjj+1) begin : y
      for (gkk=0; gkk<GSIZE1DX; gkk=gkk+1) begin : x
        localparam CBID = {gii[NN1DIDW-1:0], //LSBs
                           gjj[NN1DIDW-1:0],
                           gkk[NN1DIDW-1:0]};

        localparam CBIDX = {gii[GADDRW1DZ-1:NN1DIDW], //MSBs
                            gjj[GADDRW1DY-1:NN1DIDW],
                            gkk[GADDRW1DX-1:NN1DIDW]};

        initial begin
          // Zero out grid contents becuase number of particles is < # of grid elements
          DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] = 64'd0;

          // Check charge mapping before FFTX
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == FFTX);
          #21;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "Charge mapping RTL sim values\n");
          end
          $fdisplay(fd, "Charge map check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_CMAP_CHK[gkk][gjj][gii]) begin
            $display("[%0t] Charge map check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] Charge map check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_CMAP_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_CMAP_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_CMAP_CHK[gkk][gjj][gii][1]                                      , GMEM_CMAP_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          // Read out grid memory after FFTX
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == FFTY);
          //$finish;
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nFFTX RTL sim values\n");
          end
          $fdisplay(fd, "FFTX check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_FFTX_CHK[gkk][gjj][gii]) begin
            $display("[%0t] FFTX check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] FFTX check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_FFTX_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_FFTX_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_FFTX_CHK[gkk][gjj][gii][1]                                      , GMEM_FFTX_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          // Read out grid memory after FFTY
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == FFTZNG);
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nFFTY RTL sim values\n");
          end
          $fdisplay(fd, "FFTY check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_FFTY_CHK[gkk][gjj][gii]) begin
            $display("[%0t] FFTY check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] FFTY check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_FFTY_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_FFTY_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_FFTY_CHK[gkk][gjj][gii][1]                                      , GMEM_FFTY_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          // Read out grid memory after FFTZNG
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == IFFTX);
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nFFTZNG RTL sim values\n");
          end
          $fdisplay(fd, "FFTZNG check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_FFTZNG_CHK[gkk][gjj][gii]) begin
            $display("[%0t] FFTZ check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] FFTZ check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_FFTZNG_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_FFTZNG_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_FFTZNG_CHK[gkk][gjj][gii][1]                                      , GMEM_FFTZNG_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end
//////////////////////////////////
          //#1;
          //// Replace all values in the grid memory
          //$display("Replacing values in the grid memory after FFTZNG.");
          //DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] = GMEM_FFTZNG_CHK[gkk][gjj][gii];

//          // REead out memory ontents again.
//          $display("Read out memory contents after replacing with expected values post FFTNG.");
//          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_FFTZNG_CHK[gkk][gjj][gii]) begin
//            $display("[%0t] FFTZ check after replacing at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
//          end else begin
//            $display("[%0t] FFTZ check after replacing at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);
//
//            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
//            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
//            theor[1] = $bitstoshortreal(GMEM_FFTZNG_CHK[gkk][gjj][gii][1]);
//            theor[0] = $bitstoshortreal(GMEM_FFTZNG_CHK[gkk][gjj][gii][0]);
//
//            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
//                     GMEM_FFTZNG_CHK[gkk][gjj][gii][1]                                      , GMEM_FFTZNG_CHK[gkk][gjj][gii][0],
//                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
//
//            if (theor[1] != 0) begin
//              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
//              $display("[%0t] Percent error of Real : %f", $time, error[1]);
//                
//            end
//            if (theor[0] != 0) begin
//              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
//              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
//            end
//          end
//////////////////////////////////


          // Read out grid memory after IFFTX
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == IFFTY);
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nIFFTX RTL sim values\n");
          end
          $fdisplay(fd, "IFFTX check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_IFFTX_CHK[gkk][gjj][gii]) begin
            $display("[%0t] IFFTX check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] IFFTX check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_IFFTX_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_IFFTX_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_IFFTX_CHK[gkk][gjj][gii][1]                                     , GMEM_IFFTX_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          //#1;
          //// Replace all values in the grid memory
          //$display("Replacing values in the grid memory after IFFTX.");
          //DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] = GMEM_IFFTX_CHK[gkk][gjj][gii];



          // Read out grid memory after IFFTY
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == IFFTZ);
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nIFFTY RTL sim values\n");
          end
          $fdisplay(fd, "IFFTY check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_IFFTY_CHK[gkk][gjj][gii]) begin
            $display("[%0t] IFFTY check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] IFFTY check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_IFFTY_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_IFFTY_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_IFFTY_CHK[gkk][gjj][gii][1]                                     , GMEM_IFFTY_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          //#1;
          //// Replace all values in the grid memory
          //$display("Replacing values in the grid memory after IFFTY.");
          //DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] = GMEM_IFFTY_CHK[gkk][gjj][gii];



          // Read out grid memory after IFFTZ
          wait (DUT.u_md_lr_seqr.md_lr_seqr_state == FCALC);
          #41;
          if(gii == 0 & gjj == 0 & gkk == 0)begin
            $fdisplay(fd, "\n\n\nIFFTZ RTL sim values\n");
          end
          $fdisplay(fd, "IFFTZ check at coordinate (%0d, %0d, %0d): %h, %h", gkk, gjj, gii, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

          if (DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] == GMEM_IFFTZ_CHK[gkk][gjj][gii]) begin
            $display("[%0t] IFFTZ check at coordinate (%0d, %0d, %0d) PASSED." , $time, gkk, gjj, gii);
          end else begin
            $display("[%0t] IFFTZ check at (%0d, %0d, %0d) FAILED!", $time, gkk, gjj, gii);

            exper[1] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32]);
            exper[0] = $bitstoshortreal(DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);
            theor[1] = $bitstoshortreal(GMEM_IFFTZ_CHK[gkk][gjj][gii][1]);
            theor[0] = $bitstoshortreal(GMEM_IFFTZ_CHK[gkk][gjj][gii][0]);

            $display("[%0t] Expected: %h, %h  Received: %h %h", $time, 
                     GMEM_IFFTZ_CHK[gkk][gjj][gii][1]                                     , GMEM_IFFTZ_CHK[gkk][gjj][gii][0],
                     DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][63:32], DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX][31:0]);

            if (theor[1] != 0) begin
              error[1] = (exper[1] - theor[1]) / theor[1] * 100;
              $display("[%0t] Percent error of Real : %f", $time, error[1]);
                
            end
            if (theor[0] != 0) begin
              error[0] = (exper[0] - theor[0]) / theor[0] * 100;
              $display("[%0t] Percent error of Imaginary : %f", $time,  error[0]);
            end
          end

          //#1;
          //// Replace all values in the grid memory
          //$display("Replacing values in the grid memory after IFFTZ.");
          //DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX] = GMEM_IFFTZ_CHK[gkk][gjj][gii];

        end // initial begin
      end // block: x
    end 
  end

  initial begin
    wait (DUT.u_md_lr_seqr.md_lr_seqr_state == FCALC);
    $fdisplay(fd, "\n\n\nForce RTL sim values\n");

    for(iii=0; iii<NUMP; iii=iii+1) begin
      #1;
      wait (fvalid && fready);
      #1;
      $fdisplay(fd, "Force check for particle %0d: %h, %h, %h", iii, fdata[31:0], fdata[63:32], fdata[95:64]);
      /*(Fx, Fy, Fz) format for c header file.*/

      if (fdata[31:0] == P_FORCE[iii][0]) begin
        $display("[%0t] Force X check of particle at coordinate (%0d, %0d, %0d) PASSED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);
      end else begin
        $display("[%0t] Force X check of particle at coordinate (%0d, %0d, %0d) FAILED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);
         
        $display("[%0t] Expected: %h  Received: %h", $time, P_FORCE[iii][0], fdata[31:0]);

        exper[0] = $bitstoshortreal(fdata[31:0]);
        theor[0] = $bitstoshortreal(P_FORCE[iii][0]);

        if (theor[0] != 0) begin
          error[0] = (exper[0] - theor[0]) / theor[0] * 100;
          $display("[%0t] Percent error: %f", $time,  error[0]);
        end
      end
         
      if (fdata[63:32] == P_FORCE[iii][1]) begin
        $display("[%0t] Force Y check of particle at coordinate (%0d, %0d, %0d) PASSED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);
      end else begin
        $display("[%0t] Force Y check of particle at coordinate (%0d, %0d, %0d) FAILED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);

        $display("[%0t] Expected: %h  Received: %h", $time, P_FORCE[iii][1], fdata[63:32]);

        exper[0] = $bitstoshortreal(fdata[63:32]);
        theor[0] = $bitstoshortreal(P_FORCE[iii][1]);

        if (theor[0] != 0) begin
          error[0] = (exper[0] - theor[0]) / theor[0] * 100;
          $display("[%0t] Percent error: %f", $time,  error[0]);
        end
      end
         
      if (fdata[95:64] == P_FORCE[iii][2]) begin
        $display("[%0t] Force Z check of particle at coordinate (%0d, %0d, %0d) PASSED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);
      end else begin
        $display("[%0t] Force Z check of particle at coordinate (%0d, %0d, %0d) FAILED." ,
                 $time,
                 P_INFO[iii][(32+OIW)                             +: GADDRW1DX],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW)               +: GADDRW1DY],
                 P_INFO[iii][(32+OIW+GADDRW1DX+OIW+GADDRW1DY+OIW) +: GADDRW1DZ]);

        $display("[%0t] Expected: %h  Received: %h", $time, P_FORCE[iii][2], fdata[95:64]);

        exper[0] = $bitstoshortreal(fdata[95:64]);
        theor[0] = $bitstoshortreal(P_FORCE[iii][2]);

        if (theor[0] != 0) begin
          error[0] = (exper[0] - theor[0]) / theor[0] * 100;
          $display("[%0t] Percent error: %f", $time,  error[0]);
        end
      end
      @(posedge clk);
    end
  end

  initial begin
    #20000000;
    $display("Simulation Timeout!");
    $fclose(fd);
    $finish;
  end

  initial begin
    DUT.u_grid_mem.disable_assert = 1'd0;
    DUT.u_greens_rom.disable_assert = 1'd0;
    //wait (DUT.u_md_lr_seqr.md_lr_seqr_state == IFFTY);
    //#100;
    //$finish;
  end


  // Keep track of the (0,0,0) location of the clustered grid memory
//  initial begin
//    localparam gii = 0;
//    localparam gjj = 0;
//    localparam gkk = 0;
//
//    localparam CBID = {gii[NN1DIDW-1:0], //LSBs
//                       gjj[NN1DIDW-1:0],
//                       gkk[NN1DIDW-1:0]};
//
//    localparam CBIDX = {gii[GADDRW1DZ-1:NN1DIDW], //MSBs
//                        gjj[GADDRW1DY-1:NN1DIDW],
//                        gkk[GADDRW1DX-1:NN1DIDW]};
//
//    // $monitor statement for the same
//    $monitor("Time=%t Value Change for grid location(monitor) (%0d, %0d, %0d). New value = %h", $time, gii, gjj, gkk, DUT.u_grid_mem.nmem_z[gii%NNN1D].nmem_y[gjj%NNN1D].nmem_x[gkk%NNN1D].u_cluster_block.block[0].mem_array[CBIDX]);
//  end


endmodule
