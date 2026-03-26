`ifndef ram_16K_spram
`define ram_16K_spram 1

module ram_16K_spram(
    input  [15:0] in,
    input  [13:0] address,
    input         load,
    input         clock,
    output [15:0] out
);
`ifdef SYNTHESIS
    wire [15:0] data_out;

    SB_SPRAM256KA u_spram (
        .ADDRESS(address),
        .DATAIN(in),
        .MASKWREN(4'b0000),
        .WREN(load),
        .CHIPSELECT(1'b1),
        .CLOCK(clock),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data_out)
    );

    assign out = data_out;
`else
    reg [15:0] memory [0:(2**14)-1];

    assign out = memory[address];

    always @(posedge clock) begin
        if (load) memory[address] <= in;
    end
`endif

endmodule

`endif
