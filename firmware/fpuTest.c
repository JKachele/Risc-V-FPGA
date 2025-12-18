/*  fpu_test.c
 *  Test suite for a 32‑bit floating‑point unit (IEEE‑754 single precision).
 *  It verifies add, sub, mul and int↔float conversions and the rounding behaviour.
 *
 *  Compile:   gcc -std=c11 -Wall -Wextra -O2 fpu_test.c -o fpu_test
 *  Run:       ./fpu_test
 */

#include "libs/printf.h"
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
                printf("FAIL add exact: %.8g + %.8g = %.8g, expected 3.75\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 + 2^-25 cannot be represented exactly,
           should round to 1.0 (nearest‑even). */
        a = 1.0f;
        b = ldexpf(1.0f, -25);          // 2^-25
        r = a + b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                printf("FAIL add rounding: 1.0 + 2^-25 = %.8g, expected 1.0\n", r);
                return false;
        }

        /* Large magnitude – check overflow to +inf */
        a = 3.4e38f;    // close to FLT_MAX
        b = 3.4e38f;
        r = a + b;
        if (!isinf(r) || r < 0) {
                printf("FAIL add overflow: %e + %e = %e, expected +inf\n", a, b, r);
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
                printf("FAIL sub exact: %.8g - %.8g = %.8g, expected 2.5\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 - 2^-25 should round back to 1.0 */
        a = 1.0f;
        b = ldexpf(1.0f, -25);
        r = a - b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                printf("FAIL sub rounding: 1.0 - 2^-25 = %.8g, expected 1.0\n", r);
                return false;
        }

        /* Underflow to subnormal → zero */
        a = ldexpf(1.0f, -126);   // smallest normal: 2^-126
        b = a;
        r = a - b;
        if (r != 0.0f) {
                printf("FAIL sub underflow: %e - %e = %.8g, expected 0.0\n", a, b, r);
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
                printf("FAIL mul exact: %.8g * %.8g = %.8g, expected 1.0\n", a, b, r);
                return false;
        }

        /* Inexact case – 1.0 * (1 + 2^-24) rounds to 1.0 (nearest‑even) */
        a = 1.0f;
        b = 1.0f + ldexpf(1.0f, -24);
        r = a * b;
        if (!almost_equal_ulps(r, 1.0f, 0)) {
                printf("FAIL mul rounding: 1 * (1+2^-24) = %.8g, expected 1.0\n", r);
                return false;
        }

        /* Overflow to +inf */
        a = 3.4e38f;   // near FLT_MAX
        b = 2.0f;
        r = a * b;
        if (!isinf(r) || r < 0) {
                printf("FAIL mul overflow: %e * %e = %e, expected +inf\n", a, b, r);
                return false;
        }

        return true;
}

