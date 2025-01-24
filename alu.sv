module alu(
    input wire [63:0] operand1,
    input wire [63:0] operand2,
    input wire [2:0] operation,
    input wire modify,
    input wire cast_word,
    output logic [63:0] result
);
    logic [63:0] full_result;

    // Perform operation
    always_comb case (operation)
        // Add, or subtract if modify = 1
        0: full_result = 
            operand1 
            + (operand2 ^ {64{modify}}) 
            + ( modify ? 1 : 0 );
        // left shift
        1: full_result = operand1 << operand2[5:0];
        // subtract and check if there was a borrow (invert if signs were equal)
        // (borrow is inverted carry out)
        2: full_result = ({ 
                {1'b0, operand1} 
                + {1'b1, (operand2 ^ {64{1'b1}})}
                + 1
            }[64] ^ (operand1[63] ^ operand2[63])) ? 1 : 0;
        // subtract and check if less than 0
        3: full_result = { 
                {1'b0, operand1} 
                + {1'b1, (operand2 ^ {64{1'b1}})}
                + 1
            }[64] ? 1 : 0;
        // XOR
        4: full_result = operand1 ^ operand2;
        // right shift - keep and extend sign if modify
        5: full_result = modify ? 
            $signed(operand1) >>> operand2[5:0] 
            : operand1 >> operand2[5:0];
        // Or
        6: full_result = operand1 | operand2;
        // And
        7: full_result = operand1 & (operand2 ^ {64{modify}}) ;
    endcase

    assign result = cast_word ? 
        { {32{full_result[31]}}, full_result[31:0]}
        : full_result;
endmodule