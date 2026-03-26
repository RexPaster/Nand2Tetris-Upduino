    // ---------------------------------------------------------------
    // Pixel clock: ~25.125 MHz from 12 MHz via SB_PLL40_CORE
    //   f_vco = 12 × (DIVF+1) = 12 × 67 = 804 MHz   (in-range: 533–1066 MHz)
    //   f_pix = f_vco / 2^DIVQ = 804 / 32 = 25.125 MHz  (target: 25.175 MHz)
    // ---------------------------------------------------------------

module vga_pll #(
    parameter bit SIMULATION = 1'b0 //Is this module being sumulated or syntheized?
) (
    input logic clk_12mhz,      // Upduino 12Mhz Global Clock Input
    output logic clk_vga,       // VGA 25.125 Mhz Clock Output
    output logic pll_locked    // PLL Locked output (1 when clock is stableized)
);
    generate
        if (SIMULATION) begin : g_sim
            // Bypass PLL in simulation; use 12 MHz clock directly
            assign clk_vga   = clk_12mhz;
            assign pll_locked = 1'b1;
        end else begin : g_pll
            SB_PLL40_CORE #(
                .FEEDBACK_PATH ("SIMPLE"),
                .PLLOUT_SELECT ("GENCLK"),
                .DIVR          (4'd0),    // reference divider  = DIVR+1 = 1
                .DIVF          (7'd66),   // feedback multiplier = DIVF+1 = 67
                .DIVQ          (3'd5),    // output divider      = 2^5   = 32
                .FILTER_RANGE  (3'b001)   // 10–20 MHz reference band
            ) pll (
                .REFERENCECLK (clk_12mhz),
                .PLLOUTCORE   (clk_vga),
                .PLLOUTGLOBAL (),
                .LOCK         (pll_locked),
                .EXTFEEDBACK  (1'b0),
                .DYNAMICDELAY (8'b0),
                .LATCHINPUTVALUE (1'b0),
                .SDO          (),
                .SDI          (1'b0),
                .SCLK         (1'b0),
                .RESETB       (1'b1),
                .BYPASS       (1'b0)
            );
        end
    endgenerate
endmodule
