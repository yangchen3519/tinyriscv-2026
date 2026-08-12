#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-/tmp/${USER:-user}_tinyriscv_4core_vcs}"
LOG_ROOT="../output/vcs"
BASE_FLAGS="-full64 +v2k -timescale=1ns/1ps -debug_access+all -kdb +define+FSDB -f filelist.f"
FPGA_RTL="../fpga/rtl/yc_bridge_FPGA.v ../fpga/rtl/yc_rom.v ../fpga/rtl/yc_ram.v ../fpga/rtl/tinyriscv_4core_fpga_top.v"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$LOG_ROOT"

compile_top() {
    local top="$1" tb="$2" extra="$3" include_flags="${4:-}"
    mkdir -p "$BUILD_ROOT/csrc_$top" "$LOG_ROOT/$top"
    make compile TOP="$top" TB="$tb" SIMV="$BUILD_ROOT/simv_$top" \
        LOGDIR="$LOG_ROOT/$top" EXTRA_RTL="$extra" \
        VCS_FLAGS="$BASE_FLAGS $include_flags -Mdir=$BUILD_ROOT/csrc_$top"
}

run_checked() {
    local top="$1"; shift
    "$BUILD_ROOT/simv_$top" "$@" -l "$LOG_ROOT/$top/$top.log"
    grep -q TEST_PASS "$LOG_ROOT/$top/$top.log"
    ! grep -q TEST_FAIL "$LOG_ROOT/$top/$top.log"
}

compile_top shared_arbiter_tb ../tb/shared_arbiter_tb.v ""
run_checked shared_arbiter_tb "+FSDB_FILE=$BUILD_ROOT/shared_arbiter.fsdb"

compile_top shared_uart_debug_tb ../tb/shared_uart_debug_tb.v "$FPGA_RTL"
for core in 0 1 2 3; do
    "$BUILD_ROOT/simv_shared_uart_debug_tb" "+CHIP_SEL=$core" \
        "+FSDB_FILE=$BUILD_ROOT/shared_uart_debug_core${core}.fsdb" \
        -l "$LOG_ROOT/shared_uart_debug_tb/shared_uart_debug_core${core}.log"
    grep -q TEST_PASS "$LOG_ROOT/shared_uart_debug_tb/shared_uart_debug_core${core}.log"
    ! grep -q TEST_FAIL "$LOG_ROOT/shared_uart_debug_tb/shared_uart_debug_core${core}.log"
done

compile_top fourcore_rv32i_smoke_tb ../tb/fourcore_rv32i_smoke_tb.v "$FPGA_RTL"
rv32i_count=0
for casefile in ../firmware/test_command/Baisc_Inst_Example/*.data; do
    case "$(basename "$casefile")" in
        inst_div.data|inst_divu.data|inst_rem.data|inst_remu.data) continue ;;
    esac
    name="$(basename "$casefile" .data)"
    mkdir -p "$LOG_ROOT/$name"
    "$BUILD_ROOT/simv_fourcore_rv32i_smoke_tb" \
        "+INST_FILE=$casefile" "+FSDB_FILE=$BUILD_ROOT/$name.fsdb" \
        -l "$LOG_ROOT/$name/fourcore_rv32i_smoke_tb.log"
    grep -q TEST_PASS "$LOG_ROOT/$name/fourcore_rv32i_smoke_tb.log"
    ! grep -q TEST_FAIL "$LOG_ROOT/$name/fourcore_rv32i_smoke_tb.log"
    rv32i_count=$((rv32i_count + 1))
done

compile_top fourcore_pwm_program_tb ../tb/fourcore_pwm_program_tb.v "$FPGA_RTL"
run_checked fourcore_pwm_program_tb \
    "+INST_FILE=../firmware/test_command/Other_Example/PWM/PWM_inst.data" \
    "+FSDB_FILE=$BUILD_ROOT/fourcore_pwm_program.fsdb"
test "$(grep -c '^PASS PWM_E2E core=' "$LOG_ROOT/fourcore_pwm_program_tb/fourcore_pwm_program_tb.log")" -eq 4

compile_top fourcore_program_probe_tb ../tb/fourcore_program_probe_tb.v "$FPGA_RTL"
for casefile in \
    ../firmware/test_command/Baisc_Inst_Example/inst_div.data \
    ../firmware/test_command/Baisc_Inst_Example/inst_divu.data \
    ../firmware/test_command/Baisc_Inst_Example/inst_rem.data \
    ../firmware/test_command/Baisc_Inst_Example/inst_remu.data \
    ../firmware/test_command/Other_Example/LED/LED.data; do
    name="$(basename "$casefile" .data)"
    for core in 0 1 2 3; do
        log="$LOG_ROOT/fourcore_program_probe_tb/${name}_core${core}.log"
        "$BUILD_ROOT/simv_fourcore_program_probe_tb" "+INST_FILE=$casefile" "+CORE=$core" \
            +MAX_CYCLES=50000 -l "$log"
        grep -q 'PROGRAM_RESULT.*status=NO_PASS' "$log"
        grep -q 'TEST_PASS bounded_program_probe' "$log"
    done
done

echo "RV32I_CASES=$rv32i_count"
echo VCS_REGRESSION_PASS
