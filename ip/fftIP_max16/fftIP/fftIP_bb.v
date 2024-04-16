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
endmodule

