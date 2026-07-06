// ================================================================================================
// Module Name : lzc_32
// Description : Count the number of leading zeros of a 32-bit input. 
//               all_zeros flag is 1 if the input is 0
//               This module is used to calculate the shift amount to normalize divisor/dividend
// ================================================================================================
module lzc_32 (
    input logic [31:0] in,
    output logic [5:0] count,
    output logic all_zeros
);
  lzc_tree #(
      .WIDTH(32)
  ) LZC_32_TREE (
      .in(in),
      .count(count),
      .all_zeros(all_zeros)
  );
endmodule

module lzc_tree #(
    parameter int WIDTH = 32
) (
    input logic [WIDTH-1:0] in,
    output logic [$clog2(WIDTH):0] count,
    output logic all_zeros
);
  generate
    if (WIDTH == 2) begin : gen_base
      // ---------------------------------------------------------
      // BASE CASE: Level 0 (2-bit block)
      // ---------------------------------------------------------
      always_comb begin
        case (in)
          2'b11: begin
            count = 'd0;
            all_zeros = 1'b0;
          end
          2'b10: begin
            count = 'd0;
            all_zeros = 1'b0;
          end
          2'b01: begin
            count = 'd1;
            all_zeros = 1'b0;
          end
          2'b00: begin
            count = 'd2;
            all_zeros = 1'b1;
          end
          default: begin
            count = 'd0;
            all_zeros = 1'b0;
          end
        endcase
      end

    end else begin : gen_tree
      // ---------------------------------------------------------
      // RECURSIVE CASE: Split and Merge
      // ---------------------------------------------------------
      localparam HALF_W = WIDTH / 2;
      localparam OUT_W = $clog2(WIDTH) + 1;
      // Internal wires for the outputs of the left and right children
      logic [$clog2(HALF_W):0] count_left, count_right;
      logic all_zeros_left, all_zeros_right;

      // Instantiate Left Half (Upper bits: MSB down to middle)
      lzc_tree #(
          .WIDTH(HALF_W)
      ) left_node (
          .in(in[WIDTH-1 : HALF_W]),
          .count(count_left),
          .all_zeros(all_zeros_left)
      );

      // Instantiate Right Half (Lower bits: middle down to LSB)
      lzc_tree #(
          .WIDTH(HALF_W)
      ) right_node (
          .in(in[HALF_W-1 : 0]),
          .count(count_right),
          .all_zeros(all_zeros_right)
      );

      // Merge Logic
      always_comb begin
        all_zeros = all_zeros_left & all_zeros_right;
        if (~all_zeros_left) begin
          count = OUT_W'(count_left);
        end else begin
          count = OUT_W'(HALF_W) + OUT_W'(count_right);
        end
      end
    end
  endgenerate
endmodule

// ================================================================================================
// Module Name : otfc
// Description : Receive the estimated quotient bit from LUT and calculate the next Q, QM 
// ================================================================================================
module otfc (
    input  logic [31:0] q,
    input  logic [31:0] qm,
    input  logic [ 2:0] qi,
    output logic [31:0] q_next,
    qm_next
);
  always_comb begin
    q_next[31:2]  = qi[2] ? qm[29:0] : q[29:0];
    qm_next[31:2] = (~qi[2] && (qi[1] | qi[0])) ? q[29:0] : qm[29:0];
    case (qi)
      3'b010: begin
        q_next[1:0]  = 2'b10;
        qm_next[1:0] = 2'b01;
      end
      3'b001: begin
        q_next[1:0]  = 2'b01;
        qm_next[1:0] = 2'b00;
      end
      3'b000: begin
        q_next[1:0]  = 2'b00;
        qm_next[1:0] = 2'b11;
      end
      3'b101: begin
        q_next[1:0]  = 2'b11;
        qm_next[1:0] = 2'b10;
      end
      3'b110: begin
        q_next[1:0]  = 2'b10;
        qm_next[1:0] = 2'b01;
      end
      default: begin
        q_next[1:0]  = 2'b10;
        qm_next[1:0] = 2'b01;
      end
    endcase
  end
endmodule

