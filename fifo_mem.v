// FIFO Memory
module fifo_mem #(
	parameter DEPTH = 16,
  	parameter DATA_WIDTH = 8,
  	parameter PTR_WIDTH = 5)(
	input wclk, wr_en, rclk, rd_en,
  	input full, empty,
  	input [PTR_WIDTH-1:0] b_wptr, b_rptr,
  	input [DATA_WIDTH-1:0] data_in,
  	output reg [DATA_WIDTH-1:0] data_out
);

  reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];

  always @(posedge wclk) begin
    if(wr_en & !full) begin
      fifo[b_wptr[PTR_WIDTH-2:0]] <= data_in;
    end
  end

  always @(posedge rclk) begin
    if(rd_en & !empty) begin
      data_out <= fifo[b_rptr[PTR_WIDTH-2:0]];
    end
  end

endmodule