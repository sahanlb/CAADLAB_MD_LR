module customdelay (
  // --------------------------------------------------------------------------
  // Port Argument List
  //
  clk,   // (I) Clock
  rst,   // (I) Reset
  x,     // (I) Input to be delayed
  stall, // (I) Pipeline Stall
  y      // (I) Output
);

  // --------------------------------------------------------------------------
  // Configurable Parameters
  //
  parameter  WIDTH = 32'd32;
  parameter  DELAY = 32'd3;

  localparam DELMSBIT = (DELAY == 32'd0) ? 32'd0 : DELAY-32'd1;

  // --------------------------------------------------------------------------
  // IO Declarations
  //
  input  logic             clk;
  input  logic             rst;
  input  logic [WIDTH-1:0] x;
  input                    stall;
  output wire  [WIDTH-1:0] y;

  // --------------------------------------------------------------------------
  // Internal Variables
  //
  genvar gii;

  // --------------------------------------------------------------------------
  // Internal Signals
  //
  logic [DELAY-1:0][WIDTH-1:0] x_delayed;
 
  // --------------------------------------------------------------------------
  // Delay Logic
  //
  // Initial Delay (delay of 1)
  generate
    if (DELAY == 32'd0) begin : no_delay
      always @* begin : comb
        x_delayed[DELMSBIT] = x;
      end
    end else begin : delay
      always_ff @(posedge clk) begin : del0
        if (rst) begin
          x_delayed[0] <= {WIDTH{1'd0}};
        end else begin
          if (stall) begin
            x_delayed[0] <= x_delayed[0];
          end else begin
            x_delayed[0] <= x;
          end
        end
      end

      // Subsequent delays
      for (gii=1; gii<DELAY; gii=gii+1) begin : deln
        always_ff @(posedge clk) begin : seq
          if (rst) begin
            x_delayed[gii] <= {WIDTH{1'd0}};
          end else begin
            if (stall) begin
              x_delayed[gii] <= x_delayed[gii];
            end else begin
              x_delayed[gii] <= x_delayed[gii-1];
            end
          end
        end
      end
    end
  endgenerate

  assign y = x_delayed[DELMSBIT];
endmodule
