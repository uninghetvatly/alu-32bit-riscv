// ================================================================================================
// Module Name : shifter_unit
// Description : a 32-bit right barrel shifter with right/left unification
// ================================================================================================
module shifter_unit (
    input  logic [31:0] op1,
    input  logic [ 4:0] op2,
    input  logic [ 1:0] shift_type,
    output logic [31:0] shift_result
);
  logic is_sl, ext_bit;
  logic [31:0] op1_reversed;
  logic [31:0] out_reversed;
  logic [31:0] stage5;
  logic [31:0] stage4;
  logic [31:0] stage3;
  logic [31:0] stage2;
  logic [31:0] stage1;
  logic [31:0] stage0;
  assign is_sl   = (shift_type == 2'b10);
  assign ext_bit = (shift_type == 2'b00) ? op1[31] : 1'b0;

  always_comb begin : BIT_REVERSE_IN
    for (int i = 0; i < 32; i++) begin
      op1_reversed[i] = op1[31-i];
    end
  end

  assign stage5 = is_sl ? op1_reversed : op1;
  assign stage4 = op2[4] ? {{16{ext_bit}}, stage5[31:16]} : stage5;
  assign stage3 = op2[3] ? {{8{ext_bit}}, stage4[31:8]} : stage4;
  assign stage2 = op2[2] ? {{4{ext_bit}}, stage3[31:4]} : stage3;
  assign stage1 = op2[1] ? {{2{ext_bit}}, stage2[31:2]} : stage2;
  assign stage0 = op2[0] ? {{1{ext_bit}}, stage1[31:1]} : stage1;

  always_comb begin : REVERSE_OUT
    for (int i = 0; i < 32; i++) begin
      out_reversed[i] = stage0[31-i];
    end
  end

  assign shift_result = is_sl ? out_reversed : stage0;
endmodule
