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
    reg [15:0] AH, AL, BH, BL;
    
    // Partial products
    reg [31:0] PP_AH_BH, PP_AH_BL, PP_AL_BH, PP_AL_BL;
    
    // Split Inputs into Segments
    always @(posedge clk) begin: FirstStage
        if (rst) begin
            {AH, AL, BH, BL} = 64'b0;
        end else begin
            AH <= A[31:16];
            AL <= A[15:0];
            BH <= B[31:16];
            BL <= B[15:0];
        end
    end
    
    // Compute Partial Products
    always @(posedge clk) begin: SecondStage
        if (rst) begin
            {PP_AH_BH, PP_AH_BL, PP_AL_BH, PP_AL_BL} = 128'b0;
        end else begin
            // NOTE: Multiplication inferred directly by the synthesis tool
            PP_AH_BH <= AH * BH;
            PP_AH_BL <= AH * BL;
            PP_AL_BH <= AL * BH;
            PP_AL_BL <= AL * BL;
        end
    end
    
    // Combine Partial Products
    always @(posedge clk) begin: ThirdStage
        if (rst) begin
            Result <= 64'b0;
        end else begin
            Result <= (PP_AH_BH << 32) + // 64 bits
                      (PP_AH_BL << 16) + // 48 bits
                      (PP_AL_BH << 16) + // 48 bits
                       PP_AL_BL;         // 32 bits
        end
    end
endmodule

module rtl_mul64p (
    input                clk, rst,
    input       [63:0]   A, B,
    output reg  [127:0]  Result
);
    // Input segments
    reg [31:0] AH, AL, BH, BL;
    
    // Partial products
    wire [63:0] PP_AH_BH, PP_AH_BL, PP_AL_BH, PP_AL_BL;
    
    mul32p mult_hh(
        .clk(clk),  
        .rst(rst),  
        .A(AH),    
        .B(BH),    
        .Result(PP_AH_BH)
    );
    
    mul32p mult_hl(
        .clk(clk),  
        .rst(rst),  
        .A(AH),    
        .B(BL),    
        .Result(PP_AH_BL)
    );
    
    mul32p mult_lh(
        .clk(clk),  
        .rst(rst),  
        .A(AL),    
        .B(BH),    
        .Result(PP_AL_BH)
    );
    
    mul32p mult_ll(
        .clk(clk),  
        .rst(rst),  
        .A(AL),    
        .B(BL),    
        .Result(PP_AL_BL)
    );
    
    // Split Inputs into Segments
    always @(posedge clk) begin: FirstStage
        if (rst) begin
            {AH, AL, BH, BL} = 128'b0;
        end else begin
            AH <= A[63:32];
            AL <= A[31:0];
            BH <= B[63:32];
            BL <= B[31:0];
        end
    end
    
    // 2nd stage: Combine Partial Products
    always @(posedge clk) begin: SecondStage
        if (rst) begin
            Result <= 128'b0;
        end else begin
            Result <= (PP_AH_BH << 64) + // 128 bits
                      (PP_AH_BL << 32) + // 96 bits
                      (PP_AL_BH << 32) + // 96 bits
                       PP_AL_BL;         // 64 bits
        end
    end
endmodule
