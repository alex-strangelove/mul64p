`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2025 05:16:56 PM
// Design Name: 
// Module Name: rtl_mul64p
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

module mul32p
(
    input              clk, rst,
    input      [31:0]  A, B,
    output reg [63:0]  Result
);
    // Input segments
    reg [15:0] AH_S1, AL_S1, 
               BH_S1, BL_S1;
    
    // Partial products
    reg [31:0] PP_HH_S2, PP_HL_S2, 
               PP_LH_S2, PP_LL_S2;

    // Partial products copy
    reg [31:0] PP_HH_S2_pipe, PP_HL_S2_pipe, 
               PP_LH_S2_pipe, PP_LL_S2_pipe;

    // Partial results
    reg [63:0] PR_S1, PR_S2;
    reg [63:0] PR_S1_pipe, PR_S2_pipe;
    
    // Split Inputs into Segments
    always @(posedge clk) begin
        if (rst) begin
            {AH_S1, AL_S1, 
             BH_S1, BL_S1} = 64'b0;
        end else begin
            AH_S1 <= A[31:16];
            AL_S1 <= A[15:0];
            BH_S1 <= B[31:16];
            BL_S1 <= B[15:0];
        end
    end
    
    // Compute Partial Products
    always @(posedge clk) begin
        if (rst) begin
            {PP_HH_S2, PP_HL_S2, 
             PP_LH_S2, PP_LL_S2} <= 128'b0;
        end else begin
            PP_HH_S2 <= AH_S1 * BH_S1;
            PP_HL_S2 <= AH_S1 * BL_S1;
            PP_LH_S2 <= AL_S1 * BH_S1;
            PP_LL_S2 <= AL_S1 * BL_S1;
        end
    end
    
    // Copy PP into reg
    always @(posedge clk) begin
        if (rst) begin
            {PP_HH_S2_pipe, PP_HL_S2_pipe, 
             PP_LH_S2_pipe, PP_LL_S2_pipe} <= 128'b0;
        end else begin
            PP_HH_S2_pipe <= PP_HH_S2;
            PP_HL_S2_pipe <= PP_HL_S2;
            PP_LH_S2_pipe <= PP_LH_S2;
            PP_LL_S2_pipe <= PP_LL_S2;
        end
    end
    
    // Combine Partial Products
    always @(posedge clk) begin
        if (rst) begin
            {PR_S1, PR_S2} <= 128'b0;
        end else begin
            PR_S1 <= (PP_LH_S2_pipe << 16) + 
                      PP_LL_S2_pipe;
            PR_S2 <= (PP_HH_S2_pipe << 32) + 
                     (PP_HL_S2_pipe << 16);
        end
    end
    
    // Copy partial results into reg
    always @(posedge clk) begin
        if (rst) begin
            {PR_S1_pipe, PR_S2_pipe} <= 128'b0;
        end else begin
            PR_S1_pipe <= PR_S1;
            PR_S2_pipe <= PR_S2;
        end
    end
    
    // Final addition
    always @(posedge clk) begin
        if (rst) begin
            Result <= 64'b0;
        end else begin
            Result <= PR_S2_pipe + PR_S1_pipe;
        end
    end
endmodule

module rtl_mul64p 
(
    input                clk, rst,
    input       [63:0]   A, B,
    output reg  [127:0]  Result
);
    // Input segments
    reg [31:0]  AH_S1, AL_S1, 
                BH_S1, BL_S1;

    // Store PP after shift
    reg [127:0] shift_LH, shift_HH, shift_HL;
    
    // Partial products
    wire [63:0] PP_HH_S2, PP_HL_S2, 
                PP_LH_S2, PP_LL_S2;
    reg  [63:0] PP_HH_S2_pipe, PP_HL_S2_pipe, 
                PP_LH_S2_pipe, PP_LL_S2_pipe;

    // Partial results
    reg [127:0] PR_S1, PR_S2;
    reg [127:0] PR_S1_pipe, PR_S2_pipe;
    
    mul32p mult_hh(
        .clk(clk),  
        .rst(rst),  
        .A(AH_S1),    
        .B(BH_S1),    
        .Result(PP_HH_S2)
    );
    
    mul32p mult_hl(
        .clk(clk),  
        .rst(rst),  
        .A(AH_S1),    
        .B(BL_S1),    
        .Result(PP_HL_S2)
    );
    
    mul32p mult_lh(
        .clk(clk),  
        .rst(rst),  
        .A(AL_S1),    
        .B(BH_S1),    
        .Result(PP_LH_S2)
    );
    
    mul32p mult_ll(
        .clk(clk),  
        .rst(rst),  
        .A(AL_S1),    
        .B(BL_S1),    
        .Result(PP_LL_S2)
    );
    
    // Split Inputs into Segments
    always @(posedge clk) begin
        if (rst) begin
            {AH_S1, AL_S1, 
             BH_S1, BL_S1} = 128'b0;
        end else begin
            AH_S1 <= A[63:32];
            AL_S1 <= A[31:0];
            BH_S1 <= B[63:32];
            BL_S1 <= B[31:0];
        end
    end
    
    // Copy PP into reg
    always @(posedge clk) begin
        if (rst) begin
            {PP_HH_S2_pipe, PP_HL_S2_pipe, 
             PP_LH_S2_pipe, PP_LL_S2_pipe} <= 256'b0;
        end else begin
            PP_HH_S2_pipe <= PP_HH_S2;
            PP_HL_S2_pipe <= PP_HL_S2;
            PP_LH_S2_pipe <= PP_LH_S2;
            PP_LL_S2_pipe <= PP_LL_S2;
        end
    end

    // First level additions
    always @(posedge clk) begin
        if (rst) begin
            PR_S1 <= 0;
            PR_S2 <= 0;
        end else begin
            PR_S1 <= (PP_LH_S2_pipe << 32) + // 96 bits
                      PP_LL_S2_pipe;         // 64 bits
            PR_S2 <= (PP_HH_S2_pipe << 64)  + // 128 bits
                     (PP_HL_S2_pipe << 32);   // 96 bits
        end
    end

    // Pipeline registers
    always @(posedge clk) begin
        if (rst) begin
            PR_S1_pipe <= 0;
            PR_S2_pipe <= 0;
        end else begin
            PR_S1_pipe <= PR_S1;
            PR_S2_pipe <= PR_S2;
        end
    end
    
    // Final addition
    always @(posedge clk) begin
        if (rst) begin
            Result <= 128'b0;
        end else begin
            Result <= PR_S2_pipe + PR_S1_pipe;
        end
    end
endmodule
