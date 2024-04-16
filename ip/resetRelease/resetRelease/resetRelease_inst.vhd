	component resetRelease is
		port (
			user_reset   : out std_logic;  -- user_reset
			user_clkgate : out std_logic   -- user_clkgate
		);
	end component resetRelease;

	u0 : component resetRelease
		port map (
			user_reset   => CONNECTED_TO_user_reset,   --   user_reset.user_reset
			user_clkgate => CONNECTED_TO_user_clkgate  -- user_clkgate.user_clkgate
		);

