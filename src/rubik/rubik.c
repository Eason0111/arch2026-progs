#include "rubik.h"
#include "rubik_transition_tables.h"
#define MOVES 9

typedef struct {
    uint16_t p, o;
    uint8_t next_move;
} Frame;

static Frame stack[12];
static uint8_t path[11];

static const uint16_t *const permutation[3] = {
    perm_R,
    perm_B,
    perm_D,
};
static const uint16_t *const orientation[3] = {
    orient_R,
    orient_B,
    orient_D,
};
static int solve(unsigned input_p, unsigned input_o)
{
    unsigned depth = 0;
    stack[0].p = (uint16_t) input_p;
    stack[0].o = (uint16_t) input_o;
    stack[0].next_move = 0;

    unsigned hp = position_dist[input_p];
    unsigned ho = orientation_dist[input_o];
    unsigned bound = hp > ho ? hp : ho;
    if (bound > 11)
        return -1;

    while (1) {
        if (stack[depth].p == 0 && stack[depth].o == 0)
            return (int) depth;

        if (depth >= bound || stack[depth].next_move >= MOVES) {
            if (depth == 0) {
                if (bound >= 11)
                    return -1;
                ++bound;
                stack[0].next_move = 0;
                continue;
            }
            --depth;
            continue;
        }

        uint8_t move = stack[depth].next_move++;
        uint8_t face = move_face[move];
        if (depth > 0 && face == move_face[path[depth - 1]])
            continue;

        uint8_t turns = move_turns[move];
        uint16_t next_p = stack[depth].p;
        uint16_t next_o = stack[depth].o;
        for (uint8_t turn = 0; turn < turns; ++turn) {
            next_p = permutation[face][next_p];
            next_o = orientation[face][next_o];
        }

        unsigned next_hp = position_dist[next_p];
        unsigned next_ho = orientation_dist[next_o];
        unsigned next_h = next_hp > next_ho ? next_hp : next_ho;
        unsigned next_depth = depth + 1;
        if (next_depth + next_h > bound)
            continue;
        if (next_depth >= sizeof stack / sizeof stack[0])
            return -1;

        path[depth] = move;
        ++depth;
        stack[depth].p = next_p;
        stack[depth].o = next_o;
        stack[depth].next_move = 0;
    }
}
/* Validate the state and write a shortest solution within the buffer. */
int rubik_solve(const char *state, char *out, size_t cap)
{
    for (size_t i = 0; i < RUBIK_STATE_LEN; i++) {
        if (state[i] == '\0')
            return -1;
    }
    if (state[RUBIK_STATE_LEN] != '\0')
        return -1;
    unsigned mask = 0;
    for (size_t i = 0; i < 7; i++) {
        if (state[i] < '1' || state[i] > '7')
            return -1;

        unsigned v = (unsigned) (state[i] - '1');
        unsigned bit = 1u << v;
        if (mask & bit)
            return -1;

        mask |= bit;
    }
    unsigned sum = 0;
    for (size_t i = 7; i < RUBIK_STATE_LEN; i++) {
        if (state[i] < '1' || state[i] > '3')
            return -1;

        sum += (unsigned) (state[i] - '1');
    }

    while (sum >= 3)
        sum -= 3;

    if (sum != 0)
        return -1;
    unsigned p = 0;
    for (size_t i = 0; i < 7; i++) {
        unsigned less = 0;
        for (size_t j = i + 1; j < 7; j++) {
            if (state[j] < state[i])
                less++;
        }
        p = p * (7u - (unsigned) i) + less;
    }
    unsigned o = 0;
    for (size_t i = 7; i < 13; i++) {
        unsigned digit = (unsigned) (state[i] - '1');
        o = (o << 1) + o + digit;
    }
    int length = solve(p, o);
    if (length < 0)
        return -1;

    static const char names[9][3] = {
        "R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'",
    };

    size_t needed = 1;
    for (int i = 0; i < length; i++) {
        needed += names[path[i]][1] ? 2u : 1u;
        if (i > 0)
            needed++;
    }

    if (cap < needed) {
        if (cap > 0)
            out[0] = '\0';
        return -2;
    }

    size_t pos = 0;
    for (int i = 0; i < length; i++) {
        if (i > 0)
            out[pos++] = ' ';

        const char *name = names[path[i]];
        out[pos++] = name[0];
        if (name[1] != '\0')
            out[pos++] = name[1];
    }
    out[pos] = '\0';
    return length;
}
