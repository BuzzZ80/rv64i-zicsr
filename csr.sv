module csr_file(
    input logic phi2,
    input logic rst,
    input logic read,
    input logic write,
    input logic take_trap,
    input logic trap_to_s,
    input logic [63:0] trap_cause,
    input logic [63:0] program_counter,
    input logic mret,
    input logic sret,
    input logic [11:0] csr_addr,
    input logic [63:0] data_in,
    output logic [63:0] data_out,
    output logic invalid
);
    logic [63:0] time_buff;

    // supervisor csrs
    wire [31:0] sstatus_mask = 32'b11000000000100100010;
    logic [15:0] sie;
    logic [63:0] stvec;
    logic [63:0] senvcfg;
    logic [63:0] sscratch;
    logic [63:0] sepc;
    logic [63:0] scause;
    logic [63:0] stval;
    logic [63:0] satp;
    logic [63:0] scontext;
    // machine registers
    wire [63:0] mvendorid = 64'b0;
    wire [63:0] marchid = 64'b0;
    wire [63:0] mimpid = 64'b0;
    wire [63:0] mhartid = 64'b0;
    wire [63:0] mconfigptr = 64'b0;
    logic [31:0] mstatus;
    wire [63:0] misa = {2'b10, 36'b0, 26'b00000101000000000100000000};
    logic [15:0] medeleg;
    logic [15:0] mideleg;
    logic [15:0] mie;
    logic [63:0] mtvec;
    logic [63:0] mscratch;
    logic [63:0] mepc;
    logic [63:0] mcause;
    logic [63:0] mtval;
    logic [15:0] mip;
    logic [63:0] mtinst;
    logic [63:0] menvcfg;
    logic [63:0] pmpcfg [0:7];
    logic [53:0] pmpaddr [0:63];
    logic [63:0] mcontext;
    logic [63:0] mcycle;
    logic [63:0] minstret;

    logic [1:0] priv_level; 

    wire invalid_access = (read && (priv_level < csr_addr[9:8])) 
        || (write && (priv_level < csr_addr[9:8] || csr_addr[11:10] == 2'b11));
    assign invalid = invalid_access;

    // CSR reads
    always_comb if (read && !invalid_access) casez (csr_addr)
        // read/write
        'h100: data_out = {30'b0, 2'b10, mstatus & sstatus_mask};
        'h104: data_out = {48'b0, sie};
        'h105: data_out = stvec;
        'h106: data_out = {61'b0, 3'b111}; // scounteren
        'h10A: data_out = senvcfg;
        'h140: data_out = sscratch;
        'h141: data_out = sepc;
        'h142: data_out = scause;
        'h143: data_out = stval;
        'h144: data_out = {48'b0, mip & mideleg};
        'h180: data_out = satp;
        'h300: data_out = {28'b0, 4'b1010, mstatus};
        'h301: data_out = misa;
        'h302: data_out = {48'b0, medeleg};
        'h303: data_out = {48'b0, mideleg};
        'h304: data_out = {48'b0, mie};
        'h305: data_out = mtvec;
        'h306: data_out = {61'b0, 3'b111}; // mcounteren
        'h30A: data_out = menvcfg;
        'h340: data_out = mscratch;
        'h341: data_out = mepc;
        'h342: data_out = mcause;
        'h343: data_out = mtval;
        'h344: data_out = {48'b0, mip};
        'h34A: data_out = mtinst;
        'h3A?: data_out = csr_addr[0] ? 0 : pmpcfg[csr_addr[3:1]];
        'h3B?: data_out = {10'b0, pmpaddr[{2'b00, csr_addr[3:0]}]};
        'h3C?: data_out = {10'b0, pmpaddr[{2'b01, csr_addr[3:0]}]};
        'h3D?: data_out = {10'b0, pmpaddr[{2'b10, csr_addr[3:0]}]};
        'h3E?: data_out = {10'b0, pmpaddr[{2'b11, csr_addr[3:0]}]};
        'h5A8: data_out = scontext;
        'hB00: data_out = mcycle;
        'hB02: data_out = minstret;
        // read only
        'hC00: data_out = mcycle;
        'hC01: data_out = time_buff;
        'hC02: data_out = minstret;
        'hF11: data_out = mvendorid;
        'hF12: data_out = marchid;
        'hF13: data_out = mimpid;
        'hF14: data_out = mhartid;
        'hF15: data_out = mconfigptr;
        default: data_out = 0;
    endcase

    // exceptions, interrupts, etc idk lol
    always_ff @ (posedge phi2)
    if (take_trap) begin
        if (trap_to_s) begin
            mstatus[5] <= mstatus[1];
            mstatus[1] <= 0;
            mstatus[8] <= priv_level[0];
            priv_level <= 2'b01;

            scause <= trap_cause;
            sepc <= program_counter;
        end
        else begin
            mstatus[7] <= mstatus[3];
            mstatus[3] <= 0;
            mstatus[12:11] <= priv_level;
            priv_level <= 2'b11;

            mcause <= trap_cause;
            mepc <= program_counter;
        end
    end
    else if (mret) begin
        mstatus[3] <= mstatus[7];
        mstatus[7] <= 1;
        priv_level <= mstatus[12:11];
        mstatus[12:11] <= 2'b00;
    end
    else if (sret) begin
        mstatus[1] <= mstatus[5];
        mstatus[5] <= 1;
        priv_level <= {1'b0, mstatus[8]};
        mstatus[8] <= 0;
    end
    // CSR writes
    else if (write) casez (csr_addr)
        'h100: mstatus <= (mstatus & ~sstatus_mask) | (data_in[31:0] & sstatus_mask);
        'h104: sie <= data_in[15:0];
        'h105: begin
            if (data_in[1] == 0) stvec[1:0] <= data_in[1:0];
            stvec[63:2] <= data_in[63:2];
        end
        'h10A: senvcfg[0] <= data_in[0]; // FIOM
        'h140: sscratch <= data_in;
        'h141: sepc <= {data_in[63:2], 2'b0};
        'h142: scause <= data_in;
        'h143: stval <= data_in;
        //'h144: sip <= data_in; // unsure of how to handle writes to sip right now lmao
        'h180: if (data_in[63:60] == 8) begin
            satp[63:60] <= data_in[63:60];
            satp[21:0] <= data_in[21:0];
        end
        else if (data_in[63:60] == 0) begin 
            satp <= 0;
        end
        'h300: begin
            mstatus[1] <= data_in[1]; // SIE
            mstatus[3] <= data_in[3]; // MIE
            mstatus[5] <= data_in[5]; // SPIE
            mstatus[7] <= data_in[7]; // MPIE
            mstatus[8] <= data_in[8]; // SPP
            //MPP
            if (data_in[12:11] != 2'b10) mstatus[12:11] <= data_in[12:11];
            // TSR TW TVM MXR SUM MPRV
            mstatus[22:17] <= data_in[22:17];
        end
        'h302: medeleg <= data_in[15:0];
        'h303: mideleg <= data_in[15:0];
        'h304: mie <= data_in[15:0];
        'h305: begin
            if (data_in[1] == 0) mtvec[1:0] <= data_in[1:0];
            mtvec[63:2] <= data_in[63:2];
        end
        'h30A: menvcfg[0] <= data_in[0]; // FIOM
        'h340: mscratch <= data_in;
        'h341: mepc <= {data_in[63:2], 2'b0};
        'h342: mcause <= data_in;
        'h343: mtval <= data_in;
        'h344: mip <= data_in[15:0];
        'hB00: mcycle <= data_in;
        'hB02: minstret <= data_in;
    endcase
endmodule