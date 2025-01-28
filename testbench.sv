`include "cpu.sv"

module testbench;
    logic phi1;
    logic phi2;
    logic rst;

    wire [55:0] data_address;
    wire [1:0] data_size;
    logic [63:0] input_data;
    wire input_data_unsigned;
    wire input_data_request;
    logic input_data_valid;
    wire [63:0] output_data;
    wire output_data_request;
    logic output_data_complete;
    wire [55:0] instruction_address;
    logic [31:0] input_instruction;
    wire input_instruction_request;
    logic input_instruction_valid;

    cpu test_cpu(
        .phi1(phi1),
        .phi2(phi2),
        .rst(rst),
        .data_address(data_address),
        .data_size(data_size),
        .input_data(input_data),
        .input_data_unsigned(input_data_unsigned),
        .input_data_request(input_data_request),
        .input_data_valid(input_data_valid),
        .output_data(output_data),
        .output_data_request(output_data_request),
        .output_data_complete(output_data_complete),
        .instruction_address(instruction_address),
        .input_instruction(input_instruction),
        .input_instruction_request(input_instruction_request),
        .input_instruction_valid(input_instruction_valid)
    );

    logic [63:0] ram [0:134217728];

    int fd;
    int ix = 0;
    logic [63:0] tmp;
    initial begin
        // get rom contents
        fd = $fopen("programming/rom", "rb");
        if (fd == 0) begin
            $display("Couldnt open file `rom`");
            $finish();
        end

        while (!$feof(fd)) begin
            $fread(tmp, fd);
            tmp = {tmp[7:0], tmp[15:8], tmp[23:16], tmp[31:24], tmp[39:32], tmp[47:40], tmp[55:48], tmp[63:56]};
            ram[ix] = tmp;
            ix = ix + 1;
        end

        $fclose(fd);

        // reset
        phi1 = 0;
        phi2 = 0;
        rst = 1;
        #10 phi2 = 1;
        #10 phi2 = 0;
        #10 phi1 = 1;
        #10 phi1 = 0;
        rst = 0;

        # 1000

        // run
        while (1) begin
            #10  phi2 = 1;
            #100 phi2 = 0;
            #10  phi1 = 1;
            #100 phi1 = 0;
        end
    end

    always_comb begin
        assign input_instruction = {
            ram[instruction_address[30:3]] 
            >> ({5'b0, instruction_address[2]} << 5)
        }[31:0];

        case (data_size)
            0: begin 
                logic [7:0] unsigned_read = {
                    ram[data_address[30:3]] 
                    >> ({3'b0, data_address[2:0]} << 3)
                }[7:0];
                input_data = { 
                    {56{unsigned_read[7] && !input_data_unsigned}},
                    unsigned_read
                };
            end
            1: begin
                logic [15:0] unsigned_read = {
                    ram[data_address[30:3]] 
                    >> ({4'b0, data_address[2:1]} << 4)
                }[15:0];
                if (data_address[0] != 0 && test_cpu.input_data_request) begin
                    $display("MISALIGNED 16 %x", data_address);
                end
                input_data = { 
                    {48{unsigned_read[15] && !input_data_unsigned}},
                    unsigned_read
                };
            end
            2: begin
                logic [31:0] unsigned_read = {
                    ram[data_address[30:3]]
                    >> ({5'b0, data_address[2]} << 5)
                }[31:0];
                input_data = { 
                    {32{unsigned_read[31] && !input_data_unsigned}},
                    unsigned_read
                };
            end
            3: begin
                input_data = ram[data_address[30:3]];
            end
        endcase
    end

    always @(posedge phi1) begin
        //if (test_cpu.decoded.use_imm && instruction_address > 544) begin
        //    $display("%d", $signed(test_cpu.decoded.immediate));
        //end
        //$display("%x %x %x", test_cpu._alu.operand1, test_cpu._alu.operand2, test_cpu._alu.result);
        //$display("sp %x", test_cpu.reg_file.file[2]);
        //$display("");
        if (input_data_request) $display("rd @ %x : %x", data_address, input_data);
        if (output_data_request) $display("wr @ %x : %x", data_address, output_data);
        //$display("%x %x : %b", instruction_address, input_instruction, test_cpu._mmu.table_walker_fsm);
    end

    always_ff @(posedge phi2) if (output_data_request) begin
        if (data_address[55:31] == 0) begin 
            logic [5:0] shift;
            logic [63:0] mask;
            logic [63:0] preread;

            case (data_size)
                0: begin
                    shift = {3'b0, data_address[2:0]} << 3;
                    mask = 64'hFF << shift;
                end
                1: begin
                    shift = {4'b0, data_address[2:1]} << 4;
                    mask = 64'hFFFF << shift;
                end
                2: begin
                    shift = {5'b0, data_address[2]} << 5;
                    mask = 64'hFFFFFFFF << shift;
                end
                3: begin
                    shift = 6'b0;
                    mask = 64'hFFFFFFFFFFFFFFFF;
                end
            endcase

            preread = ram[data_address[30:3]] & ~mask;
            ram[data_address[30:3]] <= preread | ((output_data << shift) & mask);

            //#1 $display("%x from %x (%x)", ram[data_address[30:3]], data_address, data_size);
            //$display("");
        end
        else if (data_address == 56'hFFFFFFFFFFFFF8) begin
            $finish();
        end
        else if (data_address == 56'hFFFFFFFFFFFFFC) begin
            $write("%s", output_data[7:0]);
        end
        else if (data_address == 56'hFFFFFFFFFFFFF0) begin
            $display("%d", $signed(output_data));
        end
    end

    assign input_data_valid = 1;
    assign input_instruction_valid = 1;
    assign output_data_complete = 1;
endmodule