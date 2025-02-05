`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/04/2025 12:07:51 PM
// Design Name: 
// Module Name: rtl_mul64p_harness
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`default_nettype none

module Multiplexer_Binary_Behavioural
#(
    parameter       WORD_WIDTH          = 0,
    parameter       ADDR_WIDTH          = 0,
    parameter       INPUT_COUNT         = 0,

    // Do not set at instantiation
    parameter   TOTAL_WIDTH = WORD_WIDTH * INPUT_COUNT
)
(
    input   wire    [ADDR_WIDTH-1:0]    selector,
    input   wire    [TOTAL_WIDTH-1:0]   words_in,
    output  reg     [WORD_WIDTH-1:0]    word_out
);

    initial begin
        word_out = {WORD_WIDTH{1'b0}};
    end

    always @(*) begin
        word_out = words_in[(selector * WORD_WIDTH) +: WORD_WIDTH];
    end

endmodule

module Register
#(
    parameter WORD_WIDTH  = 0,
    parameter RESET_VALUE = 0
)
(
    input   wire                        clock,
    input   wire                        clock_enable,
    input   wire                        clear,
    input   wire    [WORD_WIDTH-1:0]    data_in,
    output  reg     [WORD_WIDTH-1:0]    data_out
);

    initial begin
        data_out = RESET_VALUE;
    end

// Here, we use the  "last assignment wins" idiom (See
// [Resets](./verilog.html#resets)) to implement reset.  This is also one
// place where we cannot use ternary operators, else the last assignment for
// clear (e.g.: `data_out <= (clear == 1'b1) ? RESET_VALUE : data_out;`) would
// override any previous assignment with the current value of `data_out` if
// `clear` is not asserted!

    always @(posedge clock) begin
        if (clock_enable == 1'b1) begin
            data_out <= data_in;
        end

        if (clear == 1'b1) begin
            data_out <= RESET_VALUE;
        end
    end

endmodule

module Register_Pipeline
#(
    parameter                   WORD_WIDTH      = 0,
    parameter                   PIPE_DEPTH      = 0,
    // Don't set at instantiation
    parameter                   TOTAL_WIDTH     = WORD_WIDTH * PIPE_DEPTH,

    // concatenation of each stage initial/reset value
    parameter [TOTAL_WIDTH-1:0] RESET_VALUES    = 0
)
(
    input   wire                        clock,
    input   wire                        clock_enable,
    input   wire                        clear,
    input   wire                        parallel_load,
    input   wire    [TOTAL_WIDTH-1:0]   parallel_in,
    output  reg     [TOTAL_WIDTH-1:0]   parallel_out,
    input   wire    [WORD_WIDTH-1:0]    pipe_in,
    output  reg     [WORD_WIDTH-1:0]    pipe_out
);

    localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

    initial begin
        pipe_out = WORD_ZERO;
    end

// Each pipeline state is composed of a Multiplexer feeding a Register, so we
// can select either the output of the previous Register, or the parallel load
// data. So we need a set of input and ouput wires for each stage. 

    wire [WORD_WIDTH-1:0] pipe_stage_in     [PIPE_DEPTH-1:0];
    wire [WORD_WIDTH-1:0] pipe_stage_out    [PIPE_DEPTH-1:0];

// The following attributes prevent the implementation of the multiplexer with
// DSP blocks. This can be a useful implementation choice sometimes, but here
// it's terrible, since FPGA flip-flops usually have separate data and
// synchronous load inputs, giving us a 2:1 mux for free. If not, then we
// should use LUTs instead, or other multiplexers built into the logic blocks.

    (* multstyle = "logic" *) // Quartus
    (* use_dsp   = "no" *)    // Vivado

// We strip out first iteration of module instantiations to avoid having to
// refer to index -1 in the generate loop, and also to connect to `pipe_in`
// rather than the output of a previous register.

    Multiplexer_Binary_Behavioural
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .ADDR_WIDTH     (1),
        .INPUT_COUNT    (2)
    )
    pipe_input_select
    (
        .selector       (parallel_load),    
        .words_in       ({parallel_in[0 +: WORD_WIDTH], pipe_in}),
        .word_out       (pipe_stage_in[0])
    );

    Register
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .RESET_VALUE    (RESET_VALUES[0 +: WORD_WIDTH])
    )
    pipe_stage
    (
        .clock          (clock),
        .clock_enable   (clock_enable),
        .clear          (clear),
        .data_in        (pipe_stage_in[0]),
        .data_out       (pipe_stage_out[0])
    );

    always @(*) begin
        parallel_out[0 +: WORD_WIDTH] = pipe_stage_out[0];
    end

// Now repeat over the remainder of the pipeline stages, starting at stage 1,
// connecting each pipeline stage to the output of the previous pipeline
// stage.

    generate

        genvar i;

        for(i=1; i < PIPE_DEPTH; i=i+1) begin : pipe_stages

            (* multstyle = "logic" *) // Quartus
            (* use_dsp   = "no" *)    // Vivado

            Multiplexer_Binary_Behavioural
            #(
                .WORD_WIDTH     (WORD_WIDTH),
                .ADDR_WIDTH     (1),
                .INPUT_COUNT    (2)
            )
            pipe_input_select
            (
                .selector       (parallel_load),    
                .words_in       ({parallel_in[WORD_WIDTH*i +: WORD_WIDTH], pipe_stage_out[i-1]}),
                .word_out       (pipe_stage_in[i])
            );


            Register
            #(
                .WORD_WIDTH     (WORD_WIDTH),
                .RESET_VALUE    (RESET_VALUES[WORD_WIDTH*i +: WORD_WIDTH])
            )
            pipe_stage
            (
                .clock          (clock),
                .clock_enable   (clock_enable),
                .clear          (clear),
                .data_in        (pipe_stage_in[i]),
                .data_out       (pipe_stage_out[i])
            );

            always @(*) begin
                parallel_out[WORD_WIDTH*i +: WORD_WIDTH] = pipe_stage_out[i];
            end

        end

    endgenerate

