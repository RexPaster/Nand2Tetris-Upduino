`include "./cpu_jopdorp_optimized.sv"
`include "memory.sv"

`define computer 1

// Hack computer wrapper:
// - CPU executes from instruction stream provided by memory.sv.
// - memory.sv also owns RAM/ROM/screen/keyboard address decoding.
module computer #(
  parameter SIMULATION = 1'b0,
  parameter USE_SPI_FLASH_ROM = 1'b0
) (
    input  reset,
    input  clock,
    input  [15:0] keyboard_value,
    input  [15:0] screen_read_value,
    input  rom_spi_miso,
    output [14:0] pc,
    output rom_ready,
    output rom_spi_mosi,
    output rom_spi_sck,
    output rom_spi_cs_n,
    output [12:0] screen_read_address,
    output [12:0] screen_write_address,
    output        screen_write_enable,
    output [15:0] screen_write_value
);
  wire writeM;

  wire [15:0] cpuValueToMemory;
  wire [15:0] instruction;

  wire [14:0] addressM;
  wire [15:0] value_to_cpu;

  // Centralized Hack memory subsystem including instruction ROM.
  memory #(
    .SIMULATION(SIMULATION),
    .USE_SPI_FLASH_ROM(USE_SPI_FLASH_ROM)
  ) memory(
    cpuValueToMemory,
    !clock,
    writeM,
    addressM,
    pc,
    keyboard_value,
    rom_spi_miso,
    instruction,
    value_to_cpu,
    rom_ready,
    rom_spi_mosi,
    rom_spi_sck,
    rom_spi_cs_n,
    screen_read_value,
    screen_read_address,
    screen_write_address,
    screen_write_enable,
    screen_write_value
  );
  // CPU is paused when ROM is not ready (SPI flash mode).
  cpu_jopdorp_optimized cpu(value_to_cpu,
    instruction,
    reset,
    clock,
    rom_ready,
    cpuValueToMemory,
    writeM,
    addressM,
    pc);
endmodule
