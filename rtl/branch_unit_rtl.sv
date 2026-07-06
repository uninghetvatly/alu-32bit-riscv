// ================================================================================================
// Module Name : branch_unit
// Description : Receives flags from arith_unit subtraction operation
//               Determine whether a comparison or branch instruction evaluates to true
// ================================================================================================
module branch_unit (
    input logic zero,
    input logic negative,
    input logic overflow,
    input logic carry_out,
    input logic [2:0] cmp_ctrl,
    output logic [31:0] slt_result,
    output logic branch_take
);
  logic is_less_signed, is_less_unsigned;
  assign is_less_signed   = negative ^ overflow;
  assign is_less_unsigned = ~carry_out;

  always_comb begin : SLT_LOGIC
    case (cmp_ctrl)
      3'b000:  slt_result = {31'b0, is_less_signed};
      3'b001:  slt_result = {31'b0, is_less_unsigned};
      default: slt_result = 32'b0;
    endcase
  end

  always_comb begin : BRANCH_LOGIC
    case (cmp_ctrl)
      3'b000, 3'b001: branch_take = 1'b0;
      3'b010: branch_take = zero;
      3'b011: branch_take = ~zero;
      3'b100: branch_take = is_less_signed;
      3'b101: branch_take = ~is_less_signed;
      3'b110: branch_take = is_less_unsigned;
      3'b111: branch_take = ~is_less_unsigned;
      default: branch_take = 1'b0;
    endcase
  end
endmodule
