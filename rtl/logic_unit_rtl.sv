// ================================================================================================
// Module Name : logic_unit
// Description : Perform logical instruction: and, or, xor
// ================================================================================================
module logic_unit (
    input  logic [31:0] op1,
    input  logic [31:0] op2,
    input  logic [ 1:0] logic_type,
    output logic [31:0] logic_result
);
  always_comb begin : LOGIC_OPERATION
    case (logic_type)
      2'b01:   logic_result = op1 & op2;
      2'b10:   logic_result = op1 | op2;
      2'b11:   logic_result = op1 ^ op2;
      default: logic_result = 32'b0;
    endcase
  end
endmodule
