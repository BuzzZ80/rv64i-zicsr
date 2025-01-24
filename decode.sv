typedef struct {
    logic [63:0] immediate;
    logic [4:0] reg_read_addrs [0:1];
    logic [4:0] reg_wb_addr;
    logic use_imm;
    logic use_pc;
    logic [2:0] alu_op;
    logic alu_modify;
    logic cast_word;
    logic [1:0] data_size;
    logic read_unsigned;
    logic data_read;
    logic data_write;
    logic branch;
    logic jump;
    logic [2:0] branch_cond;
    logic csr_read;
    logic csr_write;
    logic mret;
    logic sret;
} decoded_instruction;

module decoder(
    input logic [31:0] instruction,
    output decoded_instruction decoded,
    output illegal_instruction,
    output logic ebreak,
    output logic ecall
);
    logic [2:0] inst_type;
    logic op_func3_illegal;
    logic alu_illegal;

    assign illegal_instruction = op_func3_illegal || alu_illegal;

    decode_type type_decoder(
        .instruction(instruction),
        .inst_type(inst_type),
        .illegal_instruction(op_func3_illegal),
        .ebreak(ebreak),
        .ecall(ecall),
        .mret(decoded.mret),
        .sret(decoded.sret)
    );
    decode_imm immediate_decoder(
        .instruction(instruction),
        .inst_type(inst_type),
        .immediate(decoded.immediate)
    );
    decode_regs register_decoder(
        .instruction(instruction),
        .inst_type(inst_type),
        .reg_read_addrs(decoded.reg_read_addrs),
        .reg_wb_addr(decoded.reg_wb_addr)
    );
    decode_alu alu_decoder(
        .instruction(instruction),
        .inst_type(inst_type),
        .use_imm(decoded.use_imm),
        .use_pc(decoded.use_pc),
        .alu_op(decoded.alu_op),
        .alu_modify(decoded.alu_modify),
        .cast_word(decoded.cast_word),
        .illegal_instruction(alu_illegal)
    );
    decode_mem memory_decoder(
        .instruction(instruction),
        .data_size(decoded.data_size),
        .read_unsigned(decoded.read_unsigned),
        .data_read(decoded.data_read),
        .data_write(decoded.data_write)
    );
    decode_branch branch_decoder(
        .instruction(instruction),
        .branch(decoded.branch),
        .jump(decoded.jump),
        .branch_cond(decoded.branch_cond)
    );
    decode_csr csr_decoder(
        .instruction(instruction),
        .inst_type(inst_type),
        .csr_read(decoded.csr_read),
        .csr_write(decoded.csr_write)
    );
endmodule

module decode_type (
    input wire [31:0] instruction,
    output logic [2:0] inst_type,
    output logic illegal_instruction,
    output logic ebreak,
    output logic ecall,
    output logic mret,
    output logic sret
);
    always_comb begin
        inst_type = 0;
        illegal_instruction = 0;
        ebreak = 0;
        ecall = 0;
        mret = 0;
        sret = 0;
        case (instruction[6:0])
            'h03: 
                if (instruction[14:12] == 7) illegal_instruction = 1;
                else inst_type = 1;
            'h13: inst_type = 1;
            'h17: inst_type = 4;
            'h1B: 
                if (instruction[13:12] != 1 && instruction[14:12] != 0) illegal_instruction = 1;
                else inst_type = 1;
            'h23: 
                if (instruction[14]) illegal_instruction = 1;
                else inst_type = 2;
            // atomics
            'h2F: 
                if (instruction[14:13] != 1) illegal_instruction = 1;
                else inst_type = 0;
            'h33: inst_type = 0;
            'h37: inst_type = 4;
            'h3B: 
                if (instruction[13:12] != 1 && instruction[14:12] != 0) illegal_instruction = 1;
                else inst_type = 0;
            'h63: 
                if (instruction[14:13] == 1) illegal_instruction = 1;
                else inst_type = 3;
            'h67: 
                if (instruction[14:12] != 0) illegal_instruction = 1;
                else inst_type = 1;
            'h6F: inst_type = 5;
            'h73: 
                // system instructions
                if (instruction[14:12] == 0) begin
                    inst_type = 7;
                    casez (instruction[31:20])
                        12'b000000000000: ecall = 1;
                        12'b000000000001: ebreak = 1;
                        12'b000100000010: sret = 1;
                        12'b001100000010: mret = 1;
                        default: illegal_instruction = 1;
                    endcase
                end
                // csr instructions
                else if (instruction[14:12] != 4) begin
                    inst_type = 1;
                end
                else
                    illegal_instruction = 1;
            default: illegal_instruction = 1;
        endcase
    end
