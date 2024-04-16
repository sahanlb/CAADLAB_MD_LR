// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : fft_idx_translator.sv
// Description    : Translates FFT sample index presented in time to its sample
//                  index in its true sequential context
// 
// ============================================================================

module fft_idx_translator (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  idxin, // (I) Input index
  idxout // (O) Output index
);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  // Number of FFT points
  parameter NPTS = 32'd32;

  // Translation Type:
  // 32'd0   : No Translation
  // 32'd1   : Natural to Mixed Radix-4/2 Algorithm (see comments below)
  // default : No translation
  // Using 32-bit parameter to account for future, TBD translation types.
  parameter TTYPE = 32'd0;
  
  // --------------------------------------------------------------------------
  // Top-Level Derived Parameters
  //
  // Index width
  localparam IDXW = $clog2(NPTS);

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input  [IDXW-1:0] idxin;
  output [IDXW-1:0] idxout;

  generate
    case (TTYPE)
      32'd0 : begin : notrans
        // No translation
        assign idxout = idxin;
      end

      32'd1 : begin : nat_to_mixd42a
        // If NPTS is a power of four, the order is radix-4 digit reversed
        // order, in which two-bit digits in the input index are units in the
        // reverse ordering. For example, if NPTS = 16, input index 4 becomes
        // the second output index in the sample stream (by reversal of the
        // digits in 0001, the location in the sample stream, to 0100).
        //
        // However, in mixed radix-4/2 algorithm, NPTS need not be a power of
        // four. If NPTS is not a power of four, the two-bit digits are
        // grouped from the least significant bit, and the most significant bit
        // becomes the least significant bit in the digit-reversed order. For
        // example, if NPTS = 32, the input index 18 (10010) in the natural
        // ordering becomes output sample 17 (10001) in the digit-reversed
        // order.

        // Indicator of whether or not the index bit width is odd or not.
        localparam IDXW_IS_ODD = IDXW % 32'd2;
        
        // Number of two bit digits in the index
        localparam N2BD = IDXW >> 32'd1;

        genvar ii;
                
        if (IDXW_IS_ODD) begin : non_pow4
          assign idxout[0] = idxin[IDXW-1];

          for(ii=0; ii<N2BD; ii=ii+1) begin : twobitdigit
            assign idxout[(IDXW-2)-(2*ii)+:2] = idxin[(2*ii)+:2];
          end
        end else begin : pow4
          for(ii=0; ii<N2BD; ii=ii+1) begin : twobitdigit
            assign idxout[(IDXW-2)-(2*ii)+:2] = idxin[(2*ii)+:2];
          end
        end
      end
      default : begin : default_no_trans
        // No translation
        assign idxout = idxin;
      end
    endcase
  endgenerate
endmodule
