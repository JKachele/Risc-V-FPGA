.global main
.section .text
main:
machine:
        sw      ra, (sp)
        la      t0, supervisor
        csrw    mepc, t0
        la      t1, m_trap
        csrw    mtvec, t1
        li      t2, 0x1800
        csrc    mstatus, t2
        li      t3, 0x800
        csrs    mstatus, t3
        li      t4, 0x100
        csrs    medeleg, t4
        call    printMachine
        mret

m_trap:
        csrr    t0, mepc
        csrr    t1, mcause
        # la      t2, supervisor
        # csrw    mepc, t2
        call    printMTrap
        mret

supervisor:
        la      t0, user
        csrw    sepc, t0
        la      t1, s_trap
        csrw    stvec, t1
        call    printSupervisor
        sret

s_trap:
        csrr    t0, sepc
        csrr    t1, scause
        call    printSTrap
        ecall
        sret

user:
        csrr    t0, instret
        call    printUser
        ecall
        lw      ra, (sp)
        ret

.section .data
Hello:
        .ascii "Hello, World!\n"
