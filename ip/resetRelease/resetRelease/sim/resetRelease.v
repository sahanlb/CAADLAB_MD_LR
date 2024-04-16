// resetRelease.v

// Generated using ACDS version 18.1 222

`timescale 1 ps / 1 ps
module resetRelease (
		output wire  user_reset,   //   user_reset.user_reset
		output wire  user_clkgate  // user_clkgate.user_clkgate
	);

	altera_s10_user_rst_clkgate #(
		.USER_RESET_DELAY   ("0"),
		.USER_CLKGATE_DELAY ("0")
	) s10_user_rst_clkgate_0 (
		.user_reset   (user_reset),   //  output,  width = 1,   user_reset.user_reset
		.user_clkgate (user_clkgate)  //  output,  width = 1, user_clkgate.user_clkgate
	);

endmodule