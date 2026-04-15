// framebuffer_ebr30_dualclk.sv
// Hardware path: explicit iCE40 EBR primitives (30 banks, 256x16 each)
// plus a CPU-facing SPRAM shadow copy for screen reads.
// Simulation path: behavioral memory model with CPU writes + VGA reads

module framebuffer #(
    parameter bit SIMULATION   = 1'b0,
    parameter int H_VISIBLE    = 640,
    parameter int V_VISIBLE    = 480,
    parameter int H_TOTAL      = 800,
    parameter int V_TOTAL      = 525,
    parameter int H_WRITEABLE  = 512,
    parameter int V_WRITEABLE  = 240,
    parameter int WRITE_ADDR_W = 13
) (
    input  logic                       clk_pix,
    input  logic                       clk_cpu,
    input  logic                       rst_n,

    // VGA read
    input  logic                       active,
    input  logic [9:0]                 h_cnt,
    input  logic [9:0]                 v_cnt,

    // CPU read/write
    input  logic [WRITE_ADDR_W-1:0]    read_addr,
    output logic [15:0]                read_data,
    input  logic                       write_en,
    input  logic [WRITE_ADDR_W-1:0]    write_addr,
    input  logic [15:0]                write_data,

    // Pixel output
    output logic                       pixel_on
);

    localparam int WORDS_PER_ROW    = 32;
    localparam int BRAM_BLOCKS      = 30;
    localparam int BRAM_BLOCK_WORDS = 256;
    localparam int FB_WORDS         = BRAM_BLOCKS * BRAM_BLOCK_WORDS;
    localparam logic [9:0] H_WRITEABLE_10 = H_WRITEABLE[9:0];
    localparam logic [9:0] V_WRITEABLE_10 = V_WRITEABLE[9:0];

    logic [12:0] read_word_addr;
    logic [3:0]  bit_index;
    logic        fb_in_range;

    logic [15:0] read_word;
    logic        fb_in_range_q;
    logic [3:0]  bit_index_q;

    always_comb begin
        fb_in_range = active && (h_cnt < H_WRITEABLE_10) && (v_cnt < V_WRITEABLE_10);

        if (fb_in_range) begin
            read_word_addr = ({3'b000, v_cnt} << 5) + {7'b0000000, h_cnt[9:4]};
            bit_index      = h_cnt[3:0];
        end else begin
            read_word_addr = '0;
            bit_index      = '0;
        end
    end

    generate
        if (SIMULATION) begin : g_sim
            logic [15:0] fb_mem [0:FB_WORDS-1];
            logic [15:0] cpu_read_word;

            always_ff @(posedge clk_cpu) begin
                if (write_en && (write_addr < FB_WORDS[WRITE_ADDR_W-1:0])) begin
                    fb_mem[write_addr] <= write_data;
                end

                if (read_addr < FB_WORDS[WRITE_ADDR_W-1:0]) begin
                    cpu_read_word <= fb_mem[read_addr];
                end else begin
                    cpu_read_word <= 16'h0000;
                end
            end

            assign read_data = cpu_read_word;

            always_ff @(posedge clk_pix) begin
                fb_in_range_q <= fb_in_range;
                bit_index_q   <= bit_index;

                if (read_word_addr < FB_WORDS[12:0]) begin
                    read_word <= fb_mem[read_word_addr];
                end else begin
                    read_word <= 16'h0000;
                end
            end
        end else begin : g_hw
            logic [15:0] bank_rdata [0:BRAM_BLOCKS-1];
            logic [4:0]  bank_sel_q;
            logic [12:0] read_word_addr_q;
            logic [15:0] shadow_read_data;

            // CPU-facing shadow copy of the screen memory.
            // Reads stay on the CPU clock while the VGA side keeps using EBRs.
            SB_SPRAM256KA shadow_screen (
                .ADDRESS ({1'b0, write_en ? write_addr : read_addr}),
                .DATAIN  (write_data),
                .MASKWREN(4'b0000),
                .WREN    (write_en),
                .CHIPSELECT(1'b1),
                .CLOCK   (clk_cpu),
                .STANDBY (1'b0),
                .SLEEP   (1'b0),
                .POWEROFF(1'b1),
                .DATAOUT (shadow_read_data)
            );

            assign read_data = (read_addr < FB_WORDS[12:0]) ? shadow_read_data : 16'h0000;

            for (genvar i = 0; i < BRAM_BLOCKS; i++) begin : g_bank
                localparam logic [4:0] BANK_ID = i[4:0];
                logic bank_we;

                always_comb begin
                    bank_we = write_en && (write_addr[12:8] == BANK_ID);
                end

                SB_RAM40_4K #(
                    .READ_MODE(0),
                    .WRITE_MODE(0)
                ) u_ebr (
                    .RCLK (clk_pix),
                    .RCLKE(1'b1),
                    .RE   (fb_in_range),
                    .RADDR({3'b000, read_word_addr[7:0]}),
                    .RDATA(bank_rdata[i]),

                    .WCLK (clk_cpu),
                    .WCLKE(1'b1),
                    .WE   (bank_we),
                    .WADDR({3'b000, write_addr[7:0]}),
                    .WDATA(write_data),
                    .MASK (16'h0000)
                );
            end

            always_ff @(posedge clk_pix or negedge rst_n) begin
                if (!rst_n) begin
                    fb_in_range_q <= 1'b0;
                    bit_index_q   <= 4'h0;
                    bank_sel_q    <= 5'h0;
                    read_word_addr_q <= 13'h0000;
                    read_word     <= 16'h0000;
                end else begin
                    fb_in_range_q <= fb_in_range;
                    bit_index_q   <= bit_index;
                    bank_sel_q    <= read_word_addr[12:8];
                    read_word_addr_q <= read_word_addr;

                    case (bank_sel_q)
                        5'd0:  read_word <= bank_rdata[0];
                        5'd1:  read_word <= bank_rdata[1];
                        5'd2:  read_word <= bank_rdata[2];
                        5'd3:  read_word <= bank_rdata[3];
                        5'd4:  read_word <= bank_rdata[4];
                        5'd5:  read_word <= bank_rdata[5];
                        5'd6:  read_word <= bank_rdata[6];
                        5'd7:  read_word <= bank_rdata[7];
                        5'd8:  read_word <= bank_rdata[8];
                        5'd9:  read_word <= bank_rdata[9];
                        5'd10: read_word <= bank_rdata[10];
                        5'd11: read_word <= bank_rdata[11];
                        5'd12: read_word <= bank_rdata[12];
                        5'd13: read_word <= bank_rdata[13];
                        5'd14: read_word <= bank_rdata[14];
                        5'd15: read_word <= bank_rdata[15];
                        5'd16: read_word <= bank_rdata[16];
                        5'd17: read_word <= bank_rdata[17];
                        5'd18: read_word <= bank_rdata[18];
                        5'd19: read_word <= bank_rdata[19];
                        5'd20: read_word <= bank_rdata[20];
                        5'd21: read_word <= bank_rdata[21];
                        5'd22: read_word <= bank_rdata[22];
                        5'd23: read_word <= bank_rdata[23];
                        5'd24: read_word <= bank_rdata[24];
                        5'd25: read_word <= bank_rdata[25];
                        5'd26: read_word <= bank_rdata[26];
                        5'd27: read_word <= bank_rdata[27];
                        5'd28: read_word <= bank_rdata[28];
                        5'd29: read_word <= bank_rdata[29];
                        default: read_word <= 16'h0000;
                    endcase
                end
            end
        end
    endgenerate

    assign pixel_on = fb_in_range_q ? read_word[bit_index_q] : 1'b0;

endmodule
