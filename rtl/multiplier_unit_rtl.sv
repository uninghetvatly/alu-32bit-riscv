// ================================================================================================
// Module Name : radix4_booth_encoder
// Description : Determine the partial product case (0, +A, +2A, -A, -2A) using Booth's radix 4
// ================================================================================================
`timescale 1ns / 1ps
module radix4_booth_encoder (
    input logic [2:0] x,
    output logic neg,
    output logic two,
    output logic zero
);
  assign neg  = (x == 3'b100) || (x == 3'b110) || (x == 3'b101); //Negative sign
  assign two  = (x == 3'b100) || (x == 3'b011); //Double
  assign zero = (x == 3'b000) || (x == 3'b111); //Zero
endmodule

// ================================================================================================
// Module Name : partial_product_gen
// Description : Generate the correct partial product using the case from radix4_booth_encoder
// ================================================================================================
module partial_product_gen (
    input logic [32:0] A,
    input logic neg,
    input logic zero,
    input logic two,
    output logic [33:0] pp
);
  logic [33:0] pos_pp;
  always_comb begin
    if (zero) begin
      pos_pp = 34'b0;
    end else if (two) begin
      pos_pp = {A, 1'b0};
    end else begin
      pos_pp = {A[32], A};
    end

    pp = neg ? ~pos_pp : pos_pp;
  end
endmodule

// ================================================================================================
// Module Name : mul_cycle1
// Description : Generate the paritial product matrix and perform dadda reduction up to stage 2
// ================================================================================================
module mul_cycle1 (
    input logic [32:0] op1,
    input logic [32:0] op2,
    output logic [8:0][63:0] pp_matrix_stage2
);
  logic [33:0] pp_raw[16:0];
  logic [17:0][65:0] pp_matrix;
  logic [16:0] zero, two, neg, s;  //sign bit for each row
  logic [34:0] op2_ext;  //used to check for the radix-4 case
  assign op2_ext = {op2[32], op2[32:0], 1'b0};

  genvar i;
  generate
    for (i = 0; i < 17; i++) begin : PPG_ARRAY
      radix4_booth_encoder ENCODER (
          .x(op2_ext[2*i+2:2*i]),
          .neg(neg[i]),
          .zero(zero[i]),
          .two(two[i])
      );

      partial_product_gen GENERATOR (
          .A(op1),
          .neg(neg[i]),
          .zero(zero[i]),
          .two(two[i]),
          .pp(pp_raw[i])
      );
    end
  endgenerate

  always_comb begin
    for (int k = 0; k < 17; k++) begin
      s[k] = pp_raw[k][33];
    end
    for (int r = 0; r < 18; r++) begin
      pp_matrix[r] = 66'b0;
    end

    pp_matrix[0][33:0]  = pp_raw[0];
    pp_matrix[0][36:34] = {~s[0], s[0], s[0]};

    for (int r = 1; r < 16; r++) begin
      pp_matrix[r][2*r+:34] = pp_raw[r];
      pp_matrix[r][(2*r+34)+:2] = {1'b1, ~s[r]};
      pp_matrix[r][2*r-2] = neg[r-1];
    end

    pp_matrix[16][65:32] = pp_raw[16];
    pp_matrix[16][30] = neg[15];
    pp_matrix[17][32] = neg[16];
  end

  //DADDA STAGE 1 + 2
  logic [17:0][63:0] pp_matrix_64;
  always_comb begin
    for (int i = 0; i < 18; i++) begin
      pp_matrix_64[i] = pp_matrix[i][63:0];
    end
  end
  dadda_tree_stage2 dadda_2 (
      .pp_matrix(pp_matrix_64),
      .pp_matrix_stage2(pp_matrix_stage2)
  );
endmodule

// ================================================================================================
// Module Name : mul_cycle2
// Description : Perform dadda reduction stage 3, 4, 5, 6
//               Calculate the two final partial products.
// ================================================================================================
module mul_cycle2 (
    input logic [8:0][63:0] pp_matrix_stage2,
    output logic [63:0] pp_1,
    output logic [63:0] pp_2
);
  dadda_tree_stage6 DADDA_CYCLE2 (
      .pp_matrix_stage2(pp_matrix_stage2),
      .final_sum(pp_1),
      .final_carry(pp_2)
  );
endmodule
// ================================================================================================
// Module Name : mul_unit
// Description : Split the execution path into 3 cycles using shift register structure
//               Cycle 1: Perform partial product generation and dadda stage 2
//               Cycle 2: Perform dadda stage 3,4,5,6
//               Cycle 3: Send request signal to arith_unit to calculate the final product
// ================================================================================================
module mul_unit (
    input logic clk,
    input logic rst_n,
    input logic start_mul,
    input logic [1:0] mul_type,
    input logic [31:0] op1,
    input logic [31:0] op2,
    input logic [63:0] arith_result,
    output logic [63:0] mul_result,
    output logic mul_done,
    output logic mul_idle,

    mul_feedback_if.exe_out  mul_fb_bus
);
  logic [32:0] op1_ext, op2_ext;
  assign op1_ext = mul_type[0] ? {op1[31], op1[31:0]} : {1'b0, op1[31:0]};
  assign op2_ext = (mul_type == 2'b01) ? {op2[31], op2[31:0]} : {1'b0, op2[31:0]};

  logic [8:0][63:0] pp_matrix_stage2;
  logic [63:0] cycle2_pp_1, cycle2_pp_2;
  logic [8:0][63:0] pipe_reg_matrix;
  logic [63:0] pipe_reg_pp_1;
  logic [63:0] pipe_reg_pp_2;
  logic [63:0] pipe_reg_mul_result;
  mul_cycle1 CYCLE_1_CORE (
      .op1(op1_ext),
      .op2(op2_ext),
      .pp_matrix_stage2(pp_matrix_stage2)
  );

  mul_cycle2 CYCLE_2_CORE (
      .pp_matrix_stage2(pipe_reg_matrix),
      .pp_1(cycle2_pp_1),
      .pp_2(cycle2_pp_2)
  );

  logic [2:0] mul_state;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_state <= 3'b000;
      pipe_reg_matrix <= '0;
      pipe_reg_pp_1 <= '0;
      pipe_reg_pp_2 <= '0;
      pipe_reg_mul_result <= '0;
    end else begin
      if (start_mul && mul_state == 3'b000) begin
        mul_state <= 3'b001;
      end else if (mul_state == 3'b001) begin
        mul_state <= 3'b010;
      end else if (mul_state == 3'b010) begin
        mul_state <= 3'b100;
      end else if (mul_state == 3'b100) begin
          mul_state <= 3'b000;
      end else begin
        mul_state <= 3'b000;
      end

      if (start_mul && mul_state == 3'b000) begin
        pipe_reg_matrix <= pp_matrix_stage2;
      end

      if (mul_state[0]) begin
        pipe_reg_pp_1 <= cycle2_pp_1;
        pipe_reg_pp_2 <= cycle2_pp_2;
      end

      if (mul_state[1]) begin
        pipe_reg_mul_result <= arith_result;
      end
    end
  end
  assign mul_done = mul_state[2];
  assign mul_idle = (mul_state == 3'b000);
  assign mul_fb_bus.mul_pp_1 = pipe_reg_pp_1;
  assign mul_fb_bus.mul_pp_2 = pipe_reg_pp_2;
  assign mul_fb_bus.mul_add_pp = (mul_state == 3'b010);
  assign mul_result = pipe_reg_mul_result;

endmodule
