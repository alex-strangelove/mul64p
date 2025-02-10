`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/03/2025 05:18:17 PM
// Design Name: 
// Module Name: mul64_tb
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


module mul64p_tb;
    // Parameters
    localparam    CLK_PERIOD     = 1.971; // 507 MHZ
    localparam    PIPELINE_DEPTH = 11;    

    // Signals
    logic         clk, rst;
    logic [63:0]  A, B;
    logic [127:0] Result, 
                  ExpectedResult;
                  
    int           error_count = 0;
    int           test_count = 0;

    // DUT Instance
    rtl_mul64p dut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .Result(Result)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize and reset
        rst = 1;
        A = 0;
        B = 0;
        repeat(3) @(posedge clk);
        rst = 0;

        // Test Case 1: Zero multiplication
        @(posedge clk);
        A = 0; B = 0;
        
        // Test Case 2: Maximum values
        @(posedge clk);
        A = 64'hFFFF_FFFF_FFFF_FFFF;
        B = 64'hFFFF_FFFF_FFFF_FFFF;
        
        // Test Case 3: Random values
        repeat(1000) begin
            @(posedge clk);
            A = $random();
            B = $random();
            test_count++;
            
            // Calculate expected after pipeline delay
            #(PIPELINE_DEPTH * CLK_PERIOD);
            ExpectedResult = A * B;
            
            if(Result !== ExpectedResult) begin
                $display("============================================");
                $display("Error: A=%h B=%h", A, B);
                $display("Expected: %h", ExpectedResult);
                $display("Got: %h", Result);
                $display("============================================");
                error_count++;
            end 
        end

        // Report results
        $display("Tests completed: %0d", test_count);
        $display("Errors: %0d", error_count);
        $finish;
    end

    // Coverage
    covergroup cg @(posedge clk);
        coverpoint A {
            bins zeros = {'h0};
            bins max = {'hFFFF_FFFF_FFFF_FFFF};
            bins others = {[1:$]};
        }
        coverpoint B {
            bins zeros = {'h0};
            bins max = {'hFFFF_FFFF_FFFF_FFFF};
            bins others = {[1:$]};
        }
        cross A, B;
    endgroup

    cg coverage = new();

endmodule
