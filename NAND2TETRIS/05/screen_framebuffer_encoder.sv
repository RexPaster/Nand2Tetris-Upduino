`ifndef screen_framebuffer_encoder
`define screen_framebuffer_encoder 1

module screen_framebuffer_encoder(
    input  [15:0] in,
    input  [12:0] address,
    input         load,
    input         clock,
    input  [15:0] fb_read_value,
    output [15:0] out,
    output [12:0] fb_read_address,
    output [12:0] fb_write_address,
    output        fb_write_enable,
    output [15:0] fb_write_value
);
  // Encode Hack screen memory accesses to shared framebuffer read/write signals.
  assign out = fb_read_value;
  assign fb_read_address = address;
  assign fb_write_address = address;
  assign fb_write_enable = load;
  assign fb_write_value = in;

  // Keep clock referenced to avoid changing module interface at this stage.
  wire _unused_clock = clock;
endmodule

`endif
