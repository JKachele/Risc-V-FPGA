.global main
.section .text
main:
        la      t0, num1
        fld     ft0, 0(t0)
        la      t0, num2
        fld     ft1, 0(t0)
        la      t0, num3
        fld     ft2, 0(t0)

        fmul.d  ft3, ft0, ft1
        fadd.d  ft3, ft3, ft2

        fmadd.d ft4, ft0, ft1, ft2

        la      t0, num4
        fld     ft0, 0(t0)
        la      t0, num5
        fld     ft1, 0(t0)
        la      t0, num6
        fld     ft2, 0(t0)

        fmul.d  ft5, ft0, ft1
        fadd.d  ft5, ft5, ft2

        fmadd.d ft6, ft0, ft1, ft2

        ret


.section .data
num1:
        .double 24681.538200242
num2:
        .double 59627.161672524
num3:
        .double 29919.736789149
num4:
        .double 48984.143984087
num5:
        .double 23630.6752352
num6:
        .double 97168.891921341
