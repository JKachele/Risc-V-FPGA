/*************************************************
 *File----------errno.c
 *Project-------Risc-V-FPGA
 *Author--------Justin Kachele
 *Created-------Tuesday Nov 18, 2025 19:19:10 UTC
 *License-------GNU GPL-3.0
 ************************************************/

// Sometimes __errno is not linked, here is a dummy replacement.
// Note that __errno is a function that returns a pointer to the
// actual __errno (this is for multithreading). Made me bang my 
// head to the wall (and made tinyraytracer crash because powf()
// was *calling* __errno).

int* __errno()  {
   static int val = 0;
   return &val;
}
