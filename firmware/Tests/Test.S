.global main
.section .text
main:
        la      t0, single
        flw     ft0, 0(t0)
        la      t0, double
        fld     ft1, 0(t0)
        ret


.section .data
single:
        .float 3.141592653589793
double:
        .double 3.141592653589793
