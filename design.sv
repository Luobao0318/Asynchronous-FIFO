// 16 × 8 bit Asynchronous FIFO
`include "synchronizer.v"
`include "wptr_handler.v"
`include "rptr_handler.v"
`include "fifo_mem.v"

module asynchronous_fifo #(
	parameter DEPTH = 16,
  	parameter DATA_WIDTH = 8,
	parameter AF_LEVEL = 14,
	parameter AE_LEVEL = 2)(
	input wrst_n, wclk, wr_en,
  	input rrst_n, rclk, rd_en,
  	input [DATA_WIDTH-1:0] data_in,
  	output [DATA_WIDTH-1:0] data_out,
  	output full, empty,
  	output almost_full, almost_empty
);

  localparam PTR_WIDTH = $clog2(DEPTH) + 1;

  wire [PTR_WIDTH-1:0] g_wptr_sync, g_rptr_sync;
  wire [PTR_WIDTH-1:0] g_wptr, g_rptr;
  wire [PTR_WIDTH-1:0] b_wptr, b_rptr;

  synchronizer #(PTR_WIDTH) sync_wptr (
    .clk(rclk),
    .rst_n(rrst_n),
    .d_in(g_wptr),
    .d_out(g_wptr_sync)
  );

  synchronizer #(PTR_WIDTH) sync_rptr (
    .clk(wclk),
    .rst_n(wrst_n),
    .d_in(g_rptr),
    .d_out(g_rptr_sync)
  );

  wptr_handler #(PTR_WIDTH, AF_LEVEL) wptr_inst (
    .wclk(wclk),
    .wrst_n(wrst_n),
    .wr_en(wr_en),
    .g_rptr_sync(g_rptr_sync),
    .b_wptr(b_wptr),
    .g_wptr(g_wptr),
    .full(full),
    .almost_full(almost_full)
  );

  rptr_handler #(PTR_WIDTH, AE_LEVEL) rptr_inst (
    .rclk(rclk),
    .rrst_n(rrst_n),
    .rd_en(rd_en),
    .g_wptr_sync(g_wptr_sync),
    .b_rptr(b_rptr),
    .g_rptr(g_rptr),
    .empty(empty),
    .almost_empty(almost_empty)
  );

  fifo_mem #(
    .DEPTH(DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .PTR_WIDTH(PTR_WIDTH)) mem_inst (
    .wclk(wclk),
    .wr_en(wr_en),
    .rclk(rclk),
    .rd_en(rd_en),
    .full(full),
    .empty(empty),
    .b_wptr(b_wptr),
    .b_rptr(b_rptr),
    .data_in(data_in),
    .data_out(data_out)
  );

endmodule