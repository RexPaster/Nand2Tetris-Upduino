`ifndef keyboard
`define keyboard 1

module keyboard (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        ps2_clk,
    input  logic        ps2_data,
    output logic [15:0] keyboard_value
);
    logic [2:0] ps2_clk_sync;
    logic [2:0] ps2_data_sync;
    logic [10:0] shift;
    logic [3:0] bit_count;
    logic       break_pending;
    logic       extended_pending;

    logic [7:0] scancode;
    logic       scancode_valid;

    function automatic logic [15:0] hack_keycode_from_scancode(
        input logic       is_extended,
        input logic [7:0] code
    );
        begin
            // PS2 Keycode --> Hack Keycode
            case ({is_extended, code})
                // Numbers row
                9'h045: hack_keycode_from_scancode = 16'd48;  // 0
                9'h016: hack_keycode_from_scancode = 16'd49;  // 1
                9'h01E: hack_keycode_from_scancode = 16'd50;  // 2
                9'h026: hack_keycode_from_scancode = 16'd51;  // 3
                9'h025: hack_keycode_from_scancode = 16'd52;  // 4
                9'h02E: hack_keycode_from_scancode = 16'd53;  // 5
                9'h036: hack_keycode_from_scancode = 16'd54;  // 6
                9'h03D: hack_keycode_from_scancode = 16'd55;  // 7
                9'h03E: hack_keycode_from_scancode = 16'd56;  // 8
                9'h046: hack_keycode_from_scancode = 16'd57;  // 9

                // Letters
                9'h01C: hack_keycode_from_scancode = 16'd97;  // a
                9'h032: hack_keycode_from_scancode = 16'd98;  // b
                9'h021: hack_keycode_from_scancode = 16'd99;  // c
                9'h023: hack_keycode_from_scancode = 16'd100; // d
                9'h024: hack_keycode_from_scancode = 16'd101; // e
                9'h02B: hack_keycode_from_scancode = 16'd102; // f
                9'h034: hack_keycode_from_scancode = 16'd103; // g
                9'h033: hack_keycode_from_scancode = 16'd104; // h
                9'h043: hack_keycode_from_scancode = 16'd105; // i
                9'h03B: hack_keycode_from_scancode = 16'd106; // j
                9'h042: hack_keycode_from_scancode = 16'd107; // k
                9'h04B: hack_keycode_from_scancode = 16'd108; // l
                9'h03A: hack_keycode_from_scancode = 16'd109; // m
                9'h031: hack_keycode_from_scancode = 16'd110; // n
                9'h044: hack_keycode_from_scancode = 16'd111; // o
                9'h04D: hack_keycode_from_scancode = 16'd112; // p
                9'h015: hack_keycode_from_scancode = 16'd113; // q
                9'h02D: hack_keycode_from_scancode = 16'd114; // r
                9'h01B: hack_keycode_from_scancode = 16'd115; // s
                9'h02C: hack_keycode_from_scancode = 16'd116; // t
                9'h03C: hack_keycode_from_scancode = 16'd117; // u
                9'h02A: hack_keycode_from_scancode = 16'd118; // v
                9'h01D: hack_keycode_from_scancode = 16'd119; // w
                9'h022: hack_keycode_from_scancode = 16'd120; // x
                9'h035: hack_keycode_from_scancode = 16'd121; // y
                9'h01A: hack_keycode_from_scancode = 16'd122; // z

                // Hack printable/control keys
                9'h029: hack_keycode_from_scancode = 16'd32;  // space
                9'h05A: hack_keycode_from_scancode = 16'd128; // enter
                9'h066: hack_keycode_from_scancode = 16'd129; // backspace
                9'h076: hack_keycode_from_scancode = 16'd140; // esc

                // Extended cursor keys
                9'h16B: hack_keycode_from_scancode = 16'd130; // left
                9'h175: hack_keycode_from_scancode = 16'd131; // up
                9'h174: hack_keycode_from_scancode = 16'd132; // right
                9'h172: hack_keycode_from_scancode = 16'd133; // down

                // Hack special keys (extended)
                9'h16C: hack_keycode_from_scancode = 16'd134; // home
                9'h169: hack_keycode_from_scancode = 16'd135; // end
                9'h17D: hack_keycode_from_scancode = 16'd136; // page up
                9'h17A: hack_keycode_from_scancode = 16'd137; // page down
                9'h170: hack_keycode_from_scancode = 16'd138; // insert
                9'h171: hack_keycode_from_scancode = 16'd139; // delete

                // Hack function keys
                9'h005: hack_keycode_from_scancode = 16'd141; // F1
                9'h006: hack_keycode_from_scancode = 16'd142; // F2
                9'h004: hack_keycode_from_scancode = 16'd143; // F3
                9'h00C: hack_keycode_from_scancode = 16'd144; // F4
                9'h003: hack_keycode_from_scancode = 16'd145; // F5
                9'h00B: hack_keycode_from_scancode = 16'd146; // F6
                9'h083: hack_keycode_from_scancode = 16'd147; // F7
                9'h00A: hack_keycode_from_scancode = 16'd148; // F8
                9'h001: hack_keycode_from_scancode = 16'd149; // F9
                9'h009: hack_keycode_from_scancode = 16'd150; // F10
                9'h078: hack_keycode_from_scancode = 16'd151; // F11
                9'h007: hack_keycode_from_scancode = 16'd152; // F12

                default: hack_keycode_from_scancode = 16'h0000;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ps2_clk_sync <= 3'b111;
            ps2_data_sync <= 3'b111;
            shift <= 11'd0;
            bit_count <= 4'd0;
            break_pending <= 1'b0;
            extended_pending <= 1'b0;
            scancode <= 8'h00;
            scancode_valid <= 1'b0;
            keyboard_value <= 16'h0000;
        end else begin
            logic fall_edge;
            logic [10:0] next_shift;

            ps2_clk_sync <= {ps2_clk_sync[1:0], ps2_clk};
            ps2_data_sync <= {ps2_data_sync[1:0], ps2_data};
            scancode_valid <= 1'b0;

            fall_edge = (ps2_clk_sync[2:1] == 2'b10);
            if (fall_edge) begin
                if (bit_count == 4'd0) begin
                    // Start bit must be 0.
                    if (!ps2_data_sync[2]) begin
                        bit_count <= 4'd1;
                        shift <= 11'd0;
                    end
                end else begin
                    next_shift = {ps2_data_sync[2], shift[10:1]};
                    shift <= next_shift;

                    if (bit_count == 4'd10) begin
                        bit_count <= 4'd0;

                        // Validate stop/parity before accepting scancode.
                        if (next_shift[10] && (^{next_shift[8:1], next_shift[9]} == 1'b1)) begin
                            scancode <= next_shift[8:1];
                            scancode_valid <= 1'b1;
                        end
                    end else begin
                        bit_count <= bit_count + 4'd1;
                    end
                end
            end

            if (scancode_valid) begin
                if (scancode == 8'hE0) begin
                    extended_pending <= 1'b1;
                end else if (scancode == 8'hF0) begin
                    break_pending <= 1'b1;
                end else begin
                    if (break_pending) begin
                        // On key release, clear current key for Hack keyboard register.
                        keyboard_value <= 16'h0000;
                        break_pending <= 1'b0;
                        extended_pending <= 1'b0;
                    end else begin
                        keyboard_value <= hack_keycode_from_scancode(extended_pending, scancode);
                        extended_pending <= 1'b0;
                    end
                end
            end
        end
    end
endmodule

`endif
