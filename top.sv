`include "NAND2TETRIS/05/computer.sv"
`include "keyboard/keyboard.sv"
`include "VGA/vga_pll.sv"
`include "VGA/vga_timer.sv"
`include "VGA/vga_top.sv"

// System top-level:
// - Generates 25MHz from the 12MHz board clock.
// - Bridges keyboard + Hack computer core + VGA framebuffer pipeline.
// - Exposes optional SPI flash ROM pins for instruction fetch.
module top #(
    parameter bit SIMULATION = 1'b0,
    parameter bit USE_SPI_FLASH_ROM = 1'b1
) (
    input  logic       clk_12mhz,
    input  logic       rst_n,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    input  logic       rom_spi_miso,
    output logic       rom_spi_mosi,
    output logic       rom_spi_sck,
    output logic       rom_spi_cs_n,

    // Digilent PMOD VGA — JA connector (upper)
    output logic [3:0] vga_r,    // R[3:0]  → JA1-4
    output logic [3:0] vga_g,    // G[3:0]  → JA7-10

    // Digilent PMOD VGA — JB connector (lower)
    output logic [3:0] vga_b,    // B[3:0]  → JB1-4
    output logic       vga_hs,   // HSync   → JB7  (active-low)
    output logic       vga_vs    // VSync   → JB8  (active-low)
);

    // Shared screen bus between Hack memory map and VGA framebuffer.
    logic [12:0] fb_write_addr;
    logic        fb_write_en;
    logic [15:0] fb_write_data;
    logic [12:0] fb_read_addr;
    logic [15:0] fb_read_data;

    // Peripheral status/inputs consumed by the computer core.
    logic [15:0] keyboard_value;
    logic        rom_ready;

    // PS/2 keyboard decoder writes Hack keyboard register value.
    keyboard u_keyboard(
        .clk(clk_12mhz),
        .rst_n(rst_n),
        .ps2_clk(ps2_clk),
        .ps2_data(ps2_data),
        .keyboard_value(keyboard_value)
    );

    // Hack computer core: CPU + memory map + ROM interface.
    computer #(
        .SIMULATION(SIMULATION),
        .USE_SPI_FLASH_ROM(USE_SPI_FLASH_ROM)
    ) hack(
        .reset(!rst_n),
        .clock(clk_12mhz),
        .keyboard_value(keyboard_value),
        .screen_read_value(fb_read_data),
        .rom_spi_miso(rom_spi_miso),
        .pc(),
        .rom_ready(rom_ready),
        .rom_spi_mosi(rom_spi_mosi),
        .rom_spi_sck(rom_spi_sck),
        .rom_spi_cs_n(rom_spi_cs_n),
        .screen_read_address(fb_read_addr),
        .screen_write_address(fb_write_addr),
        .screen_write_enable(fb_write_en),
        .screen_write_value(fb_write_data)
        );

    vga_top #(
        .SIMULATION(SIMULATION)
    ) vga_top (
        .clk_12mhz(clk_12mhz),
        .rst_n(rst_n),
        .fb_read_addr(fb_read_addr),
        .fb_read_data(fb_read_data),
        .fb_write_en(fb_write_en),
        .fb_write_data(fb_write_data),
        .fb_write_addr(fb_write_addr),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hs(vga_hs),
        .vga_vs(vga_vs)
    );

endmodule
