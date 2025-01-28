.section .boot
.global _start

.equ MTVEC, 0x305
.equ MEPC, 0x341
.equ MCAUSE, 0x342
.equ MSCRATCH, 0x340
.equ MSTATUS, 0x300
.equ SATP, 0x180

# cpu entry point
_start:
    # initialize stack
    la sp, _sstack
    
    # setup mtvec
    la a5, trap_handler
    csrw MTVEC, a5

    #setup satp
    li a5, 0x8000000000000100
    csrw SATP, a5

    # table points to next tables
    li a5, 0x0000000000040401
    li a6, 0x100000
    sd a5, 0(a6)

    # table points to next table
    li a5, 0x0000000000040801
    li a6, 0x101000
    sd a5, 0(a6)

    # table maps vpn 0 to ppn 103
    li a5, 0x0000000000040C0F
    li a6, 0x102000
    sd a5, 0(a6)

    # pass some data to the usermode process
    li a5, 0xFEDCBA9876543210
    li a6, 0x103000
    sd a5, 0(a6)

    #start user mode process
    la a5, usermode_start
    csrw MEPC, a5
    li sp, 0xFF8
    mret

usermode_start:
    ld a0, 0(x0)
    sd a0, 8(x0)

    ecall # stop execution

# trap handling
error_msg: .string "\nExecution Terminated (trap occurred)\n\n"
.align 4
.local trap_handler
trap_handler:
    la a0, error_msg
    la a1, prints
    jalr ra, a1

    sd x0, -8(x0)
    haltloop:
    beq x0, x0, haltloop