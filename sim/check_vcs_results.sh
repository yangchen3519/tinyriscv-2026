#!/usr/bin/env bash
set -euo pipefail

LOG_ROOT="${1:-../output/vcs}"
BUILD_ROOT="${2:-/tmp/${USER:-user}_tinyriscv_4core_vcs}"

sum_matches() {
    local pattern="$1"
    { grep -Rh "$pattern" "$LOG_ROOT" 2>/dev/null || true; } | wc -l
}

echo "TEST_PASS=$(sum_matches TEST_PASS)"
echo "TEST_FAIL=$(sum_matches TEST_FAIL)"
required_fail=$({ grep -Rh 'TEST_FAIL' "$LOG_ROOT" 2>/dev/null || true; } |
    grep -v 'TEST_FAIL extension_Temp' | wc -l)
temp_observation_fail=$(sum_matches 'TEST_FAIL extension_Temp')
echo "REQUIRED_TEST_FAIL=$required_fail"
echo "TEMP_OBSERVATION_FAIL=$temp_observation_fail"
echo "RV32I_CORE_PASS=$(sum_matches '^PASS core=')"
echo "PWM_CORE_PASS=$(sum_matches '^PASS PWM_E2E core=')"
echo "UART_DEBUG_PASS=$(sum_matches 'TEST_PASS shared_uart_debug_35byte_crc_ack')"
echo "NEGATIVE_NO_PASS=$(sum_matches 'PROGRAM_RESULT.*status=NO_PASS')"

compile_errors=$({ grep -RhE 'Error-|[1-9][0-9]* error\(s\)' "$LOG_ROOT" 2>/dev/null || true; } | wc -l)
echo "COMPILE_ERRORS=$compile_errors"

test "$required_fail" -eq 0
test "$(sum_matches '^PASS core=')" -eq 80
test "$(sum_matches '^PASS PWM_E2E core=')" -eq 4
test "$(sum_matches 'TEST_PASS shared_uart_debug_35byte_crc_ack')" -eq 4
test "$(sum_matches 'PROGRAM_RESULT.*status=NO_PASS')" -eq 20
test "$compile_errors" -eq 0

find "$BUILD_ROOT" -maxdepth 1 -name '*.fsdb' -type f -printf '%f %s bytes\n' | sort
echo VCS_RESULT_AUDIT_PASS
