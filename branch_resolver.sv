module branch_resolver (
    input logic branch,
    input logic jump,
    input logic [2:0] branch_cond,
    input logic [63:0] operand1,
    input logic [63:0] operand2,
    output logic do_jump
);  
    logic cond_v;
    logic eq = (operand1 ^ operand2) == 0;
    logic slt = ({ 
        {1'b0, operand1} 
        + {1'b1, (operand2 ^ {64{1'b1}})}
        + 1
    }[64] ^ (operand1[63] ^ operand2[63])) ? 1 : 0;
    logic ult = { 
            {1'b0, operand1} 
            + {1'b1, (operand2 ^ {64{1'b1}})}
            + 1
        }[64] ? 1 : 0;

    always_comb case (branch_cond)
        0: cond_v = eq;
        1: cond_v = !eq;
        4: cond_v = slt;
        5: cond_v = !slt;
        6: cond_v = ult;
        7: cond_v = !ult;
        default: cond_v = 0;
    endcase
    assign do_jump = (branch && cond_v) || jump; 
endmodule