#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${1:-/tmp/${USER:-user}_tinyriscv_4core_vcs}"
RESULT_ROOT="${2:-../output}"

for item in inst_add fourcore_pwm_program shared_uart_debug_core3; do
    log="$RESULT_ROOT/verdi_newkh_${item}.log"
    timeout 60 verdi -batch -ssf "$BUILD_ROOT/${item}.fsdb" > "$log" 2>&1
    grep -q 'tool exits automatically' "$log"
    echo "VERDI_LOAD_PASS_${item}"
done

echo VERDI_BATCH_LOAD_PASS
