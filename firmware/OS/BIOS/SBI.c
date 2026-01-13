/*************************************************
 *File----------SBI.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Jan 13, 2026 14:04:04 UTC
 *License-------GNU GPL-3.0
 ************************************************/

#include "sbi.h"

extern void _putchar(char c);

// EID #0x01
long sbi_console_putchar(int ch) {
        _putchar(ch);
        return SBI_SUCCESS;
}

// EID #0x08
void sbi_shutdown(void) {
        asm volatile ("ebreak\n");
}

struct sbiret sbi_debug_console_write(u32 num_bytes, char *base_addr_lo, char *base_addr_hi) {
        for (int i = 0; i < num_bytes; i++) {
                _putchar(base_addr_lo[i]);
        }
        return (struct sbiret){.error = SBI_SUCCESS, .uvalue = num_bytes};
}

// EID #0x4442434E
struct sbiret dbcn(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid) {
        struct sbiret ret = {0};
        switch (fid) {
                case 0x0:
                        ret = sbi_debug_console_write(arg0, (char *)arg1, (char *)arg2);
                        break;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}

struct sbiret sbi_handler(long arg0, long arg1, long arg2, long arg3, long arg4,
                       long arg5, long fid, long eid) {
        struct sbiret ret = {0};
        switch (eid) {
                case 0x01:
                        ret.error = sbi_console_putchar((char)arg0);
                        break;
                case 0x08:
                        sbi_shutdown();
                        break;
                case 0x4442434E:
                        ret = dbcn(arg0, arg1, arg2, arg3, arg4, arg5, fid);
                        break;
                default:
                        ret.error = SBI_ERR_NOT_SUPPORTED;
        }
        return ret;
}

void mtrap_handler(struct trap_frame *f) {
        struct sbiret ret;
        ret = sbi_handler(f->a0, f->a1, f->a2, f->a3, f->a4, f->a5, f->a6, f->a7);
        f->a0 = ret.error;
        f->a1 = ret.uvalue;
}

