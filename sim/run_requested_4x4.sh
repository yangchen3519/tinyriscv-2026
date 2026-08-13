#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-/tmp/${USER:-user}_tinyriscv_requested_4x4}"
LOG_ROOT="${LOG_ROOT:-../output/requested_4x4}"
BASE_FLAGS="-full64 +v2k -timescale=1ns/1ps -debug_access+all -kdb -f filelist.f"
FPGA_RTL="../fpga/rtl/yc_bridge_FPGA.v ../fpga/rtl/yx_fpga_bridge.v ../fpga/rtl/pjy_mem_bridge_fpga.v ../fpga/rtl/khoree_mem_bridge_fpga.v ../fpga/rtl/yc_rom.v ../fpga/rtl/yc_ram.v ../fpga/rtl/tinyriscv_4core_fpga_top.v"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$LOG_ROOT/extensions" "$LOG_ROOT/pwm"

make compile TOP=fourcore_extension_program_tb \
    TB=../tb/fourcore_extension_program_tb.v \
    SIMV="$BUILD_ROOT/simv_extensions" \
    LOGDIR="$LOG_ROOT/extensions" \
    EXTRA_RTL="$FPGA_RTL ../tb/lm75_model_rt.v" \
    VCS_FLAGS="$BASE_FLAGS -Mdir=$BUILD_ROOT/csrc_extensions"

for kind in 0 1 2; do
    case "$kind" in
        0) name=sid; program=../firmware/test_command/Extend_Inst_Example/sID/sID_inst.data ;;
        1) name=if; program=../firmware/test_command/Extend_Inst_Example/IF/IF_inst.data ;;
        2) name=temp; program=../firmware/test_command/Extend_Inst_Example/Temp/Temp.data ;;
    esac
    for core in 0 1 2 3; do
        "$BUILD_ROOT/simv_extensions" "+CORE=$core" "+TEST_KIND=$kind" \
            "+INST_FILE=$program" -l "$LOG_ROOT/extensions/${name}_core${core}.log"
    done
done

make compile TOP=fourcore_pwm_program_tb \
    TB=../tb/fourcore_pwm_program_tb.v \
    SIMV="$BUILD_ROOT/simv_pwm" \
    LOGDIR="$LOG_ROOT/pwm" \
    EXTRA_RTL="$FPGA_RTL" \
    VCS_FLAGS="$BASE_FLAGS -Mdir=$BUILD_ROOT/csrc_pwm"

"$BUILD_ROOT/simv_pwm" \
    +INST_FILE=../firmware/test_command/Other_Example/PWM/PWM_inst.data \
    -l "$LOG_ROOT/pwm/pwm_all_cores.log"

echo "=== REQUESTED 4x4 SUMMARY ==="
grep -hE 'TEST_(PASS|FAIL) extension_' "$LOG_ROOT"/extensions/*.log | sort
grep -E '^(PASS PWM_E2E core=|TEST_(PASS|FAIL) fourcore_PWM)' "$LOG_ROOT/pwm/pwm_all_cores.log"
