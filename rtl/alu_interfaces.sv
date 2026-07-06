interface alu_ctrl_if; 
    logic       is_arith;
    logic       is_logic;
    logic       is_shift;
    logic       is_cmp;
    logic       is_branch;
    logic       is_mul;
    logic       is_div;

    modport in_router_out (output is_arith, is_logic, is_shift, is_cmp, is_branch, is_mul, is_div);
    modport exe_in    (input  is_arith, is_logic, is_shift, is_cmp, is_branch, is_mul, is_div);
    modport out_router_in  (input  is_arith, is_logic, is_shift, is_cmp, is_branch, is_mul, is_div);
endinterface

interface alu_operand_if;
    // Shared Arithmetic
    logic [63:0] arith_op1, arith_op2;
    logic        sub_ctrl;
    // Shared Shifter
    logic [31:0] shift_op1;
    logic [4:0]  shift_op2;
    logic [1:0]  shift_type;
    // Logic Unit
    logic [31:0] logic_op1, logic_op2;
    logic [1:0]  logic_type;
    // Mul/Div/Branch Units
    logic [31:0] mul_op1, mul_op2;
    logic [1:0]  mul_type;
    logic [31:0] div_op1, div_op2;
    logic [1:0]  div_type;
    logic [2:0]  cmp_ctrl;

    modport in_router_out (
        output arith_op1, arith_op2, sub_ctrl,
               shift_op1, shift_op2, shift_type,
               logic_op1, logic_op2, logic_type,
               mul_op1, mul_op2, mul_type,
               div_op1, div_op2, div_type,
               cmp_ctrl
    );
    modport exe_in (
        input  arith_op1, arith_op2, sub_ctrl,
               shift_op1, shift_op2, shift_type,
               logic_op1, logic_op2, logic_type,
               mul_op1, mul_op2, mul_type,
               div_op1, div_op2, div_type,
               cmp_ctrl
    );
endinterface

interface mul_feedback_if;
    logic        mul_add_pp;
    logic [63:0] mul_pp_1;
    logic [63:0] mul_pp_2;

    modport exe_out       (output mul_add_pp, mul_pp_1, mul_pp_2);
    modport in_router_in  (input  mul_add_pp, mul_pp_1, mul_pp_2);
endinterface

interface div_feedback_if;
    logic        div_2s;
    logic        div_shift_divisor;
    logic        div_shift_remainder;
    logic        div_final_cycle;
    logic [4:0]  div_shift_amount;
    logic [63:0] div_arith_op1, div_arith_op2;
    logic [31:0] div_shift_op;

    modport exe_out       (
        output div_2s, div_shift_divisor, div_shift_remainder, div_final_cycle, 
               div_shift_amount, div_arith_op1, div_arith_op2, div_shift_op
    );
    modport in_router_in  (
        input  div_2s, div_shift_divisor, div_shift_remainder, div_final_cycle, 
               div_shift_amount, div_arith_op1, div_arith_op2, div_shift_op
    );
endinterface

interface alu_result_if;
    // Combinational Results
    logic [63:0] arith_result;
    logic [31:0] shift_result;
    logic [31:0] logic_result;
    logic [31:0] slt_result;
    logic        raw_branch_take;

    // Multiplier Results & State
    logic [63:0] mul_result;
    // Divider Results & State
    logic [31:0] div_quotient;
    logic [31:0] div_remainder;

    modport exe_out (
        output arith_result, shift_result, logic_result, slt_result, raw_branch_take,
               mul_result,
               div_quotient, div_remainder
    );
    modport out_router_in (
        input  arith_result, shift_result, logic_result, slt_result, raw_branch_take,
               mul_result,
               div_quotient, div_remainder
    );
    
endinterface