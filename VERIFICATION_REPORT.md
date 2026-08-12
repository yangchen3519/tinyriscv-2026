# 前仿真验证报告

验证日期：2026-08-03

## 1. 验证对象

端到端测试统一例化 `tinyriscv_4core_fpga_top`，取指和访存经过唯一
`yc_bridge_core → yc_bridge_FPGA → yc_rom/yc_ram`。PWM 程序访问唯一 `yc_pwm`。
扩展指令不在本轮验收范围。

## 2. 本地 ModelSim 2020.4

结果：`MODELSIM_REGRESSION_PASS cases=20 core_runs=80`。以下 20 个程序在
YC、YX、PJY、Khoree 四核均通过，共 80/80：

| # | 程序 | 四核结果 |
|---:|---|---|
| 1 | `inst_add.data` | PASS |
| 2 | `inst_andi.data` | PASS |
| 3 | `inst_auipc.data` | PASS |
| 4 | `inst_beq.data` | PASS |
| 5 | `inst_bge.data` | PASS |
| 6 | `inst_bgeu.data` | PASS |
| 7 | `inst_blt.data` | PASS |
| 8 | `inst_bltu.data` | PASS |
| 9 | `inst_bne.data` | PASS |
| 10 | `inst_jal.data` | PASS |
| 11 | `inst_jalr.data` | PASS |
| 12 | `inst_lui.data` | PASS |
| 13 | `inst_ori.data` | PASS |
| 14 | `inst_simple.data` | PASS |
| 15 | `inst_slli.data` | PASS |
| 16 | `inst_slti.data` | PASS |
| 17 | `inst_sltiu.data` | PASS |
| 18 | `inst_srai.data` | PASS |
| 19 | `inst_srli.data` | PASS |
| 20 | `inst_xori.data` | PASS |

共享资源结果：

- `shared_arbiter_tb`：PASS；
- 35-byte UART debug：PASS；
- PWM 程序四核：4/4 PASS，日志明确标记 `target=yc_pwm.u_shared_pwm`；
- 所有 23 份本地回归日志均有 `TEST_PASS`、无 `TEST_FAIL`、仿真 error 为 0。

## 3. 服务器 VCS/Verdi

服务器账号：`chenh36`；服务器工程目录：
`/data2/class/chenh/chenh36/tinyriscv_4core_shared_yc`。密码未写入工程或脚本。

工具与结果：

- VCS `R-2020.12-SP1_Full64`；
- 20 个 RV32I × 4 核：80/80 PASS；
- 共享 PWM：4/4 PASS；
- UART debug：四个 `chip_sel` 均 PASS；
- 共享仲裁/非法选择：PASS；
- `DIV/DIVU/REM/REMU` 和已删除 GPIO/LED 程序：四核均为预期的
  `status=NO_PASS`，未发生错误写回或正常停机；
- 总结标志：`RV32I_CASES=20`、`VCS_REGRESSION_PASS`。

Verdi 批量加载以下 FSDB 均通过：

```text
inst_add.fsdb
fourcore_pwm_program.fsdb
shared_uart_debug_core3.fsdb
```

总结标志：`VERDI_LOAD_PASS_inst_add`、`VERDI_LOAD_PASS_fourcore_pwm_program`、
`VERDI_LOAD_PASS_shared_uart_debug_core3`、`VERDI_BATCH_LOAD_PASS`。

服务器的 VCS 版本比 FSDB dumper 新，运行时打印兼容性提示；FSDB 实际成功生成并由 Verdi
批量读回，因此不影响本轮波形可读性结论。

## 4. 静态审计

- ASIC filelist：59 文件、60 有效模块；
- 只有一个 YC regs、PWM、uart_debug、bridge_core；
- FPGA 顶层只有一个 YC bridge_FPGA、ROM、RAM；
- YX/PJY/Khoree 私有 bridge 文件不在有效 RTL；
- `rtl/` 无 ROM/RAM/FPGA-side bridge 和未使用 Verilog；
- PJY 乘除/余数、乘法、CSR、CLINT、JTAG、Timer、SPI、GPIO 不在有效层次。

本轮没有执行 Vivado 综合、实现或板上验证；这些属于后续 FPGA/后端工作。
