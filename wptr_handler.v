// Write Pointer Handler
module wptr_handler #(
  	parameter PTR_WIDTH = 5,
	parameter AF_LEVEL = 14)(
	input wrst_n,
  	input wclk,
  	input wr_en,
  	input [PTR_WIDTH-1:0] g_rptr_sync,
  	output reg [PTR_WIDTH-1:0] b_wptr, g_wptr,
  	output reg full,
  	output reg almost_full
);

  wire wfull;
  wire almost_full_next;  // 下一拍将满
  wire [PTR_WIDTH-1:0] b_rptr_sync;
  wire [PTR_WIDTH-1:0] count;

  wire [PTR_WIDTH-1:0] b_wptr_next;
  wire [PTR_WIDTH-1:0] g_wptr_next;

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

  assign b_wptr_next = b_wptr + (wr_en & !full);
  assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;
  assign wfull = (g_wptr_next == {~g_rptr_sync[PTR_WIDTH-1:PTR_WIDTH-2], g_rptr_sync[PTR_WIDTH-3:0]});

  always @(posedge wclk or negedge wrst_n) begin
    if(!wrst_n) begin
      b_wptr <= 0;
      g_wptr <= 0;
    end
    else begin
      b_wptr <= b_wptr_next;  // increase binary write pointer
      g_wptr <= g_wptr_next;  // increase gray write pointer
    end
  end

  always @(posedge wclk or negedge wrst_n) begin
    if(!wrst_n) begin
      full <= 0;
      almost_full <= 0;
    end
    else begin
      full <= wfull;
      almost_full <= almost_full_next;
    end
  end

  assign b_rptr_sync = gray2bin(g_rptr_sync);
  assign count = b_wptr_next - b_rptr_sync;
  assign almost_full_next = (count >= AF_LEVEL);

endmodule