`timescale 1ns/1ps

module tb_asynchronous_fifo;

  localparam DEPTH = 16;
  localparam DATA_WIDTH = 8;
  localparam AF_LEVEL = 14;
  localparam AE_LEVEL = 2;
  localparam SB_DEPTH = 128; // scoreboard depth

  logic wrst_n, wclk, wr_en;
  logic rrst_n, rclk, rd_en;
  logic [DATA_WIDTH-1:0] data_in;
  logic [DATA_WIDTH-1:0] data_out;
  logic full, empty;
  logic almost_full, almost_empty;

  logic [DATA_WIDTH-1:0] exp_mem [0:SB_DEPTH-1];
  integer exp_wptr, exp_rptr;
  integer write_cnt, read_cnt;
  integer err_cnt;
  integer i;

  asynchronous_fifo #(
    .DEPTH(DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .AF_LEVEL(AF_LEVEL),
    .AE_LEVEL(AE_LEVEL)) dut (
    .wrst_n(wrst_n),
    .wclk(wclk),
    .wr_en(wr_en),
    .rrst_n(rrst_n),
    .rclk(rclk),
    .rd_en(rd_en),
    .data_in(data_in),
    .data_out(data_out),
    .full(full),
    .empty(empty),
    .almost_full(almost_full),
    .almost_empty(almost_empty)
  );

  // 100MHz (10ns) & 76.9MHz (13ns)
  initial wclk = 1'b0;
  always #5 wclk = ~wclk;

  initial rclk = 1'b0;
  always #6.5 rclk = ~rclk;

  // EDA Playground EPWave
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_asynchronous_fifo);
  end

  /*********************************************************/
  always @(posedge wclk) begin
    if (!wrst_n) begin
      exp_wptr <= 0;
      write_cnt <= 0;
    end
    else if (wr_en && !full) begin
      exp_mem[exp_wptr] = data_in;
      exp_wptr = (exp_wptr + 1) % SB_DEPTH;
      write_cnt = write_cnt + 1;
    end
  end

  always @(posedge rclk) begin
    if (!rrst_n) begin
      exp_rptr <= 0;
      read_cnt <= 0;
    end else if (rd_en && !empty) begin : rd_chk
      logic [DATA_WIDTH-1:0] expected;
      expected = exp_mem[exp_rptr];
      exp_rptr = (exp_rptr + 1) % SB_DEPTH;
      #1;
      if (rrst_n) begin
        if (data_out !== expected) begin
          $display("[ERROR][%0t] exp=0x%02h, got=0x%02h", $time, expected, data_out);
          err_cnt = err_cnt + 1;
        end
        read_cnt = read_cnt + 1;
      end
    end
  end

  /*********************************************************/
  task automatic check_cond(input logic cond, input string msg);
    begin
      if (cond !== 1'b1) begin
        $display("[FAIL][%0t] %s (full=%b af=%b empty=%b ae=%b)", $time, msg, full, almost_full, empty, almost_empty);
        err_cnt = err_cnt + 1;
      end
    end
  endtask

  /*********************************************************/
  initial begin
    wrst_n = 1'b0;
    rrst_n = 1'b0;
    wr_en = 1'b0;
    rd_en = 1'b0;
    data_in = 8'h00;
    err_cnt = 0;

    #28;
    check_cond(full === 1'b0 && almost_full === 1'b0, "Reset write flags");
    check_cond(empty === 1'b1 && almost_empty === 1'b1, "Reset read flags");

    wrst_n = 1'b1;
    rrst_n = 1'b1;
    repeat (2) @(negedge wclk);
    repeat (2) @(negedge rclk);
    $display("[INFO] Reset check done.");

    // Test 1
    $display("[INFO] Test 1: Fill FIFO to almost_full and full");
    for (i = 1; i <= DEPTH; i = i + 1) begin
      @(negedge wclk);
      wr_en   = 1'b1;
      data_in = 8'hA0 + i[7:0];
      @(posedge wclk);
      #1;
      if (i < AF_LEVEL) begin
        check_cond(almost_full === 1'b0 && full === 1'b0, "Before AF_LEVEL");
      end else if (i < DEPTH) begin
        check_cond(almost_full === 1'b1 && full === 1'b0, "At/After AF_LEVEL");
      end else begin
        check_cond(almost_full === 1'b1 && full === 1'b1, "At full");
      end
    end

    repeat (2) begin
      @(negedge wclk);
      wr_en   = 1'b1;
      data_in = 8'hFF;
      @(posedge wclk);
      #1;
      check_cond(full === 1'b1, "Overflow");
    end
    @(negedge wclk);
    wr_en = 1'b0;
    check_cond(write_cnt == DEPTH, "Write count should stay 16");

    // Test 2
    $display("[INFO] Test 2: Drain FIFO to almost_empty and empty");
    repeat (4) @(negedge rclk);
    check_cond(empty === 1'b0 && almost_empty === 1'b0, "Full before drain");

    for (i = 1; i <= DEPTH; i = i + 1) begin
      @(negedge rclk);
      rd_en = 1'b1;
      @(posedge rclk);
      #1;
      if ((DEPTH - i) > AE_LEVEL) begin
        check_cond(almost_empty === 1'b0 && empty === 1'b0, "Above AE_LEVEL");
      end else if ((DEPTH - i) > 0) begin
        check_cond(almost_empty === 1'b1 && empty === 1'b0, "At/Below AE_LEVEL");
      end else begin
        check_cond(almost_empty === 1'b1 && empty === 1'b1, "At empty");
      end
    end

    repeat (2) begin
      @(negedge rclk);
      rd_en = 1'b1;
      @(posedge rclk);
      #1;
      check_cond(empty === 1'b1, "Underflow");
    end
    @(negedge rclk);
    rd_en = 1'b0;
    check_cond(read_cnt == DEPTH, "Read count should stay 16");

    // Test 3
    $display("[INFO] Test 3: Early-warning flow control");
    repeat (4) @(negedge wclk);

    // write
    i = 0;
    while (!almost_full) begin
      @(negedge wclk);
      wr_en   = 1'b1;
      data_in = 8'h50 + i[7:0];
      i = i + 1;
      @(posedge wclk);
      #1;
    end
    @(negedge wclk);
    wr_en   = 1'b1;
    data_in = 8'h5F;
    @(posedge wclk);
    #1;
    check_cond(full === 1'b0, "Stopped before full");
    @(negedge wclk);
    wr_en = 1'b0;

    // read
    repeat (4) @(negedge rclk);
    while (!almost_empty) begin
      @(negedge rclk);
      rd_en = 1'b1;
      @(posedge rclk);
      #1;
    end
    while (!empty) begin
      @(negedge rclk);
      rd_en = 1'b1;
      @(posedge rclk);
      #1;
    end
    @(negedge rclk);
    rd_en = 1'b0;
    check_cond(read_cnt == write_cnt, "Test 3 drain match");

    // Test 4
    $display("[INFO] Test 4: Concurrent async & wrap-around");
    repeat (4) @(negedge wclk);
    repeat (4) @(negedge rclk);

    fork
      // write
      begin : wr_thread
        integer w_cyc;
        for (w_cyc = 0; w_cyc < 120; w_cyc = w_cyc + 1) begin
          @(negedge wclk);
          if (w_cyc < 60)
            wr_en = (($urandom % 100) < 85);
          else
            wr_en = (($urandom % 100) < 30);
          data_in = $urandom & 8'hFF;
        end
        @(negedge wclk);
        wr_en = 1'b0;
      end

      // read
      begin : rd_thread
        integer r_cyc;
        for (r_cyc = 0; r_cyc < 100; r_cyc = r_cyc + 1) begin
          @(negedge rclk);
          if (r_cyc < 50)
            rd_en = (($urandom % 100) < 30);
          else
            rd_en = (($urandom % 100) < 85);
        end
        @(negedge rclk);
        rd_en = 1'b0;
      end
    join

    repeat (4) @(negedge rclk);
    while (!empty) begin
      @(negedge rclk);
      rd_en = 1'b1;
      @(posedge rclk);
      #1;
    end
    @(negedge rclk);
    rd_en = 1'b0;

    repeat (4) @(negedge wclk);
    repeat (4) @(negedge rclk);

    // summary
    check_cond(write_cnt == read_cnt, "Final total write == read");
    check_cond(empty === 1'b1 && almost_empty === 1'b1, "Final empty state");
    check_cond(full === 1'b0 && almost_full === 1'b0, "Final not-full state");

    $display("========================================");
    $display("Total Writes: %0d", write_cnt);
    $display("Total Reads: %0d", read_cnt);
    $display("Total Errors: %0d", err_cnt);
    if (err_cnt == 0)
      $display("ALL TESTS PASSED");
    else
      $display("TEST FAILED");
    $display("========================================");
    $finish;
  end

endmodule