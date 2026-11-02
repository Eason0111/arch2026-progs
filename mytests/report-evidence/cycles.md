# Cycle analysis

- compiler: riscv-none-elf-gcc 15.2.0, -march=rv32i_zicsr -mabi=ilp32 -ffreestanding
- rv32emu: 158b57e (system emulation, ELF_LOADER, interpreter)
- timed region: n calls on identical inputs; loop baseline subtracted

rv32emu has no timing model: `cycle` and `instret` are one counter of executed guest instructions. The figures below are instruction counts per call, with the loop control, input load and counter reads removed.

## Cycles per call

| Function | -O1 | -O2 | -O3 | -Os | asm | best C | asm vs best C |
|---|---|---|---|---|---|---|---|
| bf16.from_f32 | 11.1 | 12.2 | 13.8 | 12.2 | 11.2 | 11.1 | 0.98x |
| bf16.mul | 96.8 | 87.2 | 88.7 | 91.6 | 67.2 | 87.2 | 1.30x |
| bf16.sqrt | 326.2 | 326.1 | 327.6 | 339.0 | 48.9 | 326.1 | 6.66x |
| fixed.op1 | 24.8 | 22.1 | 24.2 | 24.7 | 22.1 | 22.1 | 1.00x |
| fixed.op2 | 4.0 | 4.0 | 5.9 | 4.0 | 4.0 | 4.0 | 1.00x |
| fixed.op3 | 7.0 | 7.0 | 8.9 | 7.0 | 7.0 | 7.0 | 1.00x |
| fixed.q_mul | 224.2 | 259.5 | 261.4 | 242.4 | 199.9 | 224.2 | 1.12x |
| gcd.gcd | 101.6 | 116.6 | 118.8 | 119.7 | 92.8 | 101.6 | 1.10x |
| rubik.solve | 262065.2 | 239903.3 | 248870.5 | 247787.8 | 57848.7 | 239903.3 | 4.15x |

## Ratio to -O2

| Function | -O1 | -O2 | -O3 | -Os | asm |
|---|---|---|---|---|---|
| bf16.from_f32 | 0.91 | 1.00 | 1.13 | 1.00 | 0.92 |
| bf16.mul | 1.11 | 1.00 | 1.02 | 1.05 | 0.77 |
| bf16.sqrt | 1.00 | 1.00 | 1.00 | 1.04 | 0.15 |
| fixed.op1 | 1.12 | 1.00 | 1.10 | 1.12 | 1.00 |
| fixed.op2 | 1.00 | 1.00 | 1.48 | 1.00 | 1.00 |
| fixed.op3 | 1.00 | 1.00 | 1.28 | 1.00 | 1.00 |
| fixed.q_mul | 0.86 | 1.00 | 1.01 | 0.93 | 0.77 |
| gcd.gcd | 0.87 | 1.00 | 1.02 | 1.03 | 0.80 |
| rubik.solve | 1.09 | 1.00 | 1.04 | 1.03 | 0.24 |

## Footprint (bytes, `size -A`, harness excluded)

| Program | Variant | .text | .rodata | .data | .bss |
|---|---|---|---|---|---|
| rubik | asm | 1440 | 99912 | 0 | 107 |
| rubik | -O1 | 1448 | 40468 | 0 | 83 |
| rubik | -O2 | 1252 | 40468 | 0 | 83 |
| rubik | -O3 | 2720 | 40468 | 0 | 83 |
| rubik | -Os | 996 | 40468 | 0 | 83 |
| bf16 | asm | 540 | 0 | 0 | 0 |
| bf16 | -O1 | 884 | 0 | 0 | 0 |
| bf16 | -O2 | 796 | 0 | 0 | 0 |
| bf16 | -O3 | 796 | 0 | 0 | 0 |
| bf16 | -Os | 748 | 0 | 0 | 0 |
| gcd | asm | 120 | 0 | 0 | 0 |
| gcd | -O1 | 140 | 0 | 0 | 0 |
| gcd | -O2 | 140 | 0 | 0 | 0 |
| gcd | -O3 | 140 | 0 | 0 | 0 |
| gcd | -Os | 120 | 0 | 0 | 0 |
| fixed | asm | 236 | 0 | 0 | 0 |
| fixed | -O1 | 272 | 0 | 0 | 0 |
| fixed | -O2 | 312 | 0 | 0 | 0 |
| fixed | -O3 | 312 | 0 | 0 | 0 |
| fixed | -Os | 216 | 0 | 0 | 0 |
