module framebuffer #(
    // Kept for compatibility with existing instantiations.
    parameter bit SIMULATION = 1'b0,

    // Visible raster dimensions from timing generator.
    parameter int H_VISIBLE = 640,
    parameter int V_VISIBLE = 480,
    parameter int H_TOTAL   = 800,
    parameter int V_TOTAL   = 525,

    // Full Hack computer screen: 512x256 pixels = 8K words x 16 bits.
    parameter int H_WRITEABLE = 512,
    parameter int V_WRITEABLE = 256,

    // Hack screen uses 8K words (13-bit address), each word holds 16 pixels.
    parameter int WRITE_ADDR_W = 13,

    // Split point for storage banking.
    // First BRAM_WORDS are mapped to BRAM; remainder are mapped to LUT RAM.
    parameter int BRAM_WORDS = 7680 //7680
) (
    // Dual Clock
    input  logic       clk_pix,
    input  logic       clk_cpu,
    input  logic       rst_n,

    // VGA read interface
    input  logic       active,
    input  logic [9:0] h_cnt,
    input  logic [9:0] v_cnt,

    // CPU read interface (Hack screen word reads).
    input  logic [WRITE_ADDR_W-1:0] read_addr,
    output logic [15:0] read_data,

    // Dual-port write interface (same clock domain).
    input  logic       write_en,
    input  logic [WRITE_ADDR_W-1:0] write_addr,
    input  logic [15:0] write_data,

    // 1-bit pixel output: 1=white, 0=black.
    output logic       pixel_on
);
    // Hack screen geometry: 512x256 pixels = 8192 words x 16 bits.
    localparam int WORDS_PER_ROW = 32;  // 512 pixels / 16 bits per word
    localparam int FB_WORDS      = 8192; //8192;  // 512 * 256 / 16
    localparam int LUT_WORDS     = FB_WORDS - BRAM_WORDS;
    localparam int LUT_ADDR_W    = $clog2(LUT_WORDS);

    // Read-side word address and bit index generated from {v_cnt, h_cnt}.
    logic [WRITE_ADDR_W-1:0] read_word_addr;
    logic [WRITE_ADDR_W-1:0] write_word_addr;
    logic [3:0]              bit_index;

    // Region-valid qualifiers for read and write sides.
    logic                 fb_in_range;
    logic                 write_in_range;
    logic [7:0]           write_row;
    logic [4:0]           write_col;

    // Integer helper used for safe address math.
    int unsigned          read_word_calc;

    logic [15:0] read_word;
    logic [15:0] read_word_bram;
    logic [15:0] read_word_lut;
    logic [15:0] cpu_read_word_bram;
    logic [15:0] cpu_read_word_lut;
    logic        cpu_read_is_lut;
    logic        cpu_read_is_lut_q;
    logic        read_is_lut;
    logic        read_is_lut_q;
    logic        write_is_lut;
    logic        fb_in_range_q;
    logic [LUT_ADDR_W-1:0] lut_read_addr;
    logic [LUT_ADDR_W-1:0] lut_write_addr;
    logic [LUT_ADDR_W-1:0] cpu_lut_read_addr;
    logic [WRITE_ADDR_W-1:0] bram_read_addr;
    logic [WRITE_ADDR_W-1:0] bram_write_addr;
    logic [WRITE_ADDR_W-1:0] cpu_bram_read_addr;
    logic [WRITE_ADDR_W-1:0] lut_read_offset;
    logic [WRITE_ADDR_W-1:0] cpu_lut_read_offset;
    logic [WRITE_ADDR_W-1:0] lut_write_offset;
    logic [3:0]              bit_index_q;
    int unsigned             write_word_calc;

    // BRAM bank.
    (* ram_style = "block" *) logic [15:0] fb_mem_bram [0:BRAM_WORDS-1];

    // LUT RAM bank.
    (* ram_style = "distributed" *) logic [15:0] fb_mem_lut [0:LUT_WORDS-1];


    // --- CPU Port (clk_cpu): Handles CPU read/write ---
    always_ff @(posedge clk_cpu or negedge rst_n) begin
        if (!rst_n) begin
            cpu_read_word_bram <= '0;
            cpu_read_word_lut <= '0;
            cpu_read_is_lut_q <= 1'b0;
        end else begin
            // Write
            if (write_en && write_in_range) begin
                if (write_is_lut) fb_mem_lut[lut_write_addr] <= write_data;
                else              fb_mem_bram[bram_write_addr] <= write_data;
            end
            // Registered CPU read
            cpu_read_word_bram <= fb_mem_bram[cpu_bram_read_addr];
            cpu_read_word_lut  <= fb_mem_lut[cpu_lut_read_addr];
            cpu_read_is_lut_q  <= cpu_read_is_lut;
        end
    end

    assign read_data = cpu_read_is_lut_q ? cpu_read_word_lut : cpu_read_word_bram;

    // --- VGA Pixel Port (clk_pix): Handles pixel reads ---
    always_ff @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            read_word_bram <= '0;
            read_word_lut <= '0;
            read_is_lut_q <= 1'b0;
            fb_in_range_q <= 1'b0;
            bit_index_q <= '0;
        end else begin
            read_word_bram <= fb_mem_bram[bram_read_addr];
            read_word_lut  <= fb_mem_lut[lut_read_addr];
            read_is_lut_q  <= read_is_lut;
            fb_in_range_q  <= fb_in_range;
            bit_index_q    <= bit_index;
        end
    end

    assign read_word = read_is_lut_q ? read_word_lut : read_word_bram;

    // Address and range generation.
    always_comb begin
        // Read is valid only inside active video and screen window.
        fb_in_range = active && (int'(h_cnt) < H_WRITEABLE) && (int'(v_cnt) < V_WRITEABLE);

        // Write address from CPU: uses Hack's 32 words/row layout (13-bit address).
        write_row = write_addr[12:5];
        write_col = write_addr[4:0];

        // Write is valid for full screen (512x256).
        write_in_range = (int'(write_row) < V_WRITEABLE) && (int'(write_col) < WORDS_PER_ROW);
        write_word_calc = (int'(write_row) * WORDS_PER_ROW) + int'(write_col);
        write_word_addr = write_word_calc[WRITE_ADDR_W-1:0];

        // Read address from VGA: Hack screen word mapping: addr = y * 32 + floor(x / 16).
        if (fb_in_range) begin
            read_word_calc = (int'(v_cnt) * WORDS_PER_ROW) + int'(h_cnt[9:4]);
            read_word_addr = read_word_calc[WRITE_ADDR_W-1:0];
            bit_index = h_cnt[3:0];
        end else begin
            read_word_calc = '0;
            read_word_addr = '0;
            bit_index = '0;
        end

        read_is_lut = (int'(read_word_addr) >= BRAM_WORDS);
        cpu_read_is_lut = (int'(read_addr) >= BRAM_WORDS);
        write_is_lut = (int'(write_word_addr) >= BRAM_WORDS);
        lut_read_offset = read_word_addr - BRAM_WORDS[WRITE_ADDR_W-1:0];
        cpu_lut_read_offset = read_addr - BRAM_WORDS[WRITE_ADDR_W-1:0];
        lut_write_offset = write_word_addr - BRAM_WORDS[WRITE_ADDR_W-1:0];
        lut_read_addr = read_is_lut ? lut_read_offset[LUT_ADDR_W-1:0] : '0;
        cpu_lut_read_addr = cpu_read_is_lut ? cpu_lut_read_offset[LUT_ADDR_W-1:0] : '0;
        lut_write_addr = write_is_lut ? lut_write_offset[LUT_ADDR_W-1:0] : '0;
        bram_read_addr = read_is_lut ? '0 : read_word_addr;
        cpu_bram_read_addr = cpu_read_is_lut ? '0 : read_addr;
        bram_write_addr = write_is_lut ? '0 : write_word_addr;

    end

    // Pixels outside the screen window are forced black.
    assign pixel_on = fb_in_range_q ? read_word[bit_index_q] : 1'b0;

endmodule
