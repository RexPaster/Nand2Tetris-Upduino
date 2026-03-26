module ErrorCloseSimulator(
  input logic Error,
  output logic TryAgain
);
assign TryAgain = Error;
endmodule

module top(
  input logic Error,
  output logic TryAgain
);

ErrorCloseSimulator AndTryAgain$(
  .Error(Error),
  .TryAgain(TryAgain)
)

endmodule
