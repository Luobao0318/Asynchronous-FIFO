// Read Pointer Handler
module rptr_handler #(
	parameter PTR_WIDTH = 5,
  	parameter AE_LEVEL = 2)(
	input rrst_n,
  	input rclk,
  	input rd_en,
  	input [PTR_WIDTH-1:0] g_wptr_sync,
  	output reg [PTR_WIDTH-1:0] b_rptr, g_rptr,
  	output reg empty,
  	output reg almost_empty
);

  wire rempty;
  wire almost_empty_next;
  wire [PTR_WIDTH-1:0] b_wptr_sync;
  wire [PTR_WIDTH-1:0] count;

  wire [PTR_WIDTH-1:0] b_rptr_next;
  wire [PTR_WIDTH-1:0] g_rptr_next;

  // Gray-to-Binary conversion
  function [PTR_WIDTH-1:0] gray2bin;
    input [PTR_WIDTH-1:0] gray;
    integer i;
    begin
      gray2bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];
      for(i = PTR_WIDTH - 2; i >= 0; i = i - 1)
        gray2bin[i] = gray2bin[i + 1] ^ gray[i];
    end
  endfunction

  assign b_rptr_next = b_rptr + (rd_en & !empty);
  assign g_rptr_next = (b_rptr_next >> 1) ^ b_rptr_next;
  assign rempty = (g_wptr_sync == g_rptr_next);

  always @(posedge rclk or negedge rrst_n) begin
    if(!rrst_n) begin
      b_rptr <= 0;
      g_rptr <= 0;
    end
    else begin
      b_rptr <= b_rptr_next;
      g_rptr <= g_rptr_next;
    end
  end

  always @(posedge rclk or negedge rrst_n) begin
    if(!rrst_n) begin
      empty <= 1;
      almost_empty <= 1;
    end
    else begin
      empty <= rempty;
      almost_empty <= almost_empty_next;
    end
  end

  assign b_wptr_sync = gray2bin(g_wptr_sync);
  assign count = b_wptr_sync - b_rptr_next;
  assign almost_empty_next = (count <= AE_LEVEL);

endmodule