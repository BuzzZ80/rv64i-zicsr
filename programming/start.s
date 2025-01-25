.section .boot
.global _start

.equ MTVEC, 0x305
.equ MEPC, 0x341
.equ MCAUSE, 0x342
.equ MSCRATCH, 0x340
.equ MSTATUS, 0x300

_start:
    # initialize stack
    la sp, _sstack
    
    # setup mtvec
    la a5, trap_handler
    csrw MTVEC, a5

    #start user mode processes
    la a5, usermode_start
    csrw MEPC, a5
    mret

usermode_start:
    #jump to main
    jal ra, main
    # signal ends simulation
    sd x0, -8(x0)
    # loop-halt cpu just in case ;3
    haltloop:
    beq x0, x0, haltloop

error_msg: .string "\nUH OH!!! :3\n\n"
.align 4
.local trap_handler
trap_handler:
    addi sp, sp, -24
    sd a1, 16(sp)
    sd a0, 8(sp)
    sd ra, 0(sp)

    la a0, error_msg
    la a1, prints
    jalr ra, a1

    ld a1, 16(sp)
    ld a0, 8(sp)
    ld ra, 0(sp)
    addi sp, sp, 8

    csrrw a0, MEPC, a0
    addi a0, a0, 4
    csrrw a0, MEPC, a0
    mret