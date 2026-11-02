#include "gcd.h"

/* Binary GCD: remove powers of two before subtracting odd operands. */
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    if (a == 0)
        return b;
    if (b == 0)
        return a;

    unsigned shift = 0;
    while (((a | b) & 1u) == 0) {
        a >>= 1;
        b >>= 1;
        shift++;
    }

    while ((a & 1u) == 0)
        a >>= 1;

    do {
        while ((b & 1u) == 0)
            b >>= 1;

        if (a > b) {
            uint32_t tmp = a;
            a = b;
            b = tmp;
        }

        b -= a;
    } while (b != 0);

    return a << shift;
}