endmodule

module decode_imm (
    input wire [31:0] instruction,
    input wire [2:0] inst_type,
    output logic [63:0] immediate
);
    always_comb begin
        case (inst_type)
            1: immediate = { {52{instruction[31]}}, instruction[31:20] };
            2: immediate = { {52{instruction[31]}}, instruction[31:25], instruction[11:7] };
            3: immediate = { {51{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
            4: immediate = { {32{instruction[31]}}, instruction[31:12], 12'b0 };
            5: immediate = { {44{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0 };
            default: immediate = 0;
        endcase
    end
endmodule

module decode_regs(
    input wire [31:0] instruction,
    input wire [2:0] inst_type,
    output logic [4:0] reg_read_addrs [0:1],
    output logic [4:0] reg_wb_addr
);
    always_comb case (inst_type)
        0: begin
            reg_read_addrs[0] = instruction[19:15];
            reg_read_addrs[1] = instruction[24:20];
            reg_wb_addr = instruction[11:7];
        end
        1: begin
            reg_read_addrs[0] = instruction[19:15];
            reg_read_addrs[1] = 0;
            reg_wb_addr = instruction[11:7];
        end
        2, 3: begin
            reg_read_addrs[0] = instruction[19:15];
            reg_read_addrs[1] = instruction[24:20];
            reg_wb_addr = 0;
        end
        4, 5: begin
            reg_read_addrs = {0, 0};
            reg_wb_addr = instruction[11:7];
        end
        default: begin
            reg_read_addrs = {0, 0};
            reg_wb_addr = 0;
        end
    endcase
endmodule

// TODO: make alu do operations for csr stuff
module decode_alu (
    input wire [31:0] instruction,
    input wire [2:0] inst_type,
    output logic use_imm,
    output logic use_pc,
    output logic [2:0] alu_op,
    output logic alu_modify,
    output logic cast_word,
    output logic illegal_instruction
);
    wire uses_func7;
    logic [6:0] func7;

    assign use_imm = inst_type != 0;
    assign use_pc = instruction[6:0] inside {
        7'b0010111, // AUIPC
        7'b1100011, // Branches
        7'b1101111  // JAL
    };

    // ALU operation for alu related instructions
    always_comb if ((instruction[6:0] & 7'b1010111) == 7'b0010011)
        alu_op = instruction[14:12];
    // ALU operation for CSR instructions
    else if ((instruction[6:0] == 'h73) && instruction[13]) 
        alu_op = {2'b11, instruction[12]};
    // default alu operation is addition
    else 
        alu_op = 0;
    
    assign func7 = (
        (inst_type == 0) || 
        (((instruction[6:0] & 7'b1010111) == 7'b0010011) && (instruction[13:12] == 2'b01))
    ) ? instruction[31:25] : 0;

    // take modify from func7, or modify for csr clear instruction
    assign alu_modify = 
        func7[5] 
        || ((instruction[6:0] == 'h73) && (instruction[13:12] == 2'b11));
    // if instruction is add or right shift
    assign uses_func7 = (instruction[13:12] == 2'b01) || (instruction[14:12] == 3'b000);
    assign illegal_instruction = !(
        ((func7 & 7'b1011111) == 7'b0)
        && (!func7[5] || uses_func7)
    );

    assign cast_word = (instruction[6:0] & 7'b1011111) == 7'b0011011;
endmodule

module decode_mem (
    input wire [31:0] instruction,
    output logic [1:0] data_size,
    output logic read_unsigned,
    output logic data_read,
    output logic data_write
);
    assign data_read = instruction[6:0] == 'b0000011;
    assign data_write = instruction[6:0] == 'b0100011;
    assign data_size = instruction[13:12];
    assign read_unsigned = instruction[14];
endmodule

module decode_branch (
    input wire [31:0] instruction,
    output logic branch,
    output logic jump,
    output logic [2:0] branch_cond
);
    assign branch = instruction[6:0] == 'b1100011;
    assign jump = (instruction[6:0] & 'b1110111) == 'b1100111;
    assign branch_cond = instruction[14:12];
endmodule

module decode_csr (
    input wire [31:0] instruction,
    input wire [2:0] inst_type,
    output logic csr_read,
    output logic csr_write
);
    wire [4:0] rd_addr = instruction[11:7];
    wire [4:0] rs1_addr = instruction[19:15];

    wire csr_inst = instruction[6:0] == 'b1110011 && instruction[13:12] != 2'b0;
    wire csr_inst_type = instruction[13];
    assign csr_read = csr_inst && (csr_inst_type || (rd_addr != 0));
    assign csr_write = csr_inst && (!csr_inst_type || (rs1_addr != 0));
endmodule