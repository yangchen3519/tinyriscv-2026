# Four-Core Function Simulation Report

Date: 2026-08-13

Simulator: Synopsys VCS R-2020.12-SP1_Full64

Server: `edaserver`
Repository commit: `d34b5c5ab084cb67544b43acf69ee87e5c563f0b`

## Scope

The current GitHub `main` branch was simulated using `tinyriscv_4core_fpga_top`, the shared YC ROM/RAM model, the four core-specific memory bridges, the shared YC register file and PWM block, and the LM75 behavioral model. The tested cores are:

| Core | `chip_sel` | Name |
|---:|---:|---|
| 0 | `00` | YC |
| 1 | `01` | YX |
| 2 | `10` | PJY |
| 3 | `11` | Khoree |

The requested functions were tested with the supplied firmware programs:

- `sID_inst.data`
- `Temp.data` (rT / temperature)
- `IF_inst.data`
- `PWM_inst.data`

## Results

| Function | YC (core 0) | YX (core 1) | PJY (core 2) | Khoree (core 3) |
|---|---|---|---|---|
| sID | **FAIL** - timeout | **PASS** - `2025210895` | **FAIL** - returned final digit `5`, expected `2` | **PASS** - `2025280058` |
| Temperature | **FAIL** - timeout | **FAIL** - returned `0xFF`, expected `0x1A` | **PASS** - returned `0x1A` | **FAIL** - timeout |
| IF | **PASS** - UART `0x8A`, x30=`0x8A` | **PASS** - UART `0x8A`, x30=`0` | **FAIL** - UART `0x8E`, expected `0x8A`; x30=`0x8E` | **PASS** - UART `0x8A`, x30=`0` |
| PWM | **FAIL** - no register writes before 200,000-cycle timeout | **PASS** - 1,320 cycles | **PASS** - 663 cycles | **PASS** - 1,243 cycles |

Overall: 8 of the 16 requested core/function combinations passed.

## Important discrepancies

The fresh results do not match the checked-in `TEST_COMMAND_REGRESSION.md` for PJY sID, PJY IF, or YC PWM. The simulated RTL still contains the earlier PJY values (`2025210905` and IF result `0x8E`), despite the report claiming they were changed to `2025210902` and `0x8A`. The current YC core also does not complete the sID or temperature programs and does not write the PWM registers during the bounded PWM test.

## Reproduction

From the repository's `sim` directory on a Linux host with VCS configured:

```bash
BUILD_ROOT=/tmp/$USER-tinyriscv-requested-4x4 \
LOG_ROOT=../output/requested_4x4 \
./run_requested_4x4.sh
```

The script intentionally runs every requested case even when a case fails, so all 16 results are recorded. Per-case logs are under `output/requested_4x4/`.
