#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    int passes = 0;
    while (b != 0) {
        uint32_t carry = (a & b) << 1;
        a ^= b;
        b = carry;
        passes++;
    }
    *n = passes;
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a & b) + ((a ^ b) >> 1);
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t x = a < 0 ? 0u - (uint32_t) a : (uint32_t) a;
    uint32_t y = b < 0 ? 0u - (uint32_t) b : (uint32_t) b;
    uint32_t xhi = 0, lo = 0, hi = 0;

    /* Unsigned register-pair arithmetic also handles INT32_MIN safely. */
    while (y != 0) {
        if (y & 1u) {
            uint32_t next = lo + x;
            hi += xhi + (next < lo);
            lo = next;
        }
        xhi = (xhi << 1) | (x >> 31);
        x <<= 1;
        y >>= 1;
    }

    if ((a < 0) != (b < 0)) {
        uint32_t carry = lo == 0;
        lo = ~lo + 1u;
        hi = ~hi + carry;
    }

    hi += lo > UINT32_MAX - (1u << (Q - 1));
    uint32_t rounded = lo + (1u << (Q - 1));
    uint32_t result = (rounded >> Q) | (hi << (32 - Q));
    /* Convert the wrapped bit pattern without an out-of-range signed cast. */
    if (result <= INT32_MAX)
        return (int32_t) result;
    return -1 - (int32_t) ~result;
}
