`timescale 1ns / 1ps
// ================================================================================================
// Module Name : alu_input_router
// Description : routes the correct inputs for the active functional unit inside the execution unit
//               performs operand isolation on other unactive units.
// ================================================================================================
module alu_input_router (
    // Top-Level Inputs
    input  logic [4:0]  alu_control,
    input  logic [31:0] op1,
    input  logic [31:0] op2,

    alu_ctrl_if.in_router_out     ctrl_bus,
    alu_operand_if.in_router_out  op_bus,
    mul_feedback_if.in_router_in  mul_fb_bus,
    div_feedback_if.in_router_in  div_fb_bus
);
    always_comb begin
    ctrl_bus.is_arith  = (alu_control == 5'b00000) || (alu_control == 5'b00001);
    ctrl_bus.is_logic  = (alu_control >= 5'b00101) && (alu_control <= 5'b00111);
    ctrl_bus.is_shift  = (alu_control >= 5'b00010) && (alu_control <= 5'b00100);
    ctrl_bus.is_cmp = (alu_control >= 5'b01000) && (alu_control <= 5'b01111);
    ctrl_bus.is_branch=(alu_control >= 5'b01010) && (alu_control <= 5'b01111);
    ctrl_bus.is_mul    = (alu_control >= 5'b10000) && (alu_control <= 5'b10011);
    ctrl_bus.is_div    = (alu_control >= 5'b10100) && (alu_control <= 5'b10111);
  end

  always_comb begin
    op_bus.arith_op1 = '0;
    op_bus.arith_op2 = '0;
    op_bus.sub_ctrl  = 1'b0;
    if (mul_fb_bus.mul_add_pp) begin
      op_bus.arith_op1 = mul_fb_bus.mul_pp_1;
      op_bus.arith_op2 = mul_fb_bus.mul_pp_2;
      op_bus.sub_ctrl  = 1'b0;
    end else if (div_fb_bus.div_final_cycle) begin
      op_bus.arith_op1 = div_fb_bus.div_arith_op1;
      op_bus.arith_op2 = div_fb_bus.div_arith_op2;
      op_bus.sub_ctrl  = 1'b0;
    end else if (div_fb_bus.div_2s) begin
      // Simultaneous Dual 32-bit 2's Complement
      // Lower 32 bits get their +1 from sub_ctrl.
      // Upper 32 bits get their +1 from the Carry Out (if op1 == 0), 
      // OR from this injected bit (if op1 != 0).
      op_bus.arith_op1 = {31'b0, (|div_fb_bus.div_arith_op1[31:0]), 32'b0};
      op_bus.arith_op2 = {div_fb_bus.div_arith_op2[31:0], div_fb_bus.div_arith_op1[31:0]};
      op_bus.sub_ctrl  = 1'b1;
    end else if (ctrl_bus.is_arith || ctrl_bus.is_cmp) begin
      op_bus.arith_op1 = {32'b0, op1};
      op_bus.arith_op2 = {32'b0, op2};
      op_bus.sub_ctrl  = (alu_control == 5'b00001) || ctrl_bus.is_cmp;
    end
  end

  always_comb begin
    op_bus.logic_op1  = ctrl_bus.is_logic ? op1 : '0;
    op_bus.logic_op2  = ctrl_bus.is_logic ? op2 : '0;
    op_bus.logic_type = alu_control[1:0];

    op_bus.mul_op1  = ctrl_bus.is_mul ? op1 : '0;
    op_bus.mul_op2  = ctrl_bus.is_mul ? op2 : '0;
    op_bus.mul_type = alu_control[1:0];

    op_bus.div_op1  = ctrl_bus.is_div ? op1 : '0;
    op_bus.div_op2  = ctrl_bus.is_div ? op2 : '0;
    op_bus.div_type = alu_control[1:0];

    op_bus.cmp_ctrl = ctrl_bus.is_cmp ? alu_control[2:0] : 3'b000;
  end

  always_comb begin
    op_bus.shift_op1  = '0;
    op_bus.shift_op2  = '0;
    op_bus.shift_type = 2'b00;

    if (div_fb_bus.div_shift_divisor) begin
      op_bus.shift_op1  = div_fb_bus.div_shift_op;
      op_bus.shift_op2  = div_fb_bus.div_shift_amount;
      op_bus.shift_type = 2'b10;
    end else if (div_fb_bus.div_shift_remainder) begin
      op_bus.shift_op1  = div_fb_bus.div_shift_op;
      op_bus.shift_op2  = div_fb_bus.div_shift_amount;
      op_bus.shift_type = 2'b11; 
    end else if (ctrl_bus.is_shift) begin
      op_bus.shift_op1  = op1;
      op_bus.shift_op2  = op2[4:0];
      op_bus.shift_type = alu_control[1:0];
    end
  end
endmodule

// ================================================================================================
// Module Name : alu_execution_unit
// Description : Instantiate the sub functional units
// ================================================================================================
module alu_execution_unit (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    output logic done,
    output logic idle,

    // Interfaces from Input Router
    alu_ctrl_if.exe_in       ctrl_bus,
    alu_operand_if.exe_in    op_bus,

    // Feedback Interfaces to Input Router
    mul_feedback_if.exe_out  mul_fb_bus,
    div_feedback_if.exe_out  div_fb_bus,

    // Interface to Output Router
    alu_result_if.exe_out    res_bus
);
    logic [63:0] internal_arith_result;
    logic [31:0] internal_shift_result;
    logic        mul_idle, mul_done;
    logic        div_idle, div_done;
    
    logic zero, negative, overflow, carry_out;
    logic start_mul, start_div;
    assign start_mul = start & ctrl_bus.is_mul;
    assign start_div = start & ctrl_bus.is_div;
    always_comb begin
      done = 1'b0;
      idle = 1'b1;
      
      if(ctrl_bus.is_arith || ctrl_bus.is_logic || ctrl_bus.is_shift || ctrl_bus.is_cmp || ctrl_bus.is_branch)begin
        done = 1'b1;
        idle = 1'b1;
      end
      else if(ctrl_bus.is_mul)begin
        done = mul_done;
        idle = mul_idle;
      end
      else if(ctrl_bus.is_div)begin
        done = div_done;
        idle = div_idle;
      end
    end

    always_comb begin
      res_bus.arith_result = internal_arith_result;
      res_bus.shift_result = internal_shift_result;
    end

    arith_unit ARITH_UNIT (
      .op1(op_bus.arith_op1),
      .op2(op_bus.arith_op2),
      .sub_ctrl(op_bus.sub_ctrl),
      .arith_result(internal_arith_result),
      .zero(zero),
      .negative(negative),
      .overflow(overflow),
      .carry_out(carry_out)
  );

    shifter_unit SHIFT_UNIT (
        .op1(op_bus.shift_op1),
        .op2(op_bus.shift_op2),
        .shift_type(op_bus.shift_type),
        .shift_result(internal_shift_result)
    );

    logic_unit LOGIC_UNIT (
          .op1(op_bus.logic_op1),
          .op2(op_bus.logic_op2),
          .logic_type(op_bus.logic_type),
          .logic_result(res_bus.logic_result)
    );

    branch_unit BRANCH_UNIT (
        .zero(zero),
        .negative(negative),
        .overflow(overflow),
        .carry_out(carry_out),
        .cmp_ctrl(op_bus.cmp_ctrl),
        .slt_result(res_bus.slt_result),
        .branch_take(res_bus.raw_branch_take)
    );

    mul_unit MUL_UNIT (
      .clk(clk),
      .rst_n(rst_n),
      .start_mul(start_mul),
      .mul_type(op_bus.mul_type),
      .op1(op_bus.mul_op1),
      .op2(op_bus.mul_op2),
      .arith_result(internal_arith_result),
      .mul_result(res_bus.mul_result),
      .mul_done(mul_done),
      .mul_idle(mul_idle),
      .mul_fb_bus(mul_fb_bus)
    );

    div_unit DIV_UNIT (
      .clk(clk),
      .rst_n(rst_n),
      .start_div(start_div),
      .div_type(op_bus.div_type),
      .op1(op_bus.div_op1),
      .op2(op_bus.div_op2),
      .arith_result(internal_arith_result),
      .shift_result(internal_shift_result),
      .div_fb_bus(div_fb_bus),
      .quotient(res_bus.div_quotient),
      .remainder(res_bus.div_remainder),
      .div_done(div_done),
      .div_idle(div_idle)
  );
endmodule
// ================================================================================================
// Module Name : alu_output_router
// Description : routes the correct alu_result and branch_take from the results of execution unit
// ================================================================================================
module alu_output_router (
    // Top-Level Inputs
    input logic [4:0] alu_control,
    // Interface Connections
    alu_ctrl_if.out_router_in   ctrl_bus,
    alu_result_if.out_router_in res_bus,

    // Top-Level Outputs
    output logic [31:0] alu_result,
    output logic        branch_take
);
    always_comb begin
    alu_result  = '0;
    branch_take = 1'b0;
    if (ctrl_bus.is_arith) begin
      alu_result = res_bus.arith_result[31:0];
    end else if (ctrl_bus.is_logic) begin
      alu_result = res_bus.logic_result;
    end else if (ctrl_bus.is_shift) begin
      alu_result = res_bus.shift_result;
    end else if (ctrl_bus.is_cmp) begin
      alu_result = res_bus.slt_result;
      if (ctrl_bus.is_branch) begin
        branch_take = res_bus.raw_branch_take;
      end
    end else if (ctrl_bus.is_mul) begin
      alu_result = (alu_control == 5'b10000) ? res_bus.mul_result[31:0] : res_bus.mul_result[63:32];
    end else if (ctrl_bus.is_div) begin
      alu_result = (alu_control[1]) ? res_bus.div_remainder : res_bus.div_quotient;
    end
  end
endmodule
// ================================================================================================
// Module Name : alu_32-bit_riscv
// Description : Top-level ALU module
// ================================================================================================
module alu_32bit_riscv (
    input logic clk,
    input logic rst_n,
    input logic start,
    input logic [4:0] alu_control,
    input logic [31:0] op1,
    input logic [31:0] op2,
    output logic [31:0] alu_result,
    output logic branch_take,
    output logic done,
    output logic idle
);
    alu_ctrl_if     ctrl_bus();
    alu_operand_if  op_bus();
    mul_feedback_if mul_fb_bus();
    div_feedback_if div_fb_bus();
    alu_result_if   res_bus();

      // Input Router
    alu_input_router INPUT_ROUTER (
        .alu_control(alu_control),
        .op1(op1),
        .op2(op2),
        .ctrl_bus(ctrl_bus),
        .op_bus(op_bus),
        .mul_fb_bus(mul_fb_bus),
        .div_fb_bus(div_fb_bus)
    );

    // Execution Unit
    alu_execution_unit EXECUTION_UNIT (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .idle(idle),
        
        .ctrl_bus(ctrl_bus),
        .op_bus(op_bus),
        .mul_fb_bus(mul_fb_bus),
        .div_fb_bus(div_fb_bus),
        .res_bus(res_bus)
    );

    // Output Router
    alu_output_router OUTPUT_ROUTER (
        .alu_control(alu_control),
        
        .ctrl_bus(ctrl_bus),
        .res_bus(res_bus),
        
        .alu_result(alu_result),
        .branch_take(branch_take)
    );
endmodule


