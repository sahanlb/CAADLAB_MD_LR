// fftIP.v

// Generated using ACDS version 18.1.2 277

`timescale 1 ps / 1 ps
module fftIP (
		input  wire        clk,          //    clk.clk
		input  wire        reset_n,      //    rst.reset_n
		input  wire        sink_valid,   //   sink.sink_valid
		output wire        sink_ready,   //       .sink_ready
		input  wire [1:0]  sink_error,   //       .sink_error
		input  wire        sink_sop,     //       .sink_sop
		input  wire        sink_eop,     //       .sink_eop
		input  wire [31:0] sink_real,    //       .sink_real
		input  wire [31:0] sink_imag,    //       .sink_imag
		input  wire [4:0]  fftpts_in,    //       .fftpts_in
		output wire        source_valid, // source.source_valid
		input  wire        source_ready, //       .source_ready
		output wire [1:0]  source_error, //       .source_error
		output wire        source_sop,   //       .source_sop
		output wire        source_eop,   //       .source_eop
		output wire [31:0] source_real,  //       .source_real
		output wire [31:0] source_imag,  //       .source_imag
		output wire [4:0]  fftpts_out    //       .fftpts_out
	);

	fftIP_altera_fft_ii_181_iruogdq fft_ii_0 (
		.clk          (clk),          //   input,   width = 1,    clk.clk
		.reset_n      (reset_n),      //   input,   width = 1,    rst.reset_n
		.sink_valid   (sink_valid),   //   input,   width = 1,   sink.sink_valid
		.sink_ready   (sink_ready),   //  output,   width = 1,       .sink_ready
		.sink_error   (sink_error),   //   input,   width = 2,       .sink_error
		.sink_sop     (sink_sop),     //   input,   width = 1,       .sink_sop
		.sink_eop     (sink_eop),     //   input,   width = 1,       .sink_eop
		.sink_real    (sink_real),    //   input,  width = 32,       .sink_real
		.sink_imag    (sink_imag),    //   input,  width = 32,       .sink_imag
		.fftpts_in    (fftpts_in),    //   input,   width = 5,       .fftpts_in
		.source_valid (source_valid), //  output,   width = 1, source.source_valid
		.source_ready (source_ready), //   input,   width = 1,       .source_ready
		.source_error (source_error), //  output,   width = 2,       .source_error
		.source_sop   (source_sop),   //  output,   width = 1,       .source_sop
		.source_eop   (source_eop),   //  output,   width = 1,       .source_eop
		.source_real  (source_real),  //  output,  width = 32,       .source_real
		.source_imag  (source_imag),  //  output,  width = 32,       .source_imag
		.fftpts_out   (fftpts_out)    //  output,   width = 5,       .fftpts_out
	);

endmodule
