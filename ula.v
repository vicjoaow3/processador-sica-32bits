module ula(
    input  wire [2:0]  op,   // 0:add 1:sub 2:and 3:or 4:not 5:mul 6:div
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] y,
    output wire        Z,
    output wire        N
);
    always @* begin
        case (op)
            3'd0:  y = a + b;                     // ADD
            3'd1:  y = a - b;                     // SUB
            3'd2:  y = a & b;                     // AND
            3'd3:  y = a | b;                     // OR
            3'd4:  y = ~a;                        // NOT (unário)
            3'd5:  y = a * b;                     // MUL (trunc 32b)
            3'd6:  y = (b==0) ? 32'd0 : (a / b);  // DIV (div/0 -> 0)
            default:y = 32'd0;
        endcase
    end

    assign Z = (y == 32'd0);
    assign N = y[31];
endmodule