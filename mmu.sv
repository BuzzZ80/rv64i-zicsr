module mmu(
    input wire phi1,
    input wire phi2,
    input wire rst,
    input wire translation_enable,
    input wire [63:0] satp,
    input wire read_rq_from_cpu,
    input wire write_rq_from_cpu,
    input wire [55:0] addr_from_cpu,
    input wire [63:0] data_from_cpu,
    output logic [63:0] data_to_cpu,
    output logic stop_execution,

    input logic [63:0] data_from_mem
    output logic [63:0] data_to_mem,
    output logic [55:0] addr_to_mem,
    output logic read_rq_to_memory,
    output logic write_rq_to_memory
);  
    // Table Lookaside Buffer
    reg [19:0] tlb_tags [0:127];
    reg [43:0] tlb_ppns [0:127];
    reg [8:0] tlb_flags [0:127];
    reg tlb_entry_valid [0:127];

    // finite state machine for fetching PTEs
    reg [7:0] table_walker_fsm;
    reg [1:0] i;
    reg [43:0] a;
    reg [63:0] pte;

    // halt the cpu if the FSM is fetching a PTE
    reg stop_execution_ff;
    assign stop_execution = 
        stop_execution_ff
        || tlb_miss;

    logic [8:0] vpn [0:2] = {
        addr_from_cpu[20:12],
        addr_from_cpu[29:21],
        addr_from_cpu[38:30]
    };

    logic tlb_miss = 
        translation_enable
        && (read_rq_from_cpu || write_rq_from_cpu) 
        && !tlb_entry_valid[addr_from_cpu[18:12]];

    always_ff @ (posedge phi2)
    if (rst) begin
        table_walker_fsm <= 0;
        i <= 0;
        a <= 0;
    end
    else if (tlb_miss && (table_walker_fsm == 0)) 
        table_walker_fsm <= 1;
    else 
        table_walker_fsm <= table_walker_fsm << 1;

    always_ff @ (posedge phi1)
    if (rst) begin
        pte <= 0;
        stop_execution_ff <= 0;
    end
    else if (table_walker_fsm[0]) begin
        i <=
    

    // memory interface
    assign data_to_mem = data_from_cpu;
    assign data_to_cpu = data_from_mem;
    assign write_rq_to_memory = (table_walker_fsm == 0) && write_rq_from_cpu;
    always_comb
    if (!translation_enable) begin
        addr_to_mem = addr_from_cpu;
        read_rq_to_memory = read_rq_from_cpu;
    end
    else if (table_walker_fsm == 0) begin
        addr_to_mem = {tlb_ppns[addr_from_cpu[18:12]], addr_from_cpu[11:0]};
        read_rq_to_memory = read_rq_from_cpu;
    end
    else if (table_walker_fsm[0]) begin
        addr_to_mem = {a, vpn[i], 3'b0}
        read_rq_to_memory = 1;
    end

endmodule