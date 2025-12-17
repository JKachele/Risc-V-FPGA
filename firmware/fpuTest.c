/*  fpu_test.c
 *  Test suite for a 32‑bit floating‑point unit (IEEE‑754 single precision).
 *  It verifies add, sub, mul and int↔float conversions and the rounding behaviour.
 *
 *  Compile:   gcc -std=c11 -Wall -Wextra -O2 fpu_test.c -o fpu_test
 *  Run:       ./fpu_test
 */

#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <stdbool.h>
#include <inttypes.h>

/* --------------------------------------------------------------------- */
/* Helper: view a float as its 32‑bit pattern */
static uint32_t float_bits(float f)
{
        union { float f; uint32_t u; } u = { .f = f };
        return u.u;
}

/* Helper: compare two floats with a tolerance expressed in ULPs (units in last place). */
static bool almost_equal_ulps(float a, float b, int maxULPs)
{
        /* NaNs and infinities are compared directly */
        if (isnan(a) || isnan(b)) return false;
        if (isinf(a) || isinf(b)) return a == b;

        int32_t ia = (int32_t)float_bits(a);
        int32_t ib = (int32_t)float_bits(b);

        /* Make lexicographic ordering of sign‑magnitude */
        if (ia < 0) ia = 0x80000000 - ia;
        if (ib < 0) ib = 0x80000000 - ib;

        int32_t diff = ia - ib;
        if (diff < 0) diff = -diff;
        return diff <= maxULPs;
}

/* --------------------------------------------------------------------- */
/* Test case description */
typedef struct {
        const char *name;
        bool (*func)(void);
} test_case_t;

/* --------------------------------------------------------------------- */
/* Individual test functions                                            */

static bool test_addition(void)
{
        /* Simple exact case */
        float a = 1.5f, b = 2.25f;
        float r = a + b;
        if (!almost_equal_ulps(r, 3.75f, 0)) {
                // printf("FAIL add exact: %.8g + %.8g = %.8g, expected 3.75\n", a, b, r);
                printf("FAIL add exact: %f + %f = %f, expected 3.75\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 + 2^-25 cannot be represented exactly,
           should round to 1.0 (nearest‑even). */
        a = 1.0f;
        b = ldexpf(1.0f, -25);          // 2^-25
        r = a + b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                // printf("FAIL add rounding: 1.0 + 2^-25 = %.8g, expected 1.0\n", r);
                printf("FAIL add rounding: 1.0 + 2^-25 = %f, expected 1.0\n", r);
                return false;
        }

        /* Large magnitude – check overflow to +inf */
        a = 3.4e38f;    // close to FLT_MAX
        b = 3.4e38f;
        r = a + b;
        if (!isinf(r) || r < 0) {
                // printf("FAIL add overflow: %e + %e = %e, expected +inf\n", a, b, r);
                printf("FAIL add overflow: %f + %f = %f, expected +inf\n", a, b, r);
                return false;
        }

        return true;
}

static bool test_subtraction(void)
{
        /* Exact case */
        float a = 5.0f, b = 2.5f;
        float r = a - b;
        if (!almost_equal_ulps(r, 2.5f, 0)) {
                // printf("FAIL sub exact: %.8g - %.8g = %.8g, expected 2.5\n", a, b, r);
                printf("FAIL sub exact: %f - %f = %f, expected 2.5\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 - 2^-25 should round back to 1.0 */
        a = 1.0f;
        b = ldexpf(1.0f, -25);
        r = a - b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                // printf("FAIL sub rounding: 1.0 - 2^-25 = %.8g, expected 1.0\n", r);
                printf("FAIL sub rounding: 1.0 - 2^-25 = %f, expected 1.0\n", r);
                return false;
        }

        /* Underflow to subnormal → zero */
        a = ldexpf(1.0f, -126);   // smallest normal: 2^-126
        b = a;
        r = a - b;
        if (r != 0.0f) {
                // printf("FAIL sub underflow: %e - %e = %.8g, expected 0.0\n", a, b, r);
                printf("FAIL sub underflow: %f - %f = %f, expected 0.0\n", a, b, r);
                return false;
        }

        return true;
}

static bool test_multiplication(void)
{
        /* Exact case */
        float a = 1.25f, b = 0.8f;
        float r = a * b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                // printf("FAIL mul exact: %.8g * %.8g = %.8g, expected 1.0\n", a, b, r);
                printf("FAIL mul exact: %f * %f = %f, expected 1.0\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 * (1 + 2^-24) rounds to 1.0 (nearest‑even) */
        a = 1.0f;
        b = 1.0f + ldexpf(1.0f, -24);
        r = a * b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                // printf("FAIL mul rounding: 1 * (1+2^-24) = %.8g, expected 1.0\n", r);
                printf("FAIL mul rounding: 1 * (1+2^-24) = %f, expected 1.0\n", r);
                return false;
        }

        /* Overflow to +inf */
        a = 3.4e38f;   // near FLT_MAX
        b = 2.0f;
        r = a * b;
        if (!isinf(r) || r < 0) {
                // printf("FAIL mul overflow: %e * %e = %e, expected +inf\n", a, b, r);
                printf("FAIL mul overflow: %f * %f = %f, expected +inf\n", a, b, r);
                return false;
        }

        return true;
}

static bool test_conversion_int_float(void)
{
        /* int → float → int round‑trip */
        int32_t ints[] = { -123456789, -1, 0, 1, 123456789, INT32_MAX, INT32_MIN };
        size_t n = sizeof(ints)/sizeof(ints[0]);

        for (size_t i = 0; i < n; ++i) {
                float f = (float)ints[i];
                int32_t back = (int32_t)f;   // truncates toward zero per C standard

                /* For values that fit exactly in the mantissa (24 bits) the round‑trip must succeed.
                   Larger magnitudes may lose low‑order bits – we allow a deviation of 1 ULP. */
                if (fabsf(ints[i]) <= (float)(1 << 24)) {
                        if (back != ints[i]) {
                                // printf("FAIL int→float→int exact: %d → %g → %d\n",
                                // ints[i], f, back);
                                printf("FAIL int→float→int exact: %d → %f → %d\n",
                                                ints[i], f, back);
                                return false;
                        }
                } else {
                        /* Compare using ULP distance between the two floats */
                        float f_original = (float)ints[i];
                        float f_back     = (float)back;
                        if (!almost_equal_ulps(f_original, f_back, 1)) {
                                // printf("FAIL int→float→int inexact: %d → %g → %d (ULP diff >1)\n",
                                //         ints[i], f, back);
                                printf("FAIL int→float→int inexact: %d → %f → %d (ULP diff >1)\n",
                                                ints[i], f, back);
                                return false;
                        }
                }
        }

        /* float → int tests – check truncation and rounding edge cases */
        struct {
                float f;
                int32_t expected;
        } conv[] = {
                {  1.9f,  1 },
                { -1.9f, -1 },
                {  2.0f,  2 },
                { -2.0f, -2 },
                {  0.0f,  0 },
                {  1.5e7f, 15000000 },           // exact integer representable
                {  1.5e8f, 150000000 },          // not all low bits representable – truncates
        };

        for (size_t i = 0; i < sizeof(conv)/sizeof(conv[0]); ++i) {
                int32_t ix = (int32_t)conv[i].f;
                if (ix != conv[i].expected) {
                        // printf("FAIL float→int: %g -> %d, expected %d\n",
                        //         conv[i].f, ix, conv[i].expected);
                        printf("FAIL float→int: %f -> %d, expected %d\n",
                                        conv[i].f, ix, conv[i].expected);
                        return false;
                }
        }

        return true;
}

/* --------------------------------------------------------------------- */

int main(void)
{
        test_case_t tests[] = {
                { "Addition",                test_addition },
                { "Subtraction",             test_subtraction },
                { "Multiplication",          test_multiplication },
                { "Int↔Float Conversion",    test_conversion_int_float },
        };

        size_t passed = 0;
        size_t total  = sizeof(tests)/sizeof(tests[0]);

        for (size_t i = 0; i < total; ++i) {
                // printf("Running %-24s ... ", tests[i].name);
                printf("Running %s ... ", tests[i].name);
                // fflush(stdout);
                bool ok = tests[i].func();
                printf("%s\n", ok ? "PASS" : "FAIL");
                if (ok) ++passed;
        }

        // printf("\nSummary: %zu/%zu tests passed.\n", passed, total);
        printf("\nSummary: %d/%d tests passed.\n", passed, total);
        return (passed == total) ? 0 : 1;
}

