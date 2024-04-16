// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// Template for Variable-streaming unidirectional test-benches

`timescale 1 ps / 1 ps
module fftIP_altera_fft_ii_181_reujcoy_tb #(
            parameter B_IN  = 18,
            parameter B_OUT = 18,
            parameter FFT_REP_WIDTH = 10,
            parameter EXP_W = 6
	) ();

        // confusing names here - but consistent with the top-level testbench
        localparam SRC_SYMBOL_W = (2*B_IN)  + FFT_REP_WIDTH;
        localparam SNK_SYMBOL_W = (2*B_OUT) + FFT_REP_WIDTH;

	wire                      altera_fft_ii_inst_core_source_valid;   
	wire   [SNK_SYMBOL_W-1:0] altera_fft_ii_inst_core_source_data;     
	wire                      altera_fft_ii_inst_core_source_ready;           
	wire                      altera_fft_ii_inst_core_source_startofpacket;  
	wire                [1:0] altera_fft_ii_inst_core_source_error;          
	wire                      altera_fft_ii_inst_core_source_endofpacket;      
	wire                [0:0] altera_fft_ii_inst_core_sink_valid;      
	wire   [SRC_SYMBOL_W-1:0] altera_fft_ii_inst_core_sink_data;      
	wire                      altera_fft_ii_inst_core_sink_ready;      
	wire                [0:0] altera_fft_ii_inst_core_sink_startofpacket;
	wire                [0:0] altera_fft_ii_inst_core_sink_endofpacket;  
	wire                [1:0] altera_fft_ii_inst_core_sink_error;        
	wire                      altera_fft_ii_inst_core_clk;          
	wire                      altera_fft_ii_inst_core_reset_n;       

	// Pack/unpack data streams between BFMs and core (inverse of pack/unpack in the transaction classes)

	logic          [B_IN-1:0] altera_fft_ii_inst_core_sink_real;       
	logic          [B_IN-1:0] altera_fft_ii_inst_core_sink_imag;       
	logic [FFT_REP_WIDTH-1:0] altera_fft_ii_inst_core_fftpts_in;       

	logic         [B_OUT-1:0] altera_fft_ii_inst_core_source_real;       
	logic         [B_OUT-1:0] altera_fft_ii_inst_core_source_imag;       
	logic [FFT_REP_WIDTH-1:0] altera_fft_ii_inst_core_fftpts_out;       

	assign
            altera_fft_ii_inst_core_sink_real =   
                altera_fft_ii_inst_core_sink_data[(2*B_IN) + FFT_REP_WIDTH - 1 : B_IN + FFT_REP_WIDTH], 
            altera_fft_ii_inst_core_sink_imag =     
                altera_fft_ii_inst_core_sink_data[B_IN + FFT_REP_WIDTH - 1 : FFT_REP_WIDTH],
            altera_fft_ii_inst_core_fftpts_in = 
                altera_fft_ii_inst_core_sink_data[FFT_REP_WIDTH - 1 : 0]; 

	fftIP_altera_fft_ii_181_reujcoy altera_fft_ii_inst (
		.clk          (altera_fft_ii_inst_core_clk),       
		.reset_n      (altera_fft_ii_inst_core_reset_n),   
		.sink_valid   (altera_fft_ii_inst_core_sink_valid), 
		.sink_ready   (altera_fft_ii_inst_core_sink_ready),  
		.sink_error   (altera_fft_ii_inst_core_sink_error), 
		.sink_sop     (altera_fft_ii_inst_core_sink_startofpacket), 
		.sink_eop     (altera_fft_ii_inst_core_sink_endofpacket),  
		.sink_real    (altera_fft_ii_inst_core_sink_real),   
		.sink_imag    (altera_fft_ii_inst_core_sink_imag),  
		.fftpts_in    (altera_fft_ii_inst_core_fftpts_in),
		.source_valid (altera_fft_ii_inst_core_source_valid),
		.source_ready (altera_fft_ii_inst_core_source_ready),
		.source_error (altera_fft_ii_inst_core_source_error),
		.source_sop   (altera_fft_ii_inst_core_source_startofpacket), 
		.source_eop   (altera_fft_ii_inst_core_source_endofpacket),  
		.source_real  (altera_fft_ii_inst_core_source_real), 
		.source_imag  (altera_fft_ii_inst_core_source_imag), 
		.fftpts_out   (altera_fft_ii_inst_core_fftpts_out)   
        );

	assign
            altera_fft_ii_inst_core_source_data[(2*B_OUT) + FFT_REP_WIDTH - 1 : B_OUT + FFT_REP_WIDTH] =
                altera_fft_ii_inst_core_source_real,
            altera_fft_ii_inst_core_source_data[B_OUT + FFT_REP_WIDTH - 1 : FFT_REP_WIDTH] =
                altera_fft_ii_inst_core_source_imag,
            altera_fft_ii_inst_core_source_data[FFT_REP_WIDTH - 1 : 0] =
                altera_fft_ii_inst_core_fftpts_out;

	altera_avalon_clock_source #(
		.CLOCK_RATE (50000000),
		.CLOCK_UNIT (1)
	) altera_fft_ii_inst_core_clk_bfm (
		.clk (altera_fft_ii_inst_core_clk) 
	);

	altera_avalon_reset_source #(
		.ASSERT_HIGH_RESET    (0),
		.INITIAL_RESET_CYCLES (50)
	) altera_fft_ii_inst_core_rst_bfm (
		.reset (altera_fft_ii_inst_core_reset_n),
		.clk   (altera_fft_ii_inst_core_clk)     
	);

	altera_avalon_st_source_bfm #(
		.USE_PACKET       (1),
		.USE_CHANNEL      (0),
		.USE_ERROR        (1),
		.USE_READY        (1),
		.USE_VALID        (1),
		.USE_EMPTY        (0),
		.ST_SYMBOL_W      (SRC_SYMBOL_W),
		.ST_NUMSYMBOLS    (1),
		.ST_CHANNEL_W     (1),
		.ST_ERROR_W       (2),
		.ST_EMPTY_W       (1),
		.ST_READY_LATENCY (0),
		.ST_BEATSPERCYCLE (1),
		.ST_MAX_CHANNELS  (0),
		.VHDL_ID          (0)
	) altera_fft_ii_inst_core_sink_bfm (
		.clk               (altera_fft_ii_inst_core_clk),      
		.reset             (~altera_fft_ii_inst_core_reset_n),    
		.src_data          (altera_fft_ii_inst_core_sink_data), 
		.src_valid         (altera_fft_ii_inst_core_sink_valid),    
		.src_ready         (altera_fft_ii_inst_core_sink_ready), 
		.src_startofpacket (altera_fft_ii_inst_core_sink_startofpacket),
		.src_endofpacket   (altera_fft_ii_inst_core_sink_endofpacket),  
		.src_error         (altera_fft_ii_inst_core_sink_error),  
		.src_empty         (),   
		.src_channel       ()    
	);

	altera_avalon_st_sink_bfm #(
		.USE_PACKET       (1),
		.USE_CHANNEL      (0),
		.USE_ERROR        (1),
		.USE_READY        (1),
		.USE_VALID        (1),
		.USE_EMPTY        (0),
		.ST_SYMBOL_W      (SNK_SYMBOL_W),
		.ST_NUMSYMBOLS    (1),
		.ST_CHANNEL_W     (1),
		.ST_ERROR_W       (2),
		.ST_EMPTY_W       (1),
		.ST_READY_LATENCY (0),
		.ST_BEATSPERCYCLE (1),
		.ST_MAX_CHANNELS  (0),
		.VHDL_ID          (0)
	) altera_fft_ii_inst_core_source_bfm (
		.clk                (altera_fft_ii_inst_core_clk),     
		.reset              (~altera_fft_ii_inst_core_reset_n), 
		.sink_data          (altera_fft_ii_inst_core_source_data),          
		.sink_valid         (altera_fft_ii_inst_core_source_valid),       
		.sink_ready         (altera_fft_ii_inst_core_source_ready),    
		.sink_startofpacket (altera_fft_ii_inst_core_source_startofpacket), 
		.sink_endofpacket   (altera_fft_ii_inst_core_source_endofpacket),  
		.sink_error         (altera_fft_ii_inst_core_source_error),       
		.sink_empty         (1'b0),     
		.sink_channel       (1'b0)  
	);

endmodule