// ================================================================================================
// Module Name : lut
// Description : Receive the three bits [30:28] from the normalized divisor
//               And 7-bit sum of remainder sum and remainder carry
//               Calculate the estimated qotient bit using a Look Up Table
// ================================================================================================
module lut (
    input logic [2:0] d_trunc,
    input logic signed [6:0] r_est,
    output logic [2:0] qi
);
  always_comb begin
    case (d_trunc)
      3'b000: begin
        if (r_est >= 7'sd12) qi = 3'b010;
        else if (r_est >= 7'sd4) qi = 3'b001;
        else if (r_est >= -7'sd4) qi = 3'b000;
        else if (r_est >= -7'sd13) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b001: begin
        if (r_est >= 7'sd14) qi = 3'b010;
        else if (r_est >= 7'sd4) qi = 3'b001;
        else if (r_est >= -7'sd5) qi = 3'b000;
        else if (r_est >= -7'sd15) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b010: begin
        if (r_est >= 7'sd15) qi = 3'b010;
        else if (r_est >= 7'sd4) qi = 3'b001;
        else if (r_est >= -7'sd5) qi = 3'b000;
        else if (r_est >= -7'sd16) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b011: begin
        if (r_est >= 7'sd16) qi = 3'b010;
        else if (r_est >= 7'sd4) qi = 3'b001;
        else if (r_est >= -7'sd5) qi = 3'b000;
        else if (r_est >= -7'sd17) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b100: begin
        if (r_est >= 7'sd18) qi = 3'b010;
        else if (r_est >= 7'sd6) qi = 3'b001;
        else if (r_est >= -7'sd6) qi = 3'b000;
        else if (r_est >= -7'sd19) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b101: begin
        if (r_est >= 7'sd20) qi = 3'b010;
        else if (r_est >= 7'sd6) qi = 3'b001;
        else if (r_est >= -7'sd6) qi = 3'b000;
        else if (r_est >= -7'sd21) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b110: begin
        if (r_est >= 7'sd20) qi = 3'b010;
        else if (r_est >= 7'sd8) qi = 3'b001;
        else if (r_est >= -7'sd8) qi = 3'b000;
        else if (r_est >= -7'sd21) qi = 3'b101;
        else qi = 3'b110;
      end

      3'b111: begin
        if (r_est >= 7'sd22) qi = 3'b010;
        else if (r_est >= 7'sd8) qi = 3'b001;
        else if (r_est >= -7'sd8) qi = 3'b000;
        else if (r_est >= -7'sd23) qi = 3'b101;
        else qi = 3'b110;
      end
      default: qi = 3'b000;
    endcase
  end
endmodule

// ================================================================================================
// Module Name : shifter_32_to_64_left
// Description : Treat 32-bit variable as 64-bit and shift left
//               This module is used to normalize the dividend
// ================================================================================================
module shifter_32_to_64_left (
    input  logic [31:0] in,
    input  logic [ 4:0] shift_amount,
    output logic [63:0] out
);
  logic [63:0] stage_16;
  logic [63:0] stage_8;
  logic [63:0] stage_4;
  logic [63:0] stage_2;
  logic [63:0] stage_1;

  // Step 0: Pad the 32-bit input to 64 bits
  logic [63:0] data_padded;
  assign data_padded = {32'b0, in};

  always_comb begin
    // Stage 4: Shift by 16 if shift_amount[4] is 1
    if (shift_amount[4]) stage_16 = {data_padded[47:0], 16'b0};
    else stage_16 = data_padded;

    // Stage 3: Shift by 8 if shift_amt[3] is 1
    if (shift_amount[3]) stage_8 = {stage_16[55:0], 8'b0};
    else stage_8 = stage_16;

    // Stage 2: Shift by 4 if shift_amt[2] is 1
    if (shift_amount[2]) stage_4 = {stage_8[59:0], 4'b0};
    else stage_4 = stage_8;

    // Stage 1: Shift by 2 if shift_amt[1] is 1
    if (shift_amount[1]) stage_2 = {stage_4[61:0], 2'b0};
    else stage_2 = stage_4;

    // Stage 0: Shift by 1 if shift_amt[0] is 1
    if (shift_amount[0]) stage_1 = {stage_2[62:0], 1'b0};
    else stage_1 = stage_2;
  end

  assign out = stage_1;

endmodule

// ================================================================================================
// Module Name : srt_radix4_core
// Description : Execution unit for the SRT LOOP state
//               This module instantiates the LUT to estimate the quotient bit
//               The quotient bit is fed to the OTFC unit to generate Q, Qm
//               The module then updates its regs with the new Q, QM
//               A 34-bit CSA is used to accumulate partial remainder
// ================================================================================================
module srt_radix4_core (
    input logic clk,
    input logic rst_n,
    // --- Control Signals ---
    input logic init_en,  // High on Cycle 0 to initialize registers
    input logic loop_en,  // High for the 16 iterations
    // --- Data Inputs ---
    input  logic [31:0] dividend_upper,
    input  logic [31:0] divisor_norm,
    input  logic [33:0] dividend_lower,
    // --- Outputs ---
    output logic [35:0] rem_sum,
    output logic [35:0] rem_carry,
    output logic [31:0] divisor_norm_out,
    output logic [31:0] q,
    output logic [31:0] qm
);
  logic [ 2:0] qi;
  logic [31:0] q_next, qm_next;
  logic [31:0] divisor_norm_reg;
  logic [33:0] dividend_lower_reg, dividend_lower_nxt;
  logic [35:0]
      rem_sum_reg,
      rem_carry_reg,
      rem_sum_nxt,
      rem_carry_nxt,
      shift_sum,
      shift_carry,
      shift_carry_update,
      csa_op,
      csa_carry;
  logic [6:0] r_est;
  assign divisor_norm_out = divisor_norm_reg;
  // =========================================================================
  // Registers Initialization and Updates
  // =========================================================================
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rem_sum_reg <= '0;
      rem_carry_reg <= '0;
      divisor_norm_reg <= '0;
      dividend_lower_reg <= '0;
      q <= '0;
      qm <= '0;
    end else if (init_en) begin
      rem_sum_reg <= {4'b0000, dividend_upper};
      rem_carry_reg <= '0;
      divisor_norm_reg <= divisor_norm;
      dividend_lower_reg <= dividend_lower;
      q  <= '0;
      qm <= '0;
    end else if (loop_en) begin
      rem_sum_reg <= rem_sum_nxt;
      rem_carry_reg <= rem_carry_nxt;
      dividend_lower_reg <= dividend_lower_nxt;
      q  <= q_next;
      qm <= qm_next;
    end 
  end

  // =========================================================================
  // SHIFT 2 bits, ADD 7MSB, ESTIMATE QUOTIENT BIT USING LUT
  // =========================================================================
  assign shift_sum = {rem_sum_reg[33:0], dividend_lower_reg[33:32]};
  assign shift_carry = {rem_carry_reg[33:0], 2'b00};
  assign r_est = $signed(shift_sum[34:28]) + $signed(shift_carry[34:28]);
  assign dividend_lower_nxt = {dividend_lower_reg[31:0], 2'b00};
  lut LUT_UNIT (
      .d_trunc(divisor_norm_reg[30:28]),
      .r_est(r_est),
      .qi(qi)
  );

  // =========================================================================
  // SELECT RIGHT OPERAND FOR CSA
  // =========================================================================
  always_comb begin
    case (qi)
      3'b010:  csa_op = ~{3'b000, divisor_norm_reg, 1'b0};  // Subtract 2D
      3'b001:  csa_op = ~{4'b0000, divisor_norm_reg};  // Subtract 1D
      3'b000:  csa_op = '0;  // 0
      3'b101:  csa_op = {4'b0000, divisor_norm_reg};  // Add 1D
      3'b110:  csa_op = {3'b000, divisor_norm_reg, 1'b0};  // Add 2D
      default: csa_op = '0;
    endcase
  end

  logic csa_add_1;
  assign csa_add_1 = (qi == 3'b001) || (qi == 3'b010);
  assign shift_carry_update = {shift_carry[35:1], csa_add_1};
  // =========================================================================
  // 34bit CSA
  // =========================================================================
  assign rem_sum_nxt = shift_sum ^ shift_carry_update ^ csa_op;
  assign csa_carry= (shift_sum & shift_carry_update) |
                          (shift_carry_update & csa_op) |
                          (shift_sum & csa_op);
  // =========================================================================
  // OTFC core to calculate Q and QM
  // =========================================================================
  otfc OTFC_CORE (
      .q(q),
      .qm(qm),
      .qi(qi),
      .q_next(q_next),
      .qm_next(qm_next)
  );

  assign rem_carry_nxt = {csa_carry[34:0], 1'b0};
  assign rem_sum = rem_sum_reg;
  assign rem_carry = rem_carry_reg;
endmodule



// ================================================================================================
// Module Name : div_fsm
// Description : Controller for the divider unit. 
//               Receive status signals from the datapath and output control signals
// ================================================================================================
module div_fsm (
    input logic clk,
    input logic rst_n,
    input logic start_div,
    input logic [1:0] div_type,
    input logic op1_sign,
    input logic op2_sign,  
    input logic div_by_zero, 
    input logic arith_result_sign, 
    output logic div_2s,
    output logic div_shift_divisor,
    output logic div_final_cycle,
    output logic div_shift_remainder,
    output logic init_en,
    output logic loop_en,
    output logic swap_q_qm,  //1=select QM(overshoot), 0=select Q
    output logic [1:0] arith_op1_sel,  //0: rem_sum, 1: arith_result, 2: final Q/R
    output logic [1:0] arith_op2_sel,  //0: rem_carry, 1: divisor_norm
    output logic save_2s_ops, 
    output logic save_2s_q_rem,
    output logic save_remainder,
    output logic div_done,
    output logic div_idle
);
  typedef enum logic [3:0] {
    IDLE,
    PRE_PROCESS,
    NORMALIZE,
    SRT_LOOP,
    MERGE_REMAINDER,
    CHECK_OVERSHOOT,
    DENORMALIZE,
    SIGN_FIX,
    DONE
  } state_t;
  state_t current_state, next_state;
  logic [4:0] counter;
  logic is_signed, overshoot;
  assign is_signed = ~div_type[0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start_div) begin
          if (is_signed && (op1_sign || op2_sign)) begin
            next_state = PRE_PROCESS;
          end else begin
            next_state = NORMALIZE;
          end
        end
      end

      PRE_PROCESS: next_state = NORMALIZE;
      NORMALIZE: begin
        if (div_by_zero) begin
          next_state = DONE;
        end else begin
          next_state = SRT_LOOP;
        end
      end
      SRT_LOOP: begin
        next_state = SRT_LOOP;
        if (counter == 5'd17) begin
          next_state = MERGE_REMAINDER;
        end
      end

      MERGE_REMAINDER: next_state = CHECK_OVERSHOOT;
      CHECK_OVERSHOOT: next_state = DENORMALIZE;
      DENORMALIZE: begin
        if (is_signed && (op1_sign || op2_sign)) begin
          next_state = SIGN_FIX;
        end else begin
          next_state = DONE;
        end
      end
      SIGN_FIX: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_comb begin
    div_2s = 1'b0;
    div_shift_divisor = 1'b0;
    div_final_cycle = 1'b0;
    div_shift_remainder = 1'b0;
    init_en = 1'b0;
    loop_en = 1'b0;
    swap_q_qm = overshoot;
    arith_op1_sel = 2'b00;
    arith_op2_sel = 2'b00;
    save_2s_ops = 1'b0;
    save_2s_q_rem = 1'b0;
    save_remainder = 1'b0;
    div_done = 1'b0;
    div_idle = 1'b0;
    case (current_state)
      IDLE: div_idle=1'b1;
      PRE_PROCESS: begin
        div_2s        = 1'b1;
        arith_op1_sel = 2'b11;
        arith_op2_sel = 2'b11;
        save_2s_ops   = 1'b1;
      end

      NORMALIZE: begin
        div_shift_divisor = 1'b1;
        init_en           = 1'b1;
      end

      SRT_LOOP: begin
        loop_en = (counter==5'd17) ?1'b0:1'b1;
      end

      MERGE_REMAINDER: begin
        div_final_cycle = 1'b1;
        arith_op1_sel   = 2'b00;
        arith_op2_sel   = 2'b00;
        save_remainder  = 1'b1;
      end

      CHECK_OVERSHOOT: begin
        if (overshoot) begin
          div_final_cycle = 1'b1;
          arith_op1_sel   = 2'b01;
          arith_op2_sel   = 2'b01;
          save_remainder  = 1'b1;
        end
      end

      DENORMALIZE: begin
        div_shift_remainder = 1'b1;
      end

      SIGN_FIX: begin
        div_2s        = 1'b1;
        arith_op1_sel = 2'b10;
        arith_op2_sel = 2'b10;
        save_2s_q_rem = 1'b1;
      end

      DONE: begin
        div_done = 1'b1;
      end

      default:begin end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter   <= '0;
      overshoot <= 1'b0;
    end else begin
      if (current_state == NORMALIZE) begin
        counter <= '0;
      end else if (current_state == SRT_LOOP) begin
        counter <= counter + 1'b1;
      end
      if (current_state == MERGE_REMAINDER) begin
        overshoot <= arith_result_sign;
      end
    end
  end
endmodule

// ================================================================================================
// Module Name : div_datapath
// Description : Datapath for the divider unit. 
//               Receive control signals from the controller and output status signals.
// ================================================================================================
module div_datapath (
    input  logic        clk,
    input  logic rst_n,
    input  logic start_div,
    input  logic [ 1:0] div_type,
    input  logic [31:0] op1,
    input  logic [31:0] op2,
    //Shared resource inputs
    input  logic [63:0] arith_result,
    input  logic [31:0] shift_result,
    //Control signals
    input  logic        div_idle,
    input  logic        init_en,
    input  logic        loop_en,
    input  logic        swap_q_qm,
    input  logic [ 1:0] arith_op1_sel,
    input  logic [ 1:0] arith_op2_sel,
    input  logic        save_2s_ops,
    input  logic        save_remainder,
    input  logic        div_shift_divisor,
    input  logic        div_shift_remainder,
    input  logic        div_2s,
    input  logic        save_2s_q_rem,
    // Status Signals
    output logic        op1_sign,
    output logic        op2_sign,
    output logic        div_by_zero,
    output logic        arith_result_sign,
    // Shared Resource Outputs
    output logic [ 4:0] div_shift_amount,
    output logic [63:0] div_arith_op1,
    output logic [63:0] div_arith_op2,
    output logic [31:0] div_shift_op,

    // Final Results
    output logic [31:0] quotient,
    output logic [31:0] remainder
);
  // =========================================================================
  // Datapath Registers
  // =========================================================================
  logic [31:0] op1_reg, op2_reg;
  logic [31:0] op1_2s_reg, op2_2s_reg;
  logic [35:0] rem_reg;
  logic [31:0] rem_denorm_reg;
  logic [31:0] quotient_2s_reg, rem_2s_reg;

  logic is_signed;
  assign is_signed = ~div_type[0];
  assign op1_sign = op1[31];
  assign op2_sign = op2[31];
  assign arith_result_sign = arith_result[35];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      op1_reg <= '0;
      op2_reg <= '0;
      op1_2s_reg <= '0;
      op2_2s_reg <= '0;
      rem_reg <= '0;
      rem_denorm_reg <= '0;
      quotient_2s_reg <= '0;
      rem_2s_reg <= '0;
    end else begin
      if (start_div && div_idle) begin
        op1_reg <= op1;
        op2_reg <= op2;
      end
      if (save_2s_ops) begin
        op1_2s_reg <= arith_result[31:0];
        op2_2s_reg <= arith_result[63:32];
      end
      if (save_remainder) begin
        // If overshoot (swap_q_qm = 1), the true remainder is the arith_result (+D fixed)
        // Otherwise, it was the original arith_result (A_sum + A_carry)
        rem_reg <= arith_result[35:0];
      end
      if (div_shift_remainder) begin
        rem_denorm_reg <= shift_result;
      end
      if (save_2s_q_rem) begin
        // Grab the dual 2's comp results from arith_unit
        quotient_2s_reg <= arith_result[31:0];
        rem_2s_reg <= arith_result[63:32];
      end
    end
  end

  logic [31:0] div_op1_abs, div_op2_abs;
  assign div_op1_abs = (is_signed && op1_reg[31]) ? op1_2s_reg : op1_reg;
  assign div_op2_abs = (is_signed && op2_reg[31]) ? op2_2s_reg : op2_reg;
  // =========================================================================
  // Leading Zero Counter (LZC)
  // =========================================================================
  logic [5:0] lzc_count;
  lzc_32 LZC_32BIT (
      .in(div_op2_abs),
      .count(lzc_count),
      .all_zeros(div_by_zero)
  );
  assign div_shift_amount = lzc_count[4:0];

  logic [63:0] dividend_64;
  logic [31:0] dividend_upper;
  logic [33:0] dividend_lower;
  logic [65:0] dividend_66;
  // =========================================================================
  // Internal shifter to normalize the dividend
  // =========================================================================
  shifter_32_to_64_left DIVIDEND_SHIFTER (
      .in   (div_op1_abs),
      .shift_amount (div_shift_amount),
      .out  (dividend_64)
  );

  assign dividend_66    = {2'b00, dividend_64};
  assign dividend_upper = dividend_66[65:34];
  assign dividend_lower = dividend_66[33:0];

  // =========================================================================
  // SRT Radix-4 Core
  // =========================================================================
  logic [35:0] rem_sum, rem_carry;
  logic [31:0] divisor_norm_out;
  logic [31:0] q, qm;
  srt_radix4_core SRT_CORE (
      .clk(clk),
      .rst_n(rst_n),
      .init_en(init_en),
      .loop_en(loop_en),
      .dividend_upper(dividend_upper),
      .dividend_lower(dividend_lower),
      .divisor_norm(shift_result),
      .rem_sum(rem_sum),
      .rem_carry(rem_carry),
      .divisor_norm_out(divisor_norm_out),
      .q(q),
      .qm(qm)
  );

  // =========================================================================
  // Determine operands for shared resource: arith_unit and shifter_unit
  // =========================================================================
  logic [31:0] raw_quotient;
  assign raw_quotient = swap_q_qm ? qm : q;
  always_comb begin
    div_shift_op = '0;
    if (div_shift_divisor) begin
      div_shift_op = div_op2_abs; // Route divisor to be normalized
    end else if (div_shift_remainder) begin
      div_shift_op = rem_reg[31:0]; //Route remainder to be denormalized
    end
  end

  always_comb begin
    div_arith_op1 = '0;
    div_arith_op2 = '0;
    case (arith_op1_sel)
      2'b00: begin // MERGE_REMAINDER
        div_arith_op1 = {28'b0, rem_sum};  
        div_arith_op2 = {28'b0, rem_carry};
      end
      2'b01: begin // FIX_OVERSHOOT
        div_arith_op1 = {28'b0, rem_reg};  
        div_arith_op2 = {32'b0, divisor_norm_out}; 
      end
      2'b10: begin // SIGN_FIX
        div_arith_op1 = {32'b0, raw_quotient};  
        div_arith_op2 = {32'b0, rem_denorm_reg};
      end 
      2'b11: begin // PRE_PROCESS
        div_arith_op1 = {32'b0, op1_reg};  
        div_arith_op2 = {32'b0, op2_reg};
      end
      default: begin
        div_arith_op1 = '0;
        div_arith_op2 = '0;
      end
    endcase
  end

  // =========================================================================
  // Result assignment
  // =========================================================================
  logic d_is_min;
  logic q_invert, r_invert;
  logic [31:0] bypass_q, bypass_rem;

  assign d_is_min   = is_signed && (op2_reg == 32'h80000000);
  assign q_invert   = is_signed && (op1_sign ^ op2_sign) && (raw_quotient != 0);
  assign r_invert   = is_signed && op1_sign && (rem_denorm_reg != 0);
  assign bypass_q   = (div_op1_abs == 32'h80000000) ? 32'd1 : 32'd0;
  assign bypass_rem = (div_op1_abs == 32'h80000000) ? 32'd0 : div_op1_abs;
  always_comb begin
    quotient  = q_invert ? quotient_2s_reg : raw_quotient;
    remainder = r_invert ? rem_2s_reg : rem_denorm_reg;
    if (div_by_zero) begin
      quotient  = 32'hFFFFFFFF;
      remainder = op1_reg;
    end else if (d_is_min) begin
      quotient  = (is_signed && (op1_sign ^ op2_sign) && bypass_q != 0)   ? (~bypass_q + 1'b1)   : bypass_q;
      remainder = (is_signed && op1_sign && bypass_rem != 0) ? (~bypass_rem + 1'b1) : bypass_rem;
    end
  end
endmodule
// ================================================================================================
// Module Name : div_unit
// Description : Wrapper that instantiates and wiring the div controller and div datapath 
// ================================================================================================
module div_unit (
    input logic        clk,
    input logic        rst_n,
    input logic        start_div,
    input logic [ 1:0] div_type,
    input logic [31:0] op1,
    input logic [31:0] op2,

    // Shared Resource Inputs
    input logic [63:0] arith_result,
    input logic [31:0] shift_result,

    // Shared Resource Controls
    div_feedback_if.exe_out div_fb_bus,

    // Final Outputs
    output logic [31:0] quotient,
    output logic [31:0] remainder,
    output logic        div_done,
    output logic        div_idle
);

  // Status signals from Datapath to FSM
  logic       op1_sign;
  logic       op2_sign;
  logic       div_by_zero;
  logic       arith_result_sign;

  // Control signals from FSM to Datapath
  logic       init_en;
  logic       loop_en;
  logic       swap_q_qm;
  logic [1:0] arith_op1_sel;
  logic [1:0] arith_op2_sel;
  logic       save_2s_ops;
  logic       save_2s_q_rem;
  logic       save_remainder;

  // Internal wires for signals shared between FSM, Datapath, and Interface
  logic       int_div_2s;
  logic       int_div_shift_divisor;
  logic       int_div_shift_remainder;
  logic       int_div_final_cycle;

  assign div_fb_bus.div_2s              = int_div_2s;
  assign div_fb_bus.div_shift_divisor   = int_div_shift_divisor;
  assign div_fb_bus.div_shift_remainder = int_div_shift_remainder;
  assign div_fb_bus.div_final_cycle     = int_div_final_cycle;

  // Controller
  div_fsm FSM_CORE (
      .clk              (clk),
      .rst_n            (rst_n),
      .start_div        (start_div),
      .div_type         (div_type),
      .op1_sign         (op1_sign),
      .op2_sign         (op2_sign),
      .div_by_zero      (div_by_zero),
      .arith_result_sign(arith_result_sign),

      .div_2s             (int_div_2s),
      .div_shift_divisor  (int_div_shift_divisor),
      .div_final_cycle    (int_div_final_cycle),
      .div_shift_remainder(int_div_shift_remainder),

      .init_en       (init_en),
      .loop_en       (loop_en),
      .swap_q_qm     (swap_q_qm),
      .arith_op1_sel (arith_op1_sel),
      .arith_op2_sel (arith_op2_sel),
      .save_2s_ops   (save_2s_ops),
      .save_2s_q_rem (save_2s_q_rem),
      .save_remainder(save_remainder),
      .div_done     (div_done),
      .div_idle     (div_idle)
  );

  // Datapath
  div_datapath DATAPATH_CORE (
      .clk         (clk),
      .rst_n       (rst_n),
      .start_div   (start_div),
      .div_type    (div_type),
      .op1         (op1),
      .op2         (op2),
      .arith_result(arith_result),
      .shift_result(shift_result),

      .div_idle           (div_idle),
      .init_en            (init_en),
      .loop_en            (loop_en),
      .swap_q_qm          (swap_q_qm),
      .arith_op1_sel      (arith_op1_sel),
      .arith_op2_sel      (arith_op2_sel),
      .save_2s_ops        (save_2s_ops),
      .save_2s_q_rem      (save_2s_q_rem),
      .save_remainder     (save_remainder),
      .div_shift_divisor  (int_div_shift_divisor),
      .div_shift_remainder(int_div_shift_remainder),
      .div_2s             (int_div_2s),

      .op1_sign         (op1_sign),
      .op2_sign         (op2_sign),
      .div_by_zero      (div_by_zero),
      .arith_result_sign(arith_result_sign),

      .div_shift_amount (div_fb_bus.div_shift_amount),
      .div_arith_op1(div_fb_bus.div_arith_op1),
      .div_arith_op2(div_fb_bus.div_arith_op2),
      .div_shift_op (div_fb_bus.div_shift_op),

      .quotient (quotient),
      .remainder(remainder)
  );

endmodule
