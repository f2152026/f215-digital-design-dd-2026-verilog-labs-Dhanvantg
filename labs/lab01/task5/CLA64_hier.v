// cla64_hier.v
// BONUS -- open-ended. No detailed scaffold is provided; this is meant to
// be a genuine design exercise. Not required for lab submission.
//
// You will likely need to modify cla4.v (or add signals alongside it) so
// that block-generate/block-propagate summaries of its own Gi, Pi signals
// are exposed as outputs, since the second-level lookahead unit below
// needs them. As with every module in this lab from Task 2 onward, every
// gate/assign you add should carry an explicit delay.
//
// Starting point (from Tutorial 3, Q4(d)):
//   - Reuse 16 four-bit CLA blocks (your cla4.v) -- their internal logic
//     doesn't change.
//   - For each block k, define:
//       Gblk_k = "this block produces a carry regardless of its incoming
//                 carry" -- a Boolean function of that block's own 4
//                 bit-level Gi, Pi signals.
//       Pblk_k = "an incoming carry sails straight through this whole
//                 block" -- likewise a function of its own Gi, Pi.
//   - Build a second-level lookahead unit -- structurally identical to
//     cla4.v, just one level up -- that computes each block's carry-in
//     directly from Gblk_0..Gblk_15, Pblk_0..Pblk_15, and cin, instead of
//     rippling block to block.
//
// To test this, wire it into dut.v as a fourth option (copy the pattern
// used for the other three) and run it through the same tb.v. Compare
// your final delay to cla64_blocked.v from Task 4.

module cla64_hier(
  input  [63:0] a,
  input  [63:0] b,
  input         cin,
  output [63:0] sum,
  output        cout
);

  wire [63:0] bit_p, bit_g;
  wire [15:0] block_p, block_g;
  wire [16:1] block_c;

  // Bit-level summaries used to form the sixteen four-bit block
  // generate/propagate signals.
  assign #(2) bit_p = a ^ b;
  assign #(2) bit_g = a & b;

  genvar k;
  generate
    for (k = 0; k < 16; k = k + 1) begin : gen_block_summary
      localparam integer BASE = 4 * k;

      assign #(2) block_p[k] = &bit_p[BASE +: 4];
      assign #(2) block_g[k] =
          bit_g[BASE + 3]
        | (bit_p[BASE + 3] & bit_g[BASE + 2])
        | (bit_p[BASE + 3] & bit_p[BASE + 2] & bit_g[BASE + 1])
        | (bit_p[BASE + 3] & bit_p[BASE + 2]
           & bit_p[BASE + 1] & bit_g[BASE]);
    end
  endgenerate

  // Second-level lookahead. For every block, all possible carry sources
  // are evaluated in parallel; no block carry depends recursively on the
  // carry from the preceding block.
  genvar carry_index, source_index;
  generate
    for (carry_index = 0; carry_index < 16;
         carry_index = carry_index + 1) begin : gen_block_carry
      wire [carry_index + 1:0] carry_terms;

      assign #(2) carry_terms[0] = block_g[carry_index];

      for (source_index = 0; source_index < carry_index;
           source_index = source_index + 1) begin : gen_generate_term
        assign #(2) carry_terms[source_index + 1] =
          block_g[source_index]
          & (&block_p[carry_index:source_index + 1]);
      end

      assign #(2) carry_terms[carry_index + 1] =
        cin & (&block_p[carry_index:0]);
      assign #(2) block_c[carry_index + 1] = |carry_terms;
    end
  endgenerate

  // Sixteen ordinary four-bit CLA blocks consume the independently
  // computed carry-ins above.
  genvar block_index;
  generate
    for (block_index = 0; block_index < 16;
         block_index = block_index + 1) begin : gen_cla_block
      wire unused_cout;
      if (block_index == 0) begin : gen_first_block
        cla4 block (
          .a    (a[4 * block_index +: 4]),
          .b    (b[4 * block_index +: 4]),
          .cin  (cin),
          .sum  (sum[4 * block_index +: 4]),
          .cout (unused_cout)
        );
      end else begin : gen_later_block
        cla4 block (
          .a    (a[4 * block_index +: 4]),
          .b    (b[4 * block_index +: 4]),
          .cin  (block_c[block_index]),
          .sum  (sum[4 * block_index +: 4]),
          .cout (unused_cout)
        );
      end
    end
  endgenerate

  buf #(2) (cout, block_c[16]);

endmodule
