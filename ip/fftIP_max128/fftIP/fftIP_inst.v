	fftIP u0 (
		.clk          (_connected_to_clk_),          //   input,   width = 1,    clk.clk
		.reset_n      (_connected_to_reset_n_),      //   input,   width = 1,    rst.reset_n
		.sink_valid   (_connected_to_sink_valid_),   //   input,   width = 1,   sink.sink_valid
		.sink_ready   (_connected_to_sink_ready_),   //  output,   width = 1,       .sink_ready
		.sink_error   (_connected_to_sink_error_),   //   input,   width = 2,       .sink_error
		.sink_sop     (_connected_to_sink_sop_),     //   input,   width = 1,       .sink_sop
		.sink_eop     (_connected_to_sink_eop_),     //   input,   width = 1,       .sink_eop
		.sink_real    (_connected_to_sink_real_),    //   input,  width = 32,       .sink_real
		.sink_imag    (_connected_to_sink_imag_),    //   input,  width = 32,       .sink_imag
		.fftpts_in    (_connected_to_fftpts_in_),    //   input,   width = 8,       .fftpts_in
		.source_valid (_connected_to_source_valid_), //  output,   width = 1, source.source_valid
		.source_ready (_connected_to_source_ready_), //   input,   width = 1,       .source_ready
		.source_error (_connected_to_source_error_), //  output,   width = 2,       .source_error
		.source_sop   (_connected_to_source_sop_),   //  output,   width = 1,       .source_sop
		.source_eop   (_connected_to_source_eop_),   //  output,   width = 1,       .source_eop
		.source_real  (_connected_to_source_real_),  //  output,  width = 32,       .source_real
		.source_imag  (_connected_to_source_imag_),  //  output,  width = 32,       .source_imag
		.fftpts_out   (_connected_to_fftpts_out_)    //  output,   width = 8,       .fftpts_out
	);