/* --------------------------------------------------------------------- */
/* Division tests – exact results, rounding, overflow/underflow,       */
/* special‑value handling, and divide‑by‑zero cases.                     */
static bool test_division(void)
{
        /* -------------------------------------------------------------
           1) Exact division – result can be represented exactly.
           ------------------------------------------------------------- */
        {
                float a = 9.0f, b = 3.0f;
                float r = a / b;
                if (!almost_equal_ulps(r, 3.0f, 0)) {
                        printf("FAIL div exact: %.8g / %.8g = %.8g, expected 3.0\n",
                                        a, b, r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           2) Inexact division – requires rounding to nearest‑even.
           1.0 / (1 + 2^-23) is slightly less than 1.0; the closest
           representable even float is 0.99999988 (0x3f7ffffe), which is the
           “nearest‑even” rounding.
           ------------------------------------------------------------- */
        {
                float a = 1.0f;
                /* 1 + 2⁻²³ is the next float after 1.0 */
                float b = 1.0f + ldexpf(1.0f, -23);   /* ≈1.00000011920928955078f */
                float r = a / b;                     /* ≈0.9999998807907104f */

                /* Expected value = 0.99999988f (the nearest‑even float). */
                uint32_t expected = 0x3f7ffffeU;          // reinterpret bits as float
                union { uint32_t u; float f; } u = { .u = expected };
                if (!almost_equal_ulps(r, u.f, 0)) {
                        printf("FAIL div rounding: 1 / (1+2^-25) = %.8g, expected %.8g\n",
                                        r, u.f);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           3) Overflow to +inf – divisor is tiny, numerator is large.
           ------------------------------------------------------------- */
        {
                float a = 3.4e38f;       // close to FLT_MAX
                float b = ldexpf(1.0f, -126);   // smallest normal = 2⁻¹²⁶
                float r = a / b;
                if (!isinf(r) || r < 0) {
                        printf("FAIL div overflow: %e / %e = %e, expected +inf\n",
                                        a, b, r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           4) Underflow to subnormal → zero.
           Divide the smallest normal number by a large power‑of‑two.
           ------------------------------------------------------------- */
        {
                float a = ldexpf(1.0f, -126);   // 2⁻¹²⁶  (smallest normal)
                float b = ldexpf(1.0f,  150);   // 2¹⁵⁰  (huge)
                float r = a / b;
                if (r != 0.0f) {
                        printf("FAIL div underflow: %e / %e = %.8g, expected 0.0\n",
                                        a, b, r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           5) Division by zero – numerator non‑zero.
           According to IEEE‑754 this yields +inf or -inf depending on
           the sign of the numerator.
           ------------------------------------------------------------- */
        {
                float a =  5.0f;
                float b =  0.0f;                 // +0
                float r = a / b;
                if (!isinf(r) || r < 0) {
                        printf("FAIL div by +0: %g / +0 = %g, expected +inf\n", a, r);
                        return false;
                }

                a = -5.0f;
                r = a / b;                       // -5 / +0 -> -inf
                if (!isinf(r) || r > 0) {
                        printf("FAIL div by +0 (neg): %g / +0 = %g, expected -inf\n", a, r);
                        return false;
                }

                /* +0 / +0 and -0 / +0 produce NaN */
                a =  0.0f;
                r = a / b;
                if (!isnan(r)) {
                        printf("FAIL 0/0: %g / +0 = %g, expected NaN\n", a, r);
                        return false;
                }

                a = -0.0f;
                r = a / b;
                if (!isnan(r)) {
                        printf("FAIL -0/0: %g / +0 = %g, expected NaN\n", a, r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           6) Division involving infinities.
           INF / finite  -> INF (sign follows the signs of the operands)
           finite / INF -> 0
           ------------------------------------------------------------- */
        {
                float inf = INFINITY;
                float a  =  123.0f;
                float r  = inf / a;
                if (!isinf(r) || r < 0) {
                        printf("FAIL INF / finite: INF / %g = %g, expected +inf\n", a, r);
                        return false;
                }

                a = -123.0f;
                r = inf / a;
                if (!isinf(r) || r > 0) {
                        printf("FAIL INF / negative: INF / %g = %g, expected -inf\n", a, r);
                        return false;
                }

                r = a / inf;                     // finite / INF -> 0 (preserves sign)
                if (r != 0.0f) {
                        printf("FAIL finite / INF: %g / INF = %g, expected 0\n", a, r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           7) Division with NaNs – result must be NaN.
           ------------------------------------------------------------- */
        {
                float nan = NAN;
                float a   = 3.14f;
                float r   = a / nan;
                if (!isnan(r)) {
                        printf("FAIL finite / NaN: %g / NaN = %g, expected NaN\n", a, r);
                        return false;
                }

                r = nan / a;
                if (!isnan(r)) {
                        printf("\n%x\n", *(long*)&nan);
                        printf("\n%x\n", *(long*)&r);
                        printf("FAIL NaN / finite: NaN / %g = %g, expected NaN\n", a, r);
                        return false;
                }

                r = nan / nan;
                if (!isnan(r)) {
                        printf("FAIL NaN / NaN: NaN / NaN = %g, expected NaN\n", r);
                        return false;
                }
        }

        /* -------------------------------------------------------------
           All division tests passed.
           ------------------------------------------------------------- */
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
                                printf("FAIL int→float→int exact: %d → %g → %d\n",
                                ints[i], f, back);
                                return false;
                        }
                } else {
                        /* Compare using ULP distance between the two floats */
                        float f_original = (float)ints[i];
                        float f_back     = (float)back;
                        if (!almost_equal_ulps(f_original, f_back, 1)) {
                                printf("FAIL int→float→int inexact: %d → %g → %d (ULP diff >1)\n",
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
                        printf("FAIL float→int: %g -> %d, expected %d\n",
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
                { "Division",                test_division },
                { "Int ↔ Float Conversion",  test_conversion_int_float },
        };

        size_t passed = 0;
        size_t total  = sizeof(tests)/sizeof(tests[0]);

        for (size_t i = 0; i < total; ++i) {
                printf("Running %-24s ... ", tests[i].name);
                // fflush(stdout);
                bool ok = tests[i].func();
                printf("%s\n", ok ? "PASS" : "FAIL");
                if (ok) ++passed;
        }

        printf("\nSummary: %zu/%zu tests passed.\n", passed, total);
        return (passed == total) ? 0 : 1;
}

