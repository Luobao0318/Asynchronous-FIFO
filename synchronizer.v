// 2 flip-flop synchronizer
// SYNC_WIDTH: log16+1=5
module synchronizer #(parameter WIDTH = 5)(
	input rst_n,
	input clk,
  	input [WIDTH-1:0] d_in,
  	output reg [WIDTH-1:0] d_out
);

  reg [WIDTH-1:0] q1;

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      q1 <= 0;
      d_out <= 0;
    end
    else begin
      q1 <= d_in;
      d_out <= q1;
    end
  end

endmodule