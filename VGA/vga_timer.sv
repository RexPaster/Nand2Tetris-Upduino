
module vga_timer #(
    // ---------------------------------------------------------------
    // VGA DEFAULT timing parameters — 640×480 @ 60 Hz
    //   Horizontal: 640 visible | 16 fp | 96 sync | 48 bp  = 800 total
    //   Vertical:   480 visible | 10 fp |  2 sync | 33 bp  = 525 total
    // ---------------------------------------------------------------
    parameter logic [9:0] H_VISIBLE = 10'd640,
    parameter logic [9:0] H_FRONT   = 10'd16,
    parameter logic [9:0] H_SYNC    = 10'd96,
    parameter logic [9:0] H_BACK    = 10'd48,
    parameter logic [9:0] V_VISIBLE = 10'd480,
    parameter logic [9:0] V_FRONT   = 10'd10,
    parameter logic [9:0] V_SYNC    = 10'd2,
    parameter logic [9:0] V_BACK    = 10'd33
) (
    input  logic       clk_pix,
    input  logic       rst_n,
    output logic [9:0] h_cnt,
    output logic [9:0] v_cnt,
    output logic       active,
    output logic       hs_n,
    output logic       vs_n
);

    localparam logic [9:0] H_TOTAL = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800
    localparam logic [9:0] V_TOTAL = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    // Horizontal/vertical timing counters
    always_ff @(posedge clk_pix or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= '0;
            v_cnt <= '0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= '0;
                v_cnt <= (v_cnt == V_TOTAL - 1) ? '0 : v_cnt + 1'b1;
            end else begin
                h_cnt <= h_cnt + 1'b1;
            end
        end
    end

    // Combinational blanking and sync windows
    assign active = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);
    assign hs_n   = ~( (h_cnt >= H_VISIBLE + H_FRONT) &&
                       (h_cnt <  H_VISIBLE + H_FRONT + H_SYNC) );
    assign vs_n   = ~( (v_cnt >= V_VISIBLE + V_FRONT) &&
                       (v_cnt <  V_VISIBLE + V_FRONT + V_SYNC) );
endmodule

