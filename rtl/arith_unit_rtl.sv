// ================================================================================================
// Module Name : prefix_operator
// Description : Used by the Han-Carlson tree to generate carry bits
// ================================================================================================

module prefix_operator (
    input  logic p_left,
    input  logic p_right,
    input  logic g_left,
    input  logic g_right,
    output logic p_out,
    output logic g_out
);
  assign p_out = p_left & p_right;
  assign g_out = g_left | (p_left & g_right);
endmodule

// ================================================================================================
// Module Name : carry_generator
// Description : Implement the Han-Carlson tree to generate carry bits
// ================================================================================================

module carry_generator (
    input logic [63:0] p,
    input logic [63:0] g,
    input logic c_in,
    output logic [64:1] c
);
  logic [7:0][63:0] lvl_p;
  logic [7:0][63:0] lvl_g;
  genvar i;
  generate
    // ==========================================
    // LEVEL 0: Map inputs to the structure
    // ==========================================
    for (i = 0; i < 64; i++) begin : L0_INPUTS
      assign lvl_p[0][i] = p[i];
      assign lvl_g[0][i] = g[i];
    end
    // ==========================================
    // LEVEL 1: 1,3,5,...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L1
      if (i % 2 == 1) begin : L1_OP
        prefix_operator op_l1 (
            .p_left (lvl_p[0][i]),
            .p_right(lvl_p[0][i-1]),
            .g_left (lvl_g[0][i]),
            .g_right(lvl_g[0][i-1]),
            .p_out  (lvl_p[1][i]),
            .g_out  (lvl_g[1][i])
        );
      end else begin : L1_PASS
        assign lvl_p[1][i] = lvl_p[0][i];
        assign lvl_g[1][i] = lvl_g[0][i];  // Pass-through
      end
    end

    // ==========================================
    // LEVEL 2: 3,5,7...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L2
      if (i >= 3 && i % 2 == 1) begin : L2_OP
        prefix_operator op_l2 (
            .p_left (lvl_p[1][i]),
            .p_right(lvl_p[1][i-2]),
            .g_left (lvl_g[1][i]),
            .g_right(lvl_g[1][i-2]),
            .p_out  (lvl_p[2][i]),
            .g_out  (lvl_g[2][i])
        );
      end else begin : L2_PASS
        assign lvl_p[2][i] = lvl_p[1][i];
        assign lvl_g[2][i] = lvl_g[1][i];  // Pass-through
      end
    end

    // ==========================================
    // LEVEL 3: 5,7,9...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L3
      if (i >= 5 && i % 2 == 1) begin : L3_OP
        prefix_operator op_l3 (
            .p_left (lvl_p[2][i]),
            .p_right(lvl_p[2][i-4]),
            .g_left (lvl_g[2][i]),
            .g_right(lvl_g[2][i-4]),
            .p_out  (lvl_p[3][i]),
            .g_out  (lvl_g[3][i])
        );
      end else begin : L3_PASS
        assign lvl_p[3][i] = lvl_p[2][i];
        assign lvl_g[3][i] = lvl_g[2][i];  // Pass-through
      end
    end

    // ==========================================
    // LEVEL 4: 9,11,13,...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L4
      if (i >= 9 && i % 2 == 1) begin : L4_OP
        prefix_operator op_l4 (
            .p_left (lvl_p[3][i]),
            .p_right(lvl_p[3][i-8]),
            .g_left (lvl_g[3][i]),
            .g_right(lvl_g[3][i-8]),
            .p_out  (lvl_p[4][i]),
            .g_out  (lvl_g[4][i])
        );
      end else begin : L4_PASS
        assign lvl_p[4][i] = lvl_p[3][i];
        assign lvl_g[4][i] = lvl_g[3][i];  // Pass-through
      end
    end

    // ==========================================
    // LEVEL 5: 17,19,21,...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L5
      if (i >= 17 && i % 2 == 1) begin : L5_OP
        prefix_operator op_l5 (
            .p_left (lvl_p[4][i]),
            .p_right(lvl_p[4][i-16]),
            .g_left (lvl_g[4][i]),
            .g_right(lvl_g[4][i-16]),
            .p_out  (lvl_p[5][i]),
            .g_out  (lvl_g[5][i])
        );
      end else begin : L5_PASS
        assign lvl_p[5][i] = lvl_p[4][i];
        assign lvl_g[5][i] = lvl_g[4][i];  // Pass-through
      end
    end
    // ==========================================
    // LEVEL 6: 33, 35,...63
    // ==========================================
    for (i = 0; i < 64; i++) begin : L6
      if (i >= 33 && i % 2 == 1) begin : L6_OP
        prefix_operator op_l6 (
            .p_left (lvl_p[5][i]),
            .p_right(lvl_p[5][i-32]),
            .g_left (lvl_g[5][i]),
            .g_right(lvl_g[5][i-32]),
            .p_out  (lvl_p[6][i]),
            .g_out  (lvl_g[6][i])
        );
      end else begin : L6_PASS
        assign lvl_p[6][i] = lvl_p[5][i];
        assign lvl_g[6][i] = lvl_g[5][i];  // Pass-through
      end
    end
    // ==========================================
    // LEVEL 7: 2,4,6,...30
    // ==========================================
    for (i = 0; i < 64; i++) begin : L7
      if (i >= 2 && i % 2 == 0) begin : L7_OP
        prefix_operator op_l7 (
            .p_left (lvl_p[6][i]),
            .p_right(lvl_p[6][i-1]),
            .g_left (lvl_g[6][i]),
            .g_right(lvl_g[6][i-1]),
            .p_out  (lvl_p[7][i]),
            .g_out  (lvl_g[7][i])
        );
      end else begin : L7_PASS
        assign lvl_p[7][i] = lvl_p[6][i];
        assign lvl_g[7][i] = lvl_g[6][i];  // Pass-through
      end
    end
  endgenerate

  generate
    for (i = 1; i <= 64; i++) begin : CARRY_MAP
      assign c[i] = lvl_g[7][i-1] | (lvl_p[7][i-1] & c_in);
    end
  endgenerate
