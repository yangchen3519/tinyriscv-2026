# 前仿真验证报告

验证日期：2026-08-03

## 1. 验证对象

端到端测试统一例化 `tinyriscv_4core_fpga_top`。取指和访存分别经过所选 core 自己的
chip-side bridge 与匹配 FPGA-side bridge，再仲裁到唯一 `yc_rom/yc_ram`。PWM 程序访问
唯一 `yc_pwm`。
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

- ASIC filelist：62 个源文件、75 个 module 声明，无重名模块；
- 只有一个 YC regs、PWM、uart_debug；
- ASIC 顶层有且仅有 YC/YX/PJY/Khoree 四个各自 chip-side bridge；
- FPGA 顶层有四个匹配解码 bridge，并且只有一个 YC ROM、RAM；
- `rtl/` 无 ROM/RAM/FPGA-side bridge 和未使用 Verilog；
- PJY 乘除/余数、乘法、CSR、CLINT、JTAG、Timer、SPI、GPIO 不在有效层次。

本轮没有执行 Vivado 综合、实现或板上验证；这些属于后续 FPGA/后端工作。

## 5. 2026-08-12 GitHub 合并后复验

在分支 `integrate/private-bridges-current` 上完成四核私有 bridge 与 GitHub 基线合并后，
重新执行了以下检查：

- `tools/audit_resources.ps1`：`AUDIT_PASS`，确认三项 YC 共享资源各一份、四个
  chip-side bridge 各一份、ASIC filelist 无 ROM/RAM/FPGA-side bridge；
- ModelSim 2020.4 全量基础回归：`MODELSIM_REGRESSION_PASS cases=20 core_runs=80`；
- PWM 程序：YC/YX/PJY/Khoree 4/4 PASS，均访问 `u_shared_pwm`；
- UART debug 35-byte packet：四个 `chip_sel` 分别 PASS；
- `shared_arbiter_tb`：PASS；
- `tinyriscv_4core_top_IO`：ModelSim 编译 0 error/0 warning，Icarus 完整展开 PASS；
- PAD 包装选择转换：`TEST_PASS top_IO_chip_sel_mapping`；
- ModelSim 对芯片 RTL、四套 FPGA bridge、FPGA 顶层、PAD 顶层和主要 TB 联合编译：
  0 error、0 warning。

本次没有重新执行远程 VCS/Verdi；第 3 节记录的是合并前当前功能版本的服务器结果。
合并保留了该版本的四桥架构、PJY 学号/IF 修复，并把 GitHub 基线中 Khoree UART debug
对 ROM/RAM 的等待与应答逻辑适配到 Khoree 私有 bridge。扩展 sID/IF 的本地 Icarus
运行因速度超过本轮限时而终止，未记为 PASS 或 FAIL。