// And finally, connect the output of the last register to the module pipe output.

    always @(*) begin
        pipe_out = pipe_stage_out[PIPE_DEPTH-1];
    end

endmodule

module Synthesis_Harness_Input
#(
    parameter WORD_WIDTH = 0
)
(
    input   wire                        clock,  
    input   wire                        clear,
    input   wire                        bit_in,
    input   wire                        bit_in_valid,
    output  wire    [WORD_WIDTH-1:0]    word_out
);

    localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

    // Vivado: don't put in I/O buffers, and keep netlists separate in
    // synth and implementation.
    (* IOB = "false" *)
    (* DONT_TOUCH = "true" *)

    // Quartus: don't use I/O buffers, and don't merge registers with others.
    (* useioff = 0 *)
    (* preserve *)

    Register_Pipeline
    #(
        .WORD_WIDTH     (1),
        .PIPE_DEPTH     (WORD_WIDTH),
        .RESET_VALUES   (WORD_ZERO)
    )
    shift_bit_into_word
    (
        .clock          (clock),
        .clock_enable   (bit_in_valid),
        .clear          (clear),
        .parallel_load  (1'b0),
        .parallel_in    (WORD_ZERO),
        .parallel_out   (word_out),
        .pipe_in        (bit_in),
        // verilator lint_off PINCONNECTEMPTY
        .pipe_out       ()
        // verilator lint_on  PINCONNECTEMPTY
    );

endmodule

module Synthesis_Harness_Output 
#(
    parameter   WORD_WIDTH = 0
)
(
    input       wire                        clock,
    input       wire                        clear,
    input       wire    [WORD_WIDTH-1:0]    word_in,
    input       wire                        word_in_valid,
    output      reg                         bit_out
);

    localparam WORD_ZERO = {WORD_WIDTH{1'b0}};

    initial begin
        bit_out = 1'b0;
    end

    wire [WORD_WIDTH-1:0] word_out;

    // Vivado: don't put in I/O buffers, and keep netlists separate in
    // synth and implementation.
    (* IOB = "false" *)
    (* DONT_TOUCH = "true" *)

    // Quartus: don't use I/O buffers, and don't merge registers with others.
    (* useioff = 0 *)
    (* preserve *)

    Register_Pipeline
    #(
        .WORD_WIDTH     (WORD_WIDTH),
        .PIPE_DEPTH     (1),
        .RESET_VALUES   (WORD_ZERO)
    )
    word_register
    (
        .clock          (clock),
        .clock_enable   (word_in_valid),
        .clear          (clear),
        .parallel_load  (1'b0),
        .parallel_in    (WORD_ZERO),
        // verilator lint_off PINCONNECTEMPTY
        .parallel_out   (),
        // verilator lint_on  PINCONNECTEMPTY
        .pipe_in        (word_in),
        .pipe_out       (word_out)
    );

    always @(*) begin
        bit_out = ^word_out;
    end

endmodule

module rtl_mul64p_harness
(
    input   wire    clk,            // Clock
    input   wire    rst,            // Reset
    input   wire    serial_in,      // Serial input for A/B
    input   wire    data_valid,     // Shift-enable for serial input
    output  wire    result_bit      // XOR-reduced result bit
);

    // Total input width: 64 + 64 = 128 bits
    localparam INPUT_WIDTH  = 128;
    localparam OUTPUT_WIDTH = 128;

    //------------------------------------------
    // Synthesis Harness: Inputs (A and B)
    //------------------------------------------
    wire [INPUT_WIDTH-1:0] A_B_combined;

    Synthesis_Harness_Input
    #(
        .WORD_WIDTH (INPUT_WIDTH)
    )
    input_harness
    (
        .clock      (clk),
        .clear      (rst),
        .bit_in     (serial_in),
        .bit_in_valid (data_valid),
        .word_out   (A_B_combined)
    );

    // Split the combined input into A and B
    wire [63:0] A = A_B_combined[127:64];
    wire [63:0] B = A_B_combined[63:0];

    //------------------------------------------
    // Multiplier Core
    //------------------------------------------
    wire [OUTPUT_WIDTH-1:0] Result;

    rtl_mul64p dut
    (
        .clk    (clk),
        .rst    (rst),
        .A      (A),
        .B      (B),
        .Result (Result)
    );

    //------------------------------------------
    // Synthesis Harness: Output (Result)
    //------------------------------------------
    Synthesis_Harness_Output
    #(
        .WORD_WIDTH (OUTPUT_WIDTH)
    )
    output_harness
    (
        .clock          (clk),
        .clear          (rst),
        .word_in        (Result),
        .word_in_valid  (1'b1),     // Always valid (output is registered)
        .bit_out        (result_bit)
    );

endmodule
