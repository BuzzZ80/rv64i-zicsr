module register_file(
    input logic phi1,
    input logic phi2,
    input logic [4:0] reg_read_addrs [0:1],
    input logic [4:0] reg_wb_addr,
    input logic [63:0] reg_wb_value,
    output logic [63:0] reg_read_values [0:1]
);
    logic [63:0] file [1:31];

    always_comb 
        for (int i = 0; i < 2; i++)
            if (reg_read_addrs[i] == 0)
                reg_read_values[i] = 0;
            else
                reg_read_values[i] = file[reg_read_addrs[i]];
    
    always @ (posedge phi2)
        if (reg_wb_addr != 0)
            file[reg_wb_addr] <= reg_wb_value;
endmodule