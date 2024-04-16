//
// Copyright (c) 2017, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

`include "cci_mpf_if.vh"
`include "csr_mgr.vh"
`include "afu_json_info.vh"


module app_afu (
  // --------------------------------------------------------------------------
  // IO Declarations
  //  
  input  logic clk,

  // Connection toward the host.  Reset comes in here.
  cci_mpf_if.to_fiu fiu,

  // CSR connections
  app_csrs.app csrs,

  // MPF tracks outstanding requests.  These will be true as long as
  // reads or unacknowledged writes are still in flight.
  input  logic c0NotEmpty,
  input  logic c1NotEmpty
);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // 1D Grid Dimensions
  parameter GSIZE1DX = 32'd32;
  parameter GSIZE1DY = 32'd32;
  parameter GSIZE1DZ = 32'd32;
  
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

  // Maximum FFT points supported by the FFT IP
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

  // Width of CSRs
  localparam CSRW = 16;

  // oi value width - CSR width
  localparam OIWMCSR = OIW - CSRW;
  
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
  
  // --------------------------------------------------------------------------
  // Localized Reset
  //  
  // Local reset to reduce fan-out
  logic reset = 1'b1;

  always @(posedge clk) begin
    reset <= fiu.reset;
  end

  // --------------------------------------------------------------------------
  // Accellerator
  //
  wire                  pready;
  wire                  pvalid;
  reg      [PADDRW-1:0] paddr;
  wire                  pwe;
  reg      [PDATAW-1:0] pwdata;
  reg                   plast;

  wire                  fready;
  wire                  fvalid;
  wire     [PADDRW-1:0] faddr;
  wire                  flast;
  wire     [FDATAW-1:0] fdata;

  md_lr_top #(
    .GSIZE1DX  (GSIZE1DX), // Size of the X dimension
    .GSIZE1DY  (GSIZE1DY), // Size of the Y dimension
    .GSIZE1DZ  (GSIZE1DZ), // Size of the Z dimension
    .MAXNUMP   (MAXNUMP),  // Maximum number of particles
    .PMRDTYPE  (PMRDTYPE), // Read delay timing of particle memory
    .NNN1D     (NNN1D),    // Number of nearest neighbors along one dimension
    .GMRDTYPE  (GMRDTYPE), // Read delay timing of grid mem blocks
    .MAXFFTP   (MAXFFTP)   // Max FFT points supported by the FFT IP
  ) u_md_lr_top (
    // Clocks and resets
    .clk (clk),   // (I) Clock
    .rst (reset), // (I) Reset

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
    .faddr  (),       // (O) Force address
    .flast  (flast),  // (O) Last particle data indicator
    .fdata  (fdata)   // (O) Force read data
  );

  // --------------------------------------------------------------------------
  // CSRs
  //
  // Readback Values
  /*assign csrs.afu_id = `AFU_ACCEL_UUID;
  assign csrs.cpu_rd_csrs[0].data  = 64'(pready);
  assign csrs.cpu_rd_csrs[1].data  = 64'(        pwdata[  0+:16]);
  assign csrs.cpu_rd_csrs[2].data  = 64'(        pwdata[ 16+:16]);
  assign csrs.cpu_rd_csrs[3].data  = 64'(        pwdata[ 32+:16]);
  assign csrs.cpu_rd_csrs[4].data  = 64'({ 5'd0, pwdata[ 48+:11]});
  assign csrs.cpu_rd_csrs[5].data  = 64'({12'd0, pwdata[ 59+: 4]});
  assign csrs.cpu_rd_csrs[6].data  = 64'(        pwdata[ 63+:16]);
  assign csrs.cpu_rd_csrs[7].data  = 64'({ 5'd0, pwdata[ 79+:11]});
  assign csrs.cpu_rd_csrs[8].data  = 64'({12'd0, pwdata[ 90+: 4]});
  assign csrs.cpu_rd_csrs[9].data  = 64'(        pwdata[ 94+:16]);
  assign csrs.cpu_rd_csrs[10].data = 64'({5'd0,  pwdata[110+:11]});
  assign csrs.cpu_rd_csrs[11].data = 64'({12'd0, pwdata[121+: 4]});
  assign csrs.cpu_rd_csrs[12].data = 64'(plast);
  assign csrs.cpu_rd_csrs[13].data = 64'(0);
  assign csrs.cpu_rd_csrs[14].data = 64'(0);
  assign csrs.cpu_rd_csrs[15].data = 64'(pvalid);*/

  assign csrs.afu_id = `AFU_ACCEL_UUID;
  assign csrs.cpu_rd_csrs[0].data  = 64'(pready);
  assign csrs.cpu_rd_csrs[1].data  = 64'(        pwdata[                                                                       0+:      CSRW]);
  assign csrs.cpu_rd_csrs[2].data  = 64'(        pwdata[                                                                (0+CSRW)+:      CSRW]);
  assign csrs.cpu_rd_csrs[3].data  = 64'(        pwdata[                                                           (0+CSRW+CSRW)+:      CSRW]);
  assign csrs.cpu_rd_csrs[4].data  = 64'({ 5'd0, pwdata[                                                      (0+CSRW+CSRW+CSRW)+:  OIWMCSR]});
  assign csrs.cpu_rd_csrs[5].data  = 64'({11'd0, pwdata[                                              (0+CSRW+CSRW+CSRW+OIWMCSR)+:GADDRW1DX]});
  assign csrs.cpu_rd_csrs[6].data  = 64'(        pwdata[                                    (0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX)+:      CSRW]);
  assign csrs.cpu_rd_csrs[7].data  = 64'({ 5'd0, pwdata[                               (0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW)+:  OIWMCSR]});
  assign csrs.cpu_rd_csrs[8].data  = 64'({11'd0, pwdata[                       (0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR)+:GADDRW1DY]});
  assign csrs.cpu_rd_csrs[9].data  = 64'(        pwdata[             (0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY)+:      CSRW]);
  assign csrs.cpu_rd_csrs[10].data = 64'({5'd0,  pwdata[        (0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY+CSRW)+:  OIWMCSR]});
  assign csrs.cpu_rd_csrs[11].data = 64'({11'd0, pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY+CSRW+OIWMCSR)+:GADDRW1DZ]});
  assign csrs.cpu_rd_csrs[12].data = 64'(plast);
  assign csrs.cpu_rd_csrs[13].data = 64'(0);
  assign csrs.cpu_rd_csrs[14].data = 64'(0);
  assign csrs.cpu_rd_csrs[15].data = 64'(pvalid);

  assign csrs.cpu_rd_csrs[16].data = 64'(fvalid);
  assign csrs.cpu_rd_csrs[17].data = 64'(fdata[0+:16]);
  assign csrs.cpu_rd_csrs[18].data = 64'(fdata[16+:16]);
  assign csrs.cpu_rd_csrs[19].data = 64'(fdata[32+:16]);
  assign csrs.cpu_rd_csrs[20].data = 64'(fdata[48+:16]);
  assign csrs.cpu_rd_csrs[21].data = 64'(fdata[64+:16]);
  assign csrs.cpu_rd_csrs[22].data = 64'(fdata[80+:16]);
  assign csrs.cpu_rd_csrs[23].data = 64'(flast);
  assign csrs.cpu_rd_csrs[24].data = 64'(0);
  assign csrs.cpu_rd_csrs[25].data = 64'(0);
  assign csrs.cpu_rd_csrs[26].data = 64'(0);
  assign csrs.cpu_rd_csrs[27].data = 64'(0);
  assign csrs.cpu_rd_csrs[28].data = 64'(0);
  assign csrs.cpu_rd_csrs[29].data = 64'(0);
  assign csrs.cpu_rd_csrs[30].data = 64'(0);
  assign csrs.cpu_rd_csrs[31].data = 64'(fready);

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      paddr  <= {PADDRW{1'd0}};
      pwdata <= {PDATAW{1'd0}};
      plast  <= 1'd0;
    end else begin
      // Increment address on transfer of valid particle information
      if (pvalid && pready) begin
        paddr <= paddr + {{(PADDRW-1){1'd0}}, 1'd1};
      end

      // Update pwdata segments and plast when their registers are to be
      // written
      /*
      if (csrs.cpu_wr_csrs[1].en) begin
        pwdata[0+:16] <= csrs.cpu_wr_csrs[1].data[0+:16];
      end
      if (csrs.cpu_wr_csrs[2].en) begin
        pwdata[16+:16] <= csrs.cpu_wr_csrs[2].data[0+:16];
      end
      if (csrs.cpu_wr_csrs[3].en) begin
        pwdata[32+:16] <= csrs.cpu_wr_csrs[3].data[0+:16];
      end
      if (csrs.cpu_wr_csrs[4].en) begin
         pwdata[48+:11] <= csrs.cpu_wr_csrs[4].data[0+:11];
     end
      if (csrs.cpu_wr_csrs[5].en) begin
        pwdata[59+:4] <= csrs.cpu_wr_csrs[5].data[0+:4];
      end
      if (csrs.cpu_wr_csrs[6].en) begin
        pwdata[63+:16] <= csrs.cpu_wr_csrs[6].data[0+:16];
      end
      if (csrs.cpu_wr_csrs[7].en) begin
        pwdata[79+:11] <= csrs.cpu_wr_csrs[7].data[0+:11];
      end
      if (csrs.cpu_wr_csrs[8].en) begin
        pwdata[90+:4] <= csrs.cpu_wr_csrs[8].data[0+:4];
      end
      if (csrs.cpu_wr_csrs[9].en) begin
        pwdata[94+:16] <= csrs.cpu_wr_csrs[9].data[0+:16];
      end
      if (csrs.cpu_wr_csrs[10].en) begin
        pwdata[110+:11] <= csrs.cpu_wr_csrs[10].data[0+:11];
      end
      if (csrs.cpu_wr_csrs[11].en) begin
        pwdata[121+:4] <= csrs.cpu_wr_csrs[11].data[0+:4];
      end
      if (csrs.cpu_wr_csrs[12].en) begin
        plast <= csrs.cpu_wr_csrs[12].data[0];
      end
      */

      if (csrs.cpu_wr_csrs[1].en) begin
        pwdata[0                                                                       +:     CSRW] <= csrs.cpu_wr_csrs[1].data[0+:CSRW];
      end
      if (csrs.cpu_wr_csrs[2].en) begin
        pwdata[(0+CSRW)                                                                +:     CSRW] <= csrs.cpu_wr_csrs[2].data[0+:CSRW];
      end
      if (csrs.cpu_wr_csrs[3].en) begin
        pwdata[(0+CSRW+CSRW)                                                           +:     CSRW] <= csrs.cpu_wr_csrs[3].data[0+:CSRW];
      end
      if (csrs.cpu_wr_csrs[4].en) begin
        pwdata[(0+CSRW+CSRW+CSRW)                                                      +:  OIWMCSR] <= csrs.cpu_wr_csrs[4].data[0+:OIWMCSR];
     end
      if (csrs.cpu_wr_csrs[5].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR)                                              +:GADDRW1DX] <= csrs.cpu_wr_csrs[5].data[0+:GADDRW1DX];
      end
      if (csrs.cpu_wr_csrs[6].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX)                                    +:     CSRW] <= csrs.cpu_wr_csrs[6].data[0+:CSRW];
      end
      if (csrs.cpu_wr_csrs[7].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW)                               +:  OIWMCSR] <= csrs.cpu_wr_csrs[7].data[0+:OIWMCSR];
      end
      if (csrs.cpu_wr_csrs[8].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR)                       +:GADDRW1DY] <= csrs.cpu_wr_csrs[8].data[0+:GADDRW1DY];
      end
      if (csrs.cpu_wr_csrs[9].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY)             +:     CSRW] <= csrs.cpu_wr_csrs[9].data[0+:CSRW];
      end
      if (csrs.cpu_wr_csrs[10].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY+CSRW)        +:  OIWMCSR] <= csrs.cpu_wr_csrs[10].data[0+:OIWMCSR];
      end
      if (csrs.cpu_wr_csrs[11].en) begin
        pwdata[(0+CSRW+CSRW+CSRW+OIWMCSR+GADDRW1DX+CSRW+OIWMCSR+GADDRW1DY+CSRW+OIWMCSR)+:GADDRW1DZ] <= csrs.cpu_wr_csrs[11].data[0+:GADDRW1DZ];
      end
      if (csrs.cpu_wr_csrs[12].en) begin
        plast <= csrs.cpu_wr_csrs[12].data[0];
      end
    end
  end

  assign pvalid = csrs.cpu_wr_csrs[15].en ? csrs.cpu_wr_csrs[15].data[0] : 1'b0;
  assign pwe    = csrs.cpu_wr_csrs[15].en ? csrs.cpu_wr_csrs[15].data[0] : 1'b0;
  assign fready = csrs.cpu_wr_csrs[31].en;

  // --------------------------------------------------------------------------
  // FIU
  //
  // This AFU never makes write requests
  assign fiu.c1Tx.valid = 1'd0;
  assign fiu.c1Tx.hdr   = t_cci_mpf_c1_ReqMemHdr'(0);
  assign fiu.c1Tx.data  = t_ccip_clData'(0);

  // This AFU never makes a read request or handles MMIO reads.
  assign fiu.c0Tx.valid = 1'b0;
  assign fiu.c2Tx.mmioRdValid = 1'b0;

endmodule