endmodule

// ================================================================================================
// Module Name : arith_CLA
// Description : 1-bit Carry-Look-Ahead block
// ================================================================================================
module arith_CLA (
    input  logic op1,
    input  logic op2,
    input  logic c_in,
    output logic g,
    output logic p,
    output logic s
);
  always_comb begin
    p = op1 ^ op2;
    g = op1 & op2;
    s = c_in ^ p;
  end
endmodule
// ================================================================================================
// Module Name : arith_unit
// Description : Instantiate 64 CLA blocks and the Han-Carlson carry generation tree
//               sub_ctrl is set to 1 when the unit performs subtraction, otherwise, addition
// ================================================================================================
module arith_unit (
    input logic [63:0] op1,
    input logic [63:0] op2,
    input logic sub_ctrl,
    output logic [63:0] arith_result,
    output logic zero,
    output logic negative,
    output logic overflow,
    output logic carry_out
);
  logic [63:0] p, g;
  logic [64:0] c;
  logic [63:0] op2_xor;
  assign op2_xor = op2 ^ {64{sub_ctrl}};
  assign c[0] = sub_ctrl;
  genvar i;
  generate
    for (i = 0; i < 64; i++) begin : CLA_GEN
      arith_CLA CLA_BLOCK (
          .op1(op1[i]),
          .op2(op2_xor[i]),
          .c_in(c[i]),
          .g(g[i]),
          .p(p[i]),
          .s(arith_result[i])
      );
    end
  endgenerate

  carry_generator CARRY_GEN (
      .p(p),
      .g(g),
      .c_in(sub_ctrl),
      .c(c[64:1])
  );
  assign carry_out = c[32];
  always_comb begin : FLAG
    zero = ~(|arith_result[31:0]);
    negative = arith_result[31];
    overflow = (op1[31] == op2_xor[31]) & (arith_result[31] != op1[31]);
  end
endmodule

// ================================================================================================
// Module Name : HA
// Description : 1-bit half adder
// ================================================================================================
module HA (
    input  logic op1,
    input  logic op2,
    output logic sum,
    output logic c_out
);
  always_comb begin
    sum   = op1 ^ op2;
    c_out = op1 & op2;
  end
endmodule
// ================================================================================================
// Module Name : FA
// Description : 1-bit full adder
// ================================================================================================
module FA (
    input  logic op1,
    input  logic op2,
    input  logic c_in,
    output logic sum,
    output logic c_out
);
  logic ha2_c_out;
  logic ha1_c_out;
  logic ha1_sum;
  HA HA1 (
      .op1  (op1),
      .op2  (op2),
      .sum  (ha1_sum),
      .c_out(ha1_c_out)
  );

  HA HA2 (
      .op1  (c_in),
      .op2  (ha1_sum),
      .sum  (sum),
      .c_out(ha2_c_out)
  );
  assign c_out = ha1_c_out | ha2_c_out;
endmodule


