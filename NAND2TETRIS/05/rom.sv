`ifndef rom
`define rom 1

module rom #(
    parameter ROM_FILE = "rom/rom.hack",
    parameter bit USE_SPI_FLASH = 1'b0,
    parameter logic [23:0] SPI_FLASH_BASE_ADDR = 24'h200000
) (
    input  logic       clock,
    input  logic       rst_n,
    input  logic [14:0] address,
    output logic [15:0] out,
    output logic        ready,
    input  logic        spi_miso,
    output logic        spi_mosi,
    output logic        spi_sck,
    output logic        spi_cs_n
);
    generate
        if (!USE_SPI_FLASH) begin : g_file_rom
            // 32K x 16 ROM image loaded from a .hack file.
            logic [15:0] memory [0:(2**15)-1];

            initial begin
                $readmemb(ROM_FILE, memory);
            end

            assign out = memory[address];
            assign ready = 1'b1;
            assign spi_mosi = 1'b0;
            assign spi_sck = 1'b0;
            assign spi_cs_n = 1'b1;
        end else begin : g_spi_rom
            localparam logic [2:0] ST_IDLE    = 3'd0;
            localparam logic [2:0] ST_CMD     = 3'd1;
            localparam logic [2:0] ST_ADDR    = 3'd2;
            localparam logic [2:0] ST_DATA_HI = 3'd3;
            localparam logic [2:0] ST_DATA_LO = 3'd4;

            logic [2:0]  state;
            logic [5:0]  bit_count;
            logic [7:0]  shift_tx;
            logic [7:0]  shift_rx;
            logic [23:0] byte_addr;
            logic [14:0] latched_address;
            logic [15:0] out_reg;
            logic [7:0]  hi_byte;
            logic [1:0]  addr_byte_idx;

            assign out = out_reg;

            always_ff @(posedge clock or negedge rst_n) begin
                if (!rst_n) begin
                    state <= ST_IDLE;
                    bit_count <= 6'd0;
                    shift_tx <= 8'h00;
                    shift_rx <= 8'h00;
                    byte_addr <= 24'h0;
                    latched_address <= 15'h0;
                    out_reg <= 16'h0000;
                    hi_byte <= 8'h00;
                    addr_byte_idx <= 2'd0;
                    ready <= 1'b0;
                    spi_cs_n <= 1'b1;
                    spi_sck <= 1'b0;
                    spi_mosi <= 1'b0;
                end else begin
                    case (state)
                        ST_IDLE: begin
                            spi_cs_n <= 1'b1;
                            spi_sck <= 1'b0;
                            ready <= 1'b1;
                            if (address != latched_address) begin
                                latched_address <= address;
                                byte_addr <= SPI_FLASH_BASE_ADDR + {address, 1'b0};
                                shift_tx <= 8'h03; // READ command
                                bit_count <= 6'd7;
                                spi_cs_n <= 1'b0;
                                ready <= 1'b0;
                                state <= ST_CMD;
                            end
                        end

                        ST_CMD: begin
                            spi_sck <= ~spi_sck;
                            if (!spi_sck) begin
                                spi_mosi <= shift_tx[bit_count];
                            end else if (bit_count == 0) begin
                                shift_tx <= byte_addr[23:16];
                                addr_byte_idx <= 2'd0;
                                bit_count <= 6'd7;
                                state <= ST_ADDR;
                            end else begin
                                bit_count <= bit_count - 1'b1;
                            end
                        end

                        ST_ADDR: begin
                            spi_sck <= ~spi_sck;
                            if (!spi_sck) begin
                                spi_mosi <= shift_tx[bit_count];
                            end else if (bit_count == 0) begin
                                if (addr_byte_idx == 2'd0) begin
                                    shift_tx <= byte_addr[15:8];
                                    addr_byte_idx <= 2'd1;
                                    bit_count <= 6'd7;
                                end else if (addr_byte_idx == 2'd1) begin
                                    shift_tx <= byte_addr[7:0];
                                    addr_byte_idx <= 2'd2;
                                    bit_count <= 6'd7;
                                end else begin
                                    bit_count <= 6'd7;
                                    shift_rx <= 8'h00;
                                    state <= ST_DATA_HI;
                                end
                            end else begin
                                bit_count <= bit_count - 1'b1;
                            end
                        end

                        ST_DATA_HI: begin
                            spi_sck <= ~spi_sck;
                            if (spi_sck) begin
                                shift_rx[bit_count] <= spi_miso;
                                if (bit_count == 0) begin
                                    hi_byte <= {shift_rx[7:1], spi_miso};
                                    bit_count <= 6'd7;
                                    shift_rx <= 8'h00;
                                    state <= ST_DATA_LO;
                                end else begin
                                    bit_count <= bit_count - 1'b1;
                                end
                            end
                        end

                        ST_DATA_LO: begin
                            spi_sck <= ~spi_sck;
                            if (spi_sck) begin
                                shift_rx[bit_count] <= spi_miso;
                                if (bit_count == 0) begin
                                    out_reg <= {hi_byte, {shift_rx[7:1], spi_miso}};
                                    spi_cs_n <= 1'b1;
                                    spi_sck <= 1'b0;
                                    ready <= 1'b1;
                                    state <= ST_IDLE;
                                end else begin
                                    bit_count <= bit_count - 1'b1;
                                end
                            end
                        end

                        default: state <= ST_IDLE;
                    endcase
                end
            end
        end
    endgenerate
endmodule

`endif
