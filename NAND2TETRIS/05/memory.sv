`include "ram_16K_spram.sv"
`include "screen_framebuffer_encoder.sv"
`include "rom.sv"

// Hack memory map implementation:
// - 0x0000-0x3FFF: 16K main RAM (mapped to UP5K SPRAM)
// - 0x4000-0x5FFF: screen word interface (bridged to framebuffer)
// - 0x6000: keyboard register
// - instruction fetch: dedicated ROM path (file ROM or SPI flash)
module memory #(
  parameter SIMULATION = 1'b0,
  parameter USE_SPI_FLASH_ROM = 1'b0
) (
  input  [15:0] in,
  input         clock,
  input         load,
  input  [14:0] address,
  input  [14:0] pc,
  input  [15:0] keyboard_value,
  input         rom_spi_miso,
  output [15:0] instruction,
  output [15:0] out,
  output        rom_ready,
  output        rom_spi_mosi,
  output        rom_spi_sck,
  output        rom_spi_cs_n,
  input  [15:0] screen_read_value,
  output [12:0] screen_read_address,
  output [12:0] screen_write_address,
  output        screen_write_enable,
  output [15:0] screen_write_value
);
  wire[15:0] outM, outS, outSK;
  wire N14, Mload, Sload;

  // Decode RAM vs screen/keyboard by Hack address map bit[14].
  assign N14 = ~address[14];
  assign Mload = N14 & load;
  assign Sload = address[14] & load;

  // Instruction ROM path (separate from data memory map).
  rom #(
    .ROM_FILE(SIMULATION ? "rom/rom.hack" : "rom/rom.hack"),
    .USE_SPI_FLASH(USE_SPI_FLASH_ROM)
  ) instruction_rom(
    .clock(clock),
    .rst_n(1'b1),
    .address(pc),
    .out(instruction),
    .ready(rom_ready),
    .spi_miso(rom_spi_miso),
    .spi_mosi(rom_spi_mosi),
    .spi_sck(rom_spi_sck),
    .spi_cs_n(rom_spi_cs_n)
  );

  // Data RAM uses UP5K SPRAM for capacity and timing margin.
  ram_16K_spram ram16k(in, address[13:0], Mload, clock, outM);

  // Screen accesses are forwarded to the shared VGA framebuffer.
  screen_framebuffer_encoder screen(
    .in(in),
    .address(address[12:0]),
    .load(Sload),
    .clock(clock),
    .fb_read_value(screen_read_value),
    .out(outS),
    .fb_read_address(screen_read_address),
    .fb_write_address(screen_write_address),
    .fb_write_enable(screen_write_enable),
    .fb_write_value(screen_write_value)
  );
  // Output mux: select RAM vs screen/keyboard path
  assign out = address[14] ? outSK : outM;
  // Select keyboard vs screen within upper address space
  assign outSK = address[13] ? keyboard_value : outS;
endmodule
