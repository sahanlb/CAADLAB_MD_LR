// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : cfg_sp_rw_mem.sv
// Description    : Configurable Single Port Read/Write Memory
// 
// ============================================================================

module cfg_sp_rw_mem (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  clk,   // (I) Clock
  me,    // (I) Memory enable
  addr,  // (I) Memory array address
  segwe, // (I) Active high memory array entry segment write enable
  wdata, // (I) Memory array entry write data
  rdata  // (O) Memory array entry read data
);

  // --------------------------------------------------------------------------
  // Parameters
  //
  // Number of blocks
  parameter BLKS = 32'd2;

  // Number of array entries in a block
  parameter BDEPTH = 32'd32;

  // Number of segments in an array entry
  parameter SEGS = 32'd1;
  
  // Bit-width of an array entry segment
  parameter SEGW = 32'd32;

  // Number of bits in address for entire memory space
  localparam ADDR_BITS  = $clog2(BDEPTH*BLKS);

  // MSB of address for entire memory space
  localparam ADDR_MSB = (ADDR_BITS == 32'd0) ? ADDR_BITS : ADDR_BITS - 32'd1;
  
  // Number of address bits required to select a block
  localparam BLK_SEL_BITS = $clog2(BLKS);
  
  // Number of bits in a block's address
  localparam BADDR_BITS = $clog2(BDEPTH);
 
  // MSB of address for each block
  localparam BADDR_MSB = (BADDR_BITS == 32'd0) ? BADDR_BITS: BADDR_BITS- 32'd1;
  
  // Read delay timing
  parameter [1:0] RDTYPE = 2'd1;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input                       clk;
  input                       me;
  input          [ADDR_MSB:0] addr;
  input            [SEGS-1:0] segwe;
  
  // Multi-dimensional declarations don't seem to map well to FPGA block RAMs
  input       [SEGS*SEGW-1:0] wdata;
  output wire [SEGS*SEGW-1:0] rdata;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar ii;
  genvar jj;
  
  // --------------------------------------------------------------------------
  // Internal Signals
  //
  wire [BLKS-1:0]                blke;      // Block enables
  wire [BLKS-1:0][SEGS*SEGW-1:0] blk_rdata; // Per block read data

  // --------------------------------------------------------------------------
  // Block enable generation
  //
  generate
    if (BLKS > 1) begin : mbe
      // Multiple blocks
      for (ii=0; ii<BLKS; ii=ii+1) begin : block
        assign blke[ii] = me & (addr[ADDR_MSB-:BLK_SEL_BITS] == ii[BLK_SEL_BITS-1:0]);
      end
    end else begin : obe
      // One block
      assign blke[0] = me;
    end
  endgenerate 

  // --------------------------------------------------------------------------
  // Memory Block Behavior
  //
  for (ii=0; ii<BLKS; ii=ii+1) begin : block
    // Memory array for a block
    (* ram_style = "block" *) reg [SEGS*SEGW-1:0] mem_array [BDEPTH-1:0];

    /////////////////
    // Write Logic //
    /////////////////
    //
    if (BDEPTH > 1) begin : mew
      // Multiple memory entries
      for(jj=0; jj<SEGS; jj=jj+1) begin : seg
        always @(posedge clk) begin : write
          if (blke[ii]) begin
            // Block selected
            if (segwe[jj]) begin
              // Segment write enable asserted
              mem_array[addr[BADDR_MSB:0]][jj*SEGW+:SEGW] <= wdata[jj*SEGW+:SEGW];
            end
          end
        end
      end
    end else begin : oew
      // One memory entry
      for(jj=0; jj<SEGS; jj=jj+1) begin : seg
        always @(posedge clk) begin : write
          if (blke[ii]) begin
            // Block selected
            if (segwe[jj]) begin
              // Segment write enable asserted
              mem_array[0][jj*SEGW+:SEGW] <= wdata[jj*SEGW+:SEGW];
            end
          end
        end
      end
    end

    ////////////////
    // Read Logic //
    ////////////////
    //
    case (RDTYPE)
      2'd0 : begin : async_read
        // Read data flows through
        if (BDEPTH > 32'd1) begin : mer
          // Multiple memory array entries
          assign blk_rdata[ii] = mem_array[addr[BADDR_MSB:0]];
        end else begin : oer
          // One memory array entry
          assign blk_rdata[ii] = mem_array[0];

          wire unused_oer_ok = |{addr[BADDR_MSB:0], 1'd1};
        end
      end
      
      2'd1 : begin : sync_ctrl_read
        // 1) Control signals are registered
        // 2) Memory array outputs are MUXed to generate read data
        // 3) MUX select lines are driven by registered control signals

        if (BDEPTH > 32'd1) begin : mer          
          // Multiple memory array entries
          reg [BADDR_MSB:0] addr_d1; // Pipelined address
          
          // Register Address
          always @(posedge clk) begin : addr_seq
            if (blke[ii]) begin
              // Block selected
              addr_d1 <= addr[BADDR_MSB:0];
            end
          end
  
          // MUXing w/i memory block
          assign blk_rdata[ii] = mem_array[addr_d1];        
        end else begin : obr
          // One memory array entry
          reg [SEGS*SEGW-1:0] entry_rdata;

          // Register Read Data since there is no point in registering address
          always @(posedge clk) begin : rdata_seq
            if (blke[ii]) begin
              // Block selected
              entry_rdata <= mem_array[0];
            end
          end
  
          assign blk_rdata[ii] = entry_rdata;

          wire unused_oer_ok = |{addr[BADDR_MSB:0], 1'd1};
        end
      end
      

      2'd2 : begin : sync_data_read
        // 1) Read data itself is registered
        // 2) Memory array outputs are MUXed and feed output register
        // 3) MUX select lines are driven by control signal inputs
        reg [SEGS*SEGW-1:0] entry_rdata;

        if (BDEPTH > 32'd1) begin : mer
          // Multiple memory array entries

          // Register a block's read data
          always @(posedge clk) begin : blk_rdata_seq
            if (blke[ii]) begin
              // Block selected
              entry_rdata <= mem_array[addr[BADDR_MSB:0]];
            end
          end
        end else begin : oer
          // One memory array entry

          // Register a block's read data
          always @(posedge clk) begin : blk_rdata_seq
            if (blke[ii]) begin
              // Block selected
              entry_rdata <= mem_array[0];
            end
          end

          wire unused_oer_ok = |{addr[BADDR_MSB:0], 1'd1};
        end

        assign blk_rdata[ii] = entry_rdata;
      end
          
      2'd3 : begin : sync_ctrl_data_read
        // 1) Control signals are registered
        // 2) Read data itself is registered
        // 3) Memory array outputs are MUXed and feed output register
        // 4) MUX select lines are driven by registered control signals
        reg [SEGS*SEGW-1:0] entry_rdata;
        
        reg blke_d1; // Pipelined block enable
  
        // Register memory enable
        always @(posedge clk) begin : blke_seq
          blke_d1 <= blke[ii];
        end

        if (BDEPTH > 32'd1) begin : mer
          // Multiple memory array entries
          reg [BADDR_MSB:0] addr_d1; // Pipelined address

          // Register Address
          always @(posedge clk) begin : ctrl_seq
            if (blke[ii]) begin
              // Block selected
              addr_d1 <= addr[BADDR_MSB:0];
            end
          end
              
          // Register a block's read data
          always @(posedge clk) begin : blk_rdata_seq
            if (blke_d1) begin
              // Block selected
              entry_rdata <= mem_array[addr_d1];
            end
          end
        end else begin : oer
          // One memory array entry

          // Register Read Data since there is no point in registering address
          always @(posedge clk) begin : rdata_seq
            if (blke_d1) begin
              // Block selected
              entry_rdata <= mem_array[0];
            end
          end

          wire unused_oer_ok = |{addr[BADDR_MSB:0], 1'd1};
        end

        assign blk_rdata[ii] = entry_rdata;
      end
    endcase
  end

  // --------------------------------------------------------------------------
  // Block Readback Muxing
  //
  generate
    if (BLKS > 1) begin : mbr
      // Multiple blocks
      case (RDTYPE)
        2'd0 : begin : async_read
          assign rdata = blk_rdata[addr[ADDR_MSB-:BLK_SEL_BITS]];
        end
        2'd1 : begin : sync_ctrl_read
          reg [BLK_SEL_BITS-1:0] addr_bits_d1; // Pipelined address
          
          
          // Register Upper Address Bits
          always @(posedge clk) begin : addr_bits_seq
            addr_bits_d1 <= addr[ADDR_MSB-:BLK_SEL_BITS];
          end

          assign rdata = blk_rdata[addr_bits_d1];
        end
        2'd2 : begin : sync_data_read
          reg [BLK_SEL_BITS-1:0] addr_bits_d1; // Pipelined address
          
          
          // Register Upper Address Bits
          always @(posedge clk) begin : addr_bits_seq
            addr_bits_d1 <= addr[ADDR_MSB-:BLK_SEL_BITS];
          end

          assign rdata = blk_rdata[addr_bits_d1];
        end
        2'd3 : begin : sync_ctrl_data_read
          reg [BLK_SEL_BITS-1:0] addr_bits_d1; // Pipelined address
          reg [BLK_SEL_BITS-1:0] addr_bits_d2; // Pipelined address
                    
          // Register Upper Address Bits
          always @(posedge clk) begin : addr_bits_seq
            addr_bits_d1 <= addr[ADDR_MSB-:BLK_SEL_BITS];
            addr_bits_d2 <= addr_bits_d1;
          end

          assign rdata = blk_rdata[addr_bits_d2];
        end // block: sync_ctrl_data_read
      endcase
    end else begin : obr
      // Single blocks
      assign rdata = blk_rdata[0];
    end
  endgenerate
endmodule
