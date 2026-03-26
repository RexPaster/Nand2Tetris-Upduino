`timescale 1ns/1ps

`ifndef TB_USE_SPI_FLASH_ROM
`define TB_USE_SPI_FLASH_ROM 1
`endif

module top_tb;
    logic       clk_12mhz;
    logic       rst_n;
    logic       ps2_clk;
    logic       ps2_data;
    logic       rom_spi_miso;
    logic       rom_spi_mosi;
    logic       rom_spi_sck;
    logic       rom_spi_cs_n;
    logic [3:0] vga_r, vga_g, vga_b;
    logic       vga_hs, vga_vs;
    integer     fail_count;

    top #(
        .SIMULATION(1'b1),
        .USE_SPI_FLASH_ROM(`TB_USE_SPI_FLASH_ROM)
    ) dut (
        .clk_12mhz(clk_12mhz),
        .rst_n     (rst_n),
        .ps2_clk   (ps2_clk),
        .ps2_data  (ps2_data),
        .rom_spi_miso(rom_spi_miso),
        .rom_spi_mosi(rom_spi_mosi),
        .rom_spi_sck (rom_spi_sck),
        .rom_spi_cs_n(rom_spi_cs_n),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .vga_hs    (vga_hs),
        .vga_vs    (vga_vs)
    );

    // 12 MHz clock: period = ~83 ns, half-period = 41 ns (integer safe for Yosys)
    initial begin
        clk_12mhz = 1'b0;
        forever #41 clk_12mhz = ~clk_12mhz;
    end

    // Count falling edges of HSync to verify timing
    // At 12 MHz sim clock: one line = 800 × 82 ns ≈ 65.6 µs
    // Running 200 µs should produce ~3 complete lines → 3 HSync pulses
    integer hs_count;
    integer vs_count;
    initial hs_count = 0;
    always @(negedge vga_hs) hs_count = hs_count + 1;
    initial vs_count = 0;
    always @(negedge vga_vs) vs_count = vs_count + 1;

    task automatic expect_known_sync(input string phase);
        begin
            if (vga_hs === 1'bx || vga_vs === 1'bx) begin
                $display("FAIL: unknown sync output value during %s", phase);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        fail_count = 0;
        rst_n = 1'b0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        rom_spi_miso = 1'b1;
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);

        // Hold reset for ~200 ns (enough for sync chain to settle)
        #200 rst_n = 1'b1;
        repeat (8) begin
            @(posedge clk_12mhz);
            expect_known_sync("post-reset startup");
        end

        // Run for ~3 horizontal lines (3 × 800 × 82 ns ≈ 197 µs)
        #200_000;

        // Sanity check: expect at least 2 HSync pulses
        if (hs_count < 2)
            begin
                $display("FAIL: only %0d HSync pulses seen (expected >=2)", hs_count);
                fail_count = fail_count + 1;
            end
        else
            $display("PASS: %0d HSync pulses in 200 us", hs_count);

        // A full frame is much longer than this test window, so VS is expected not to fall.
        if (vs_count != 0) begin
            $display("FAIL: unexpected VSync falling edge(s): %0d", vs_count);
            fail_count = fail_count + 1;
        end else begin
            $display("PASS: no VSync falling edge in short-run window");
        end

        // Verify RGB outputs are 0 during blanking (vga_hs low = sync = blanking)
        @(negedge vga_hs);
        @(posedge clk_12mhz);
        if (vga_r !== 4'b0 || vga_g !== 4'b0 || vga_b !== 4'b0)
            begin
                $display("FAIL: colour outputs non-zero during blanking (r=%0h g=%0h b=%0h)",
                         vga_r, vga_g, vga_b);
                fail_count = fail_count + 1;
            end
        else
            $display("PASS: colour outputs are 0 during HSync blanking");

        if (fail_count != 0) begin
            $display("TEST FAILED with %0d error(s)", fail_count);
            $fatal(1);
        end

        $display("TEST PASSED");

        $finish;
    end
endmodule
