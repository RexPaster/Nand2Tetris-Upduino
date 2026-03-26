module vga_top #(
    parameter bit SIMULATION = 1'b0
) (
    input  logic       clk_12mhz,
    input  logic       rst_n,

    // External framebuffer read interface (Hack screen word format).
    input  logic [12:0] fb_read_addr,
    output logic [15:0] fb_read_data,

    // External framebuffer write interface (Hack screen word format).
    input  logic       fb_write_en,
    input  logic [15:0] fb_write_data,
    input  logic [12:0] fb_write_addr,

    // Digilent PMOD VGA - JA connector (upper)
    output logic [3:0] vga_r,    // R[3:0]  -> JA1-4
    output logic [3:0] vga_g,    // G[3:0]  -> JA7-10

    // Digilent PMOD VGA - JB connector (lower)
    output logic [3:0] vga_b,    // B[3:0]  -> JB1-4
    output logic       vga_hs,   // HSync   -> JB7  (active-low)
    output logic       vga_vs    // VSync   -> JB8  (active-low)
);
    // PLL clock signals
    logic clk_25mhz;
    logic pll_locked;

    // ---------------------------------------------------------------
    // PLL Clock Generation (12MHz -> 25MHz)
    // ---------------------------------------------------------------
    vga_pll #(
        .SIMULATION(SIMULATION)
    ) u_pll (
        .clk_12mhz(clk_12mhz),
        .clk_vga(clk_25mhz),
        .pll_locked(pll_locked)
    );

    // ---------------------------------------------------------------
    // Reset synchroniser: async assert, sync de-assert on clk.
    // Holds design in reset until the PLL has locked.
    // ---------------------------------------------------------------
    logic [1:0] rst_pipe;
    logic       srst_n;

    always_ff @(posedge clk_25mhz or negedge rst_n) begin
        if (!rst_n) rst_pipe <= 2'b00;
        else        rst_pipe <= {rst_pipe[0], 1'b1};
    end
    assign srst_n = rst_pipe[1];

    // ---------------------------------------------------------------
    // VGA timing generator
    // ---------------------------------------------------------------
    localparam logic [9:0] H_VISIBLE = 10'd640;
    localparam logic [9:0] H_FRONT   = 10'd16;
    localparam logic [9:0] H_SYNC    = 10'd96;
    localparam logic [9:0] H_BACK    = 10'd48;
    localparam logic [9:0] V_VISIBLE = 10'd480;
    localparam logic [9:0] V_FRONT   = 10'd10;
    localparam logic [9:0] V_SYNC    = 10'd2;
    localparam logic [9:0] V_BACK    = 10'd33;

    logic [9:0] h_cnt, v_cnt;
    logic active, hs_n, vs_n;
    vga_timer #(
        .H_VISIBLE(H_VISIBLE),
        .H_FRONT(H_FRONT),
        .H_SYNC(H_SYNC),
        .H_BACK(H_BACK),
        .V_VISIBLE(V_VISIBLE),
        .V_FRONT(V_FRONT),
        .V_SYNC(V_SYNC),
        .V_BACK(V_BACK)
    ) vga_timer(
        .clk_pix(clk_25mhz),
        .rst_n(srst_n),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .active(active),
        .hs_n(hs_n),
        .vs_n(vs_n)
    );

    // ---------------------------------------------------------------
    // Framebuffer - Full Hack computer screen: 512x256
    // ---------------------------------------------------------------
    localparam logic [9:0] H_WRITEABLE = 10'd512;
    localparam logic [9:0] V_WRITEABLE = 10'd256;

    logic pixel_on;
    framebuffer #(
        .SIMULATION(SIMULATION),
        .H_VISIBLE(H_VISIBLE),
        .V_VISIBLE(V_VISIBLE),
        .H_WRITEABLE(H_WRITEABLE),
        .V_WRITEABLE(V_WRITEABLE)
    ) u_framebuffer (
        .clk_pix(clk_25mhz),
        .clk_cpu(clk_12mhz),
        .rst_n(srst_n),
        .active(active),
        .h_cnt(h_cnt),
        .v_cnt(v_cnt),
        .read_addr(fb_read_addr),
        .read_data(fb_read_data),
        .write_en(fb_write_en),
        .write_addr(fb_write_addr),
        .write_data(fb_write_data),
        .pixel_on(pixel_on)
    );

    logic mono_on;

    assign vga_r = {4{mono_on}};
    assign vga_g = {4{mono_on}};
    assign vga_b = {4{mono_on}};

    // ---------------------------------------------------------------
    // Registered VGA outputs - one pipeline stage for clean timing
    // ---------------------------------------------------------------
    always_ff @(posedge clk_25mhz or negedge srst_n) begin
        if (!srst_n) begin
            mono_on <= 1'b0;
            vga_hs <= 1'b1;
            vga_vs <= 1'b1;
        end else begin
            vga_hs <= hs_n;
            vga_vs <= vs_n;
            mono_on <= pixel_on;
        end
    end

endmodule
