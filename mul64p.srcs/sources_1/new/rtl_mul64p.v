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
    reg [15:0] AH_S1, AL_S1, BH_S1, BL_S1;
    
    // Partial products
    reg [31:0] PP_HH_S2, PP_HL_S2, PP_LH_S2, PP_LL_S2;

    // Partial result
    reg [63:0] PR_S1, PR_S2;
    
    // 1st stage: Split Inputs into Segments
    always @(posedge clk) begin: FirstStage
        if (rst) begin
            {AH_S1, AL_S1, BH_S1, BL_S1} = 64'b0;
        end else begin
            AH_S1 <= A[31:16];
            AL_S1 <= A[15:0];
            BH_S1 <= B[31:16];
            BL_S1 <= B[15:0];
        end
    end
    
    // 2nd stage: Compute Partial Products
    always @(posedge clk) begin: SecondStage
        if (rst) begin
            {PP_HH_S2, PP_HL_S2, PP_LH_S2, PP_LL_S2} = 128'b0;
        end else begin
            // NOTE: Multiplication inferred directly by the synthesis tool
            PP_HH_S2 <= AH_S1 * BH_S1;
            PP_HL_S2 <= AH_S1 * BL_S1;
            PP_LH_S2 <= AL_S1 * BH_S1;
            PP_LL_S2 <= AL_S1 * BL_S1;
        end
    end
    
    // 3rd stage: Combine Partial Products. Part 1
    always @(posedge clk) begin: ThirdStage
        if (rst) begin
            PR_S1 <= 64'b0;
        end else begin
            PR_S1 <= (PP_LH_S2 << 16) + // 48 bits
                      PP_LL_S2;         // 32 bits
        end
    end
    
    // 4th stage: Combine Partial Products. Part 2
    always @(posedge clk) begin: FourthStage
        if (rst) begin
            PR_S2 <= 64'b0;
        end else begin
            PR_S2 <= (PP_HH_S2 << 32)  + // 64 bits
                     (PP_HL_S2 << 16);   // 48 bits
        end 
    end
    
    // 5th stage: Combine Final Partial Products. Part 3
    always @(posedge clk) begin: FifthStage
        if (rst) begin
            Result <= 64'b0;
        end else begin
            Result <= PR_S2 + PR_S1;
        end
    end
endmodule

module rtl_mul64p (
    input                clk, rst,
    input       [63:0]   A, B,
    output reg  [127:0]  Result
);
    // Input segments
    reg [31:0] AH_S1, AL_S1, BH_S1, BL_S1;
    
    // Partial products
    wire [63:0] PP_HH_S2, PP_HL_S2, PP_LH_S2, PP_LL_S2;
    
    // Partial result
    reg [127:0] PR_S1, PR_S2;
    
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
    always @(posedge clk) begin: FirstStage
        if (rst) begin
            {AH_S1, AL_S1, BH_S1, BL_S1} = 128'b0;
        end else begin
            AH_S1 <= A[63:32];
            AL_S1 <= A[31:0];
            BH_S1 <= B[63:32];
            BL_S1 <= B[31:0];
        end
    end
    
    // 2nd stage: Combine Partial Products. Part 1
    always @(posedge clk) begin: SecondStage
        if (rst) begin
            PR_S1 <= 128'b0;
        end else begin
            PR_S1 <= (PP_LH_S2 << 32) + // 96 bits
                      PP_LL_S2;         // 64 bits
        end
    end
    
    // 3rd stage: Combine Partial Products. Part 2
    always @(posedge clk) begin: ThirdStage
        if (rst) begin
            PR_S2 <= 128'b0;
        end else begin
            PR_S2 <= (PP_HH_S2 << 64)  + // 128 bits
                     (PP_HL_S2 << 32);   // 96 bits
        end 
    end
    
    // 4th stage: Combine Final Partial Products. Part 3
    always @(posedge clk) begin: FourthStage
        if (rst) begin
            Result <= 128'b0;
        end else begin
            Result <= PR_S2 + PR_S1;
        end
    end
endmodule
