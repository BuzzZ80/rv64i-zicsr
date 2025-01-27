`include "decode.sv"
`include "register_file.sv"
`include "alu.sv"
`include "branch_resolver.sv"
`include "csr.sv"
`include "trap_handler.sv"
`include "mmu.sv"

// TODO: reimplement vectored interrupts to set pc instead of reading address into pc

module cpu(
    input logic phi1,
    input logic phi2,
    input logic rst,

    output logic [55:0] data_address,
    output logic [1:0] data_size,

    input wire [63:0] input_data,
    output logic input_data_unsigned,
    output logic input_data_request,
    input wire input_data_valid,

    output logic [63:0] output_data,
    output logic output_data_request,
    input wire output_data_complete,

    output logic [55:0] instruction_address,

    input wire [31:0] input_instruction,
    output logic input_instruction_request,
    input wire input_instruction_valid
);
    // exception stuff
    logic [15:0] excs;
    logic take_trap;
    logic trap_to_s;
    logic [63:0] trap_cause;

    wire [63:0] tvec = trap_to_s ? _csr_file.stvec : _csr_file.mtvec;

    assign excs[2] = decoded_illegal || csr_exception;
    assign excs[3] = ebreak;
    assign excs[8] = (_csr_file.priv_level == 2'b00) && ecall;
    assign excs[9] = (_csr_file.priv_level == 2'b10) && ecall;
    assign excs[11] = (_csr_file.priv_level == 2'b11) && ecall;

    // Instruction fetch
    logic [55:0] program_counter;
    logic [55:0] next_pc;
    logic can_fetch_next;
    logic mmu_fetch_in_progress;
    logic can_retire;
    reg did_fetch;
    assign input_instruction_request = 1;
    assign can_fetch_next = 
        input_instruction_valid 
        && (input_data_valid || !input_data_request) 
        && (output_data_complete || !output_data_request)
        && !mmu_fetch_in_progress;
    assign can_retire = did_fetch && !mmu_fetch_in_progress;
    assign instruction_address = program_counter;
    always_ff @ (posedge phi1) begin
        did_fetch <= can_fetch_next;
        if (rst) begin 
            program_counter <= 0;
        end
        else
            program_counter <= next_pc;
    end
    always_ff @ (posedge phi2) begin
        if (rst) begin
            _csr_file.priv_level <= 2'b11;
            next_pc <= 0;
        end
        else if (can_retire) begin
            if (do_jump || take_trap || decoded.mret || decoded.sret) next_pc <= alu_result[55:0] & ~'h3;
            else next_pc <= program_counter + 4;
        end
    end

    // Instruction decode
    logic decoded_illegal;
    logic ebreak;
    logic ecall;
    decoded_instruction decoded;
    decoder instruction_decode(
        .instruction(input_instruction),
        .decoded(decoded),
        .illegal_instruction(decoded_illegal),
        .ebreak(ebreak),
        .ecall(ecall)
    );

    // CSR file
    logic [63:0] csr_read;
    logic csr_exception;
    csr_file _csr_file(
        .phi2(phi2),
        .rst(rst),
        .read(decoded.csr_read),
        .write(decoded.csr_write),
        .take_trap(take_trap),
        .trap_to_s(trap_to_s),
        .trap_cause(trap_cause),
        .program_counter(program_counter),
        .mret(decoded.mret),
        .sret(decoded.sret),
        .csr_addr(input_instruction[31:20]),
        .data_in(alu_result),
        .data_out(csr_read),
        .invalid(csr_exception)
    );

    // trap handling
    trap_handler _trap_handler(
        .priv(_csr_file.priv_level),
        .e_pending(excs),
        .i_pending(_csr_file.mip),
        .mie(_csr_file.mie),
        .mie_global(_csr_file.mstatus[3]),
        .sie(_csr_file.sie),
        .sie_global(_csr_file.mstatus[1]),
        .mideleg(_csr_file.mideleg),
        .medeleg(_csr_file.medeleg),
        .take_trap(take_trap),
        .trap_to_s(trap_to_s),
        .trap_cause(trap_cause)
    );

    // Register read
    logic [63:0] reg_read_values [0:1];
    logic [63:0] reg_wb_value;
    register_file reg_file(
        .phi1(phi1),
        .phi2(phi2),
        .reg_read_addrs(decoded.reg_read_addrs),
        // don't wb if taking trap or cant reture
        .reg_wb_addr(take_trap || !can_retire ? 0 : decoded.reg_wb_addr),
        .reg_read_values(reg_read_values),
        .reg_wb_value(reg_wb_value)
    );

    // Execute / ALU
    logic [63:0] alu_result;
    logic do_jump;
    logic [63:0] operand1;
    logic [63:0] operand2;
    always_comb if (take_trap) begin
        operand1 = {tvec[63:2], 2'b0};
        operand2 = (tvec[1:0] == 0) ? 0 : (trap_cause << 2);
    end
    else if (decoded.mret) begin
        operand1 = _csr_file.mepc;
        operand2 = 0;
    end
    else if (decoded.sret) begin
        operand1 = _csr_file.sepc;
        operand2 = 0;
    end
    else if (decoded.csr_write) begin
        operand1 = (input_instruction[13:12] == 2'b01) ? 0 : csr_read;
        operand2 = input_instruction[14] ? {59'b0, decoded.reg_read_addrs[0]} : reg_read_values[0];
    end
    else begin
        operand1 = decoded.use_pc ? {8'b0, program_counter} : reg_read_values[0];
        operand2 = decoded.use_imm ? decoded.immediate : reg_read_values[1];
    end
    alu _alu(
        .operand1(operand1),
        .operand2(operand2),
        .operation(decoded.alu_op),
        .modify(decoded.alu_modify),
        .cast_word(decoded.cast_word),
        .result(alu_result)
    );
    branch_resolver _branch_resolver(
        .branch(decoded.branch),
        .jump(decoded.jump),
        .branch_cond(decoded.branch_cond),
        .operand1(reg_read_values[0]),
        .operand2(reg_read_values[1]),
        .do_jump(do_jump)
    );

    // Memory access
    wire [63:0] data_fetched_by_mmu;
    mmu _mmu (
        .phi1(phi1),
        .phi2(phi2),
        .rst(rst),
        .translation_enable(0),
        .satp(_csr_file.satp),
        .read_rq_from_cpu(decoded.data_read),
        .write_rq_from_cpu(decoded.data_write),
        .addr_from_cpu(alu_result[55:0]),
        .data_from_cpu(reg_read_values[1]),
        .data_to_cpu(data_fetched_by_mmu),
        .stop_execution(mmu_fetch_in_progress),

        .data_from_mem(input_data),
        .data_to_mem(output_data),
        .addr_to_mem(data_address),
        .read_rq_to_memory(input_data_request),
        .write_rq_to_memory(output_data_request)
    );
    assign data_size = decoded.data_size;
    assign input_data_unsigned = decoded.read_unsigned;

    // Register write
    assign reg_wb_value = decoded.jump ? 
        {8'b0, program_counter + 4}
        : (decoded.data_read ? 
            data_fetched_by_mmu
            : decoded.csr_read ? 
                csr_read
                : alu_result
        );
endmodule