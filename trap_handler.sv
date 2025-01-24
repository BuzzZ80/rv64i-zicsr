module trap_handler(
    input wire [1:0] priv,
    input wire [15:0] e_pending,
    input wire [15:0] i_pending,
    input wire [15:0] mie,
    input wire mie_global,
    input wire [15:0] sie,
    input wire sie_global,
    input wire [15:0] mideleg,
    input wire [15:0] medeleg,
    output logic take_trap,
    output logic trap_to_s,
    output logic [63:0] trap_cause
);
// interrupt detection
wire [15:0] m_interrupts = i_pending & mie;
wire [15:0] s_interrupts = i_pending & mideleg & mie & sie;

logic handle_int;
logic int_trap_to_s;
always_comb case (priv)
    2'b11: begin
        handle_int = mie_global && (m_interrupts != 0);
        int_trap_to_s = 0;
    end
    2'b10: begin
        handle_int = (sie_global && (s_interrupts != 0)) || ((m_interrupts & ~mideleg) != 0);
        int_trap_to_s = (sie_global && (s_interrupts != 0)) && ((m_interrupts & ~mideleg) == 0);
    end
    2'b00: begin
        handle_int = m_interrupts != 0;
        int_trap_to_s = (s_interrupts != 0) && ((m_interrupts & ~mideleg) == 0);
    end
    default: begin
        handle_int = 0;
        int_trap_to_s = 0;
    end
endcase

logic [3:0] int_cause;
logic [15:0] ints = int_trap_to_s ? s_interrupts : m_interrupts;
always_comb
if (ints[1]) int_cause = 1;
else if (ints[3]) int_cause = 3;
else if (ints[5]) int_cause = 5;
else if (ints[7]) int_cause = 7;
else if (ints[9]) int_cause = 9;
else if (ints[11]) int_cause = 11;
else if (ints[13]) int_cause = 13;
else int_cause = 0; // default case, idk what to put lol


// exception detection
wire [15:0] m_exceptions = e_pending;
wire [15:0] s_exceptions = e_pending & medeleg;

wire handle_exc = m_exceptions != 0;
wire exc_trap_to_s = (priv == 2'b11) ?  
        0
        : (s_exceptions != 0) && ((m_exceptions & ~medeleg) == 0);

logic [3:0] exc_cause;
wire [15:0] excs = e_pending & (exc_trap_to_s ? medeleg : ~medeleg);
// order is technically wrong lol :3
always_comb
if (excs[0]) exc_cause = 0;
else if (excs[1]) exc_cause = 1;
else if (excs[2]) exc_cause = 2;
else if (excs[3]) exc_cause = 3;
else if (excs[4]) exc_cause = 4;
else if (excs[5]) exc_cause = 5;
else if (excs[6]) exc_cause = 6;
else if (excs[7]) exc_cause = 7;
else if (excs[8]) exc_cause = 8;
else if (excs[9]) exc_cause = 9;
else if (excs[10]) exc_cause = 10;
else if (excs[11]) exc_cause = 11;
else if (excs[12]) exc_cause = 12;
else if (excs[13]) exc_cause = 13;
else if (excs[14]) exc_cause = 14;
else if (excs[15]) exc_cause = 15;
else exc_cause = 0;


// output
always_comb if (handle_int) begin
    take_trap = 1;
    trap_to_s = int_trap_to_s;
    trap_cause = {1'b1, 59'b0, int_cause};
end
else if (handle_exc) begin
    take_trap = 1;
    trap_to_s = exc_trap_to_s;
    trap_cause = {60'b0, exc_cause};
end
else begin
    take_trap = 0;
    trap_to_s = 0;
    trap_cause = 0;
end

endmodule