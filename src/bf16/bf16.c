#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    if ((f32bits & 0x7f800000u) == 0x7f800000u)
        return (uint16_t) (f32bits >> 16);

    uint32_t tie = (f32bits >> 16) & 1u;
    return (uint16_t) ((f32bits + 0x7fffu + tie) >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    unsigned sign = (a ^ b) & 0x8000u;
    unsigned abs_a = a & 0x7fffu;
    unsigned abs_b = b & 0x7fffu;
    int ea = (a >> 7) & 0xff;
    int eb = (b >> 7) & 0xff;
    unsigned ma = a & 0x7fu;
    unsigned mb = b & 0x7fu;

    /* Operand order matters: an infinite a also takes precedence over NaN b. */
    if (ea == 255) {
        if (ma != 0)
            return a;
        if (abs_b == 0)
            return 0x7fc0u;
        return (uint16_t) (sign | 0x7f80u);
    }
    if (eb == 255) {
        if (mb != 0)
            return b;
        if (abs_a == 0)
            return 0x7fc0u;
        return (uint16_t) (sign | 0x7f80u);
    }

    if (abs_a == 0 || abs_b == 0)
        return (uint16_t) sign;

    if (ea == 0) {
        ea = 1;
        while (ma < 128u) {
            ma <<= 1;
            ea--;
        }
    } else {
        ma |= 128u;
    }

    if (eb == 0) {
        eb = 1;
        while (mb < 128u) {
            mb <<= 1;
            eb--;
        }
    } else {
        mb |= 128u;
    }

    unsigned product = ma * mb;
    int exponent = ea + eb - 127;
    unsigned mantissa;
    if (product >= 32768u) {
        mantissa = product >> 8;
        exponent++;
    } else {
        mantissa = product >> 7;
    }

    if (exponent >= 255)
        return (uint16_t) (sign | 0x7f80u);

    if (exponent <= 0) {
        if (exponent < -6)
            return (uint16_t) sign;
        return (uint16_t) (sign | ((mantissa & 0x7fu) >> (1 - exponent)));
    }

    return (uint16_t) (sign | ((unsigned) exponent << 7) | (mantissa & 0x7fu));
}

uint16_t bf16_sqrt(uint16_t a)
{
    unsigned magnitude = a & 0x7fffu;
    unsigned fraction = a & 0x7fu;
    int exponent = (a >> 7) & 0xff;

    if (exponent == 255) {
        if (fraction != 0)
            return a;
        return (a & 0x8000u) ? 0x7fc0u : a;
    }

    /* Both signs of zero produce positive zero. */
    if (magnitude == 0)
        return 0;
    if (a & 0x8000u)
        return 0x7fc0u;
    if (exponent == 0)
        return 0;

    unsigned mantissa = 128u | fraction;
    exponent -= 127;

    /* Make the unbiased exponent even before halving it. */
    if (exponent % 2 != 0) {
        mantissa <<= 1;
        exponent--;
    }
    exponent = exponent / 2 + 127;

    unsigned low = 90;
    unsigned high = 256;
    unsigned root = 0;
    while (low <= high) {
        unsigned mid = (low + high) >> 1;
        if (((mid * mid) >> 7) <= mantissa) {
            root = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    while (root >= 256u) {
        root >>= 1;
        exponent++;
    }
    while (root < 128u) {
        root <<= 1;
        exponent--;
    }

    if (exponent >= 255)
        return 0x7f80u;
    if (exponent <= 0)
        return 0;

    return (uint16_t) (((unsigned) exponent << 7) | (root & 0x7fu));
}
