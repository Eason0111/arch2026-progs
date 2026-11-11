# Report verification evidence

Supporting data for the [English report](https://hackmd.io/@Eason0111/SynTumUaMx).
These supplemental checks are separate from the instructor grading harness.
They were prepared with AI assistance.

## Provenance

The published benchmark tables and numerical diagnostics describe implementation
revision `e14903125b39b2e58b96be60f1494d0149e1e754` and
[CI run 41466076945](https://github.com/Eason0111/arch2026-progs/actions/runs/41466076945).
The later revision `d32982e` renames lookup files without changing their data.
Scripts here use the new names. Historical manifests are preserved verbatim:
the old paths identify what was measured, not the current file layout.
The Rubik manifest records the exact source and executable hashes of its run.
The published probe was reformatted without changing its behavior; the portable
scripts were rerun after cleanup and reproduced the numerical diagnostics and
all 2,644 valid solutions, with the same maximum of 7,440,266 instructions.

## Files

| Files | Purpose |
|---|---|
| `benchmark-cycles.csv` | CI benchmark: instructions per call for every function and level |
| `section-sizes.csv` | CI `size -A` section sizes for every program and level |
| `test-output-bf16-O2.txt`, `test-output-gcd-O2.txt`, `test-output-fixed-O2.txt` | Detailed local test and instruction-budget output |
| `error-analysis.json`, `measure-bf16-fixed-errors.py` | Numerical error results for BF16 and Q11.20, and the host script that produces them |
| `rubik-distance11-states.txt` | Input list: the 2,644 states at distance eleven |
| `rubik-distance11-probe.c` | Target program that solves each listed state and counts instructions |
| `rubik-distance11-results.csv` | Per-state output and instruction count for the 2,644 states |
| `rubik-distance11-verification.json` | Independent replay and budget summary |
| `rubik-distance11-manifest.json` | Historical hashes of the measured sources and executables |
| `run-rubik-distance11-check.py` | Build the probe, run the emulator and independently replay solutions |
| `build-rubik-distance-up-to-5.py` | Generate the exact table for distances zero through five |
| `SHA256SUMS.json` | Hashes of the published evidence package |

The formatted cycle table and the historical Rubik section sizes were removed
because they duplicate `benchmark-cycles.csv` and `section-sizes.csv`. Files were
renamed for readability after revision `8a924bb`; their contents are unchanged.
The manifest keeps the original paths, and the generator still writes its
original header line so that regenerated tables stay byte-identical.

## Reproduce from the repository root

Use Python 3, host GCC and the RISC-V toolchain described in the main README.
The original measurements used GCC 15.2.0 and rv32emu revision
`158b57e9eab99d59e01141cd0e477b06b44b8fe3`.

```sh
make RV32EMU_REV=158b57e9eab99d59e01141cd0e477b06b44b8fe3
python3 mytests/report-evidence/measure-bf16-fixed-errors.py .
python3 mytests/report-evidence/run-rubik-distance11-check.py .
```

The numerical diagnostic writes into `generated/`. The target verification writes
into a new `rubik-distance11-run-<timestamp>/` directory and can take several minutes.
Set the environment variable `CROSS_COMPILE` if the cross-toolchain prefix differs
from `riscv-none-elf-`. The target script has a 1,800-second emulator timeout.
Neither command overwrites the published historical result files.

The optional table generator rewrites `src/rubik/rubik_distance_up_to_5.inc`.
Run it in a disposable checkout if you only want to inspect generation:

```sh
python3 mytests/report-evidence/build-rubik-distance-up-to-5.py .
```

## Interpretation

The distance-eleven verification checks all 2,644 supplied states against the
recorded set and independently replays every solution. It does not enumerate all
3,674,160 states or exhaustively time other depths. The numerical diagnostic
samples multiplication pairs; only the positive-normal square-root input domain
is fully swept there. See the report for domains and error limitations.

No compiled binaries, old implementation backups, credentials or copied emulator
are included. Charts remain available in the linked CI artifact.
