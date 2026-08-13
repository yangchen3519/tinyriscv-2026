#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="${BUILD_ROOT:-/tmp/${USER:-user}_khoree_temp}"
LOG_ROOT="${LOG_ROOT:-../output/khoree_temp}"
FPGA_RTL="../fpga/rtl/yc_bridge_FPGA.v ../fpga/rtl/yx_fpga_bridge.v ../fpga/rtl/pjy_mem_bridge_fpga.v ../fpga/rtl/khoree_mem_bridge_fpga.v ../fpga/rtl/yc_rom.v ../fpga/rtl/yc_ram.v ../fpga/rtl/tinyriscv_4core_fpga_top.v"

mkdir -p "$BUILD_ROOT" "$LOG_ROOT"
make compile TOP=khoree_uart_debug_temp_tb \
    TB=../tb/khoree_uart_debug_temp_tb.v \
    SIMV="$BUILD_ROOT/simv" \
    EXTRA_RTL="$FPGA_RTL ../tb/lm75_model_rt.v" \
    LOGDIR="$LOG_ROOT" \
    VCS_FLAGS="-full64 +v2k -timescale=1ns/1ps -debug_access+all -f filelist.f -Mdir=$BUILD_ROOT/csrc"

"$BUILD_ROOT/simv" -l "$LOG_ROOT/khoree_uart_debug_temp.log"
