# `test_command` 指令与程序前仿真核验

更新日期：2026-08-12

## 覆盖范围与判据

原始目录 `D:\tiny_riscv\tinyriscv\test_command` 共 29 个 `.data`。本轮使用
服务器 VCS R-2020.12-SP1、四核各自 chip-side bridge、FPGA 侧唯一 YC ROM/RAM 进行
端到端验证。

- 基础指令：排除已按课程要求删除的 `DIV/DIVU/REM/REMU`，其余 20 个程序要求四核
  `x26=1` 且 `x27=1`。
- sID：运行同一 `sID_inst.data`，逐字节核对各核自己的 10 位学号。
- IF：运行同一 `IF_inst.data`，四核 UART 参考返回值均为 `0x8A`。各提交对内部
  `x30` 的保留/清零策略不同，因此 `x30` 仅记录，不作为统一判据。
- Temp/rT：顺带测试，不作为本轮必过项；LM75 模型温度高字节为 `0x1A`。
- PWM：运行同一 `PWM_inst.data`，四核都必须写到唯一 `yc_pwm u_shared_pwm`，并核对
  四通道 period/duty/enable。

## 基础程序结果

下列 20 个程序均为 **YC/YX/PJY/Khoree 4/4 PASS**，合计 80/80：

| 程序 | YC | YX | PJY | Khoree |
|---|---|---|---|---|
| inst_add.data | PASS | PASS | PASS | PASS |
| inst_andi.data | PASS | PASS | PASS | PASS |
| inst_auipc.data | PASS | PASS | PASS | PASS |
| inst_beq.data | PASS | PASS | PASS | PASS |
| inst_bge.data | PASS | PASS | PASS | PASS |
| inst_bgeu.data | PASS | PASS | PASS | PASS |
| inst_blt.data | PASS | PASS | PASS | PASS |
| inst_bltu.data | PASS | PASS | PASS | PASS |
| inst_bne.data | PASS | PASS | PASS | PASS |
| inst_jal.data | PASS | PASS | PASS | PASS |
| inst_jalr.data | PASS | PASS | PASS | PASS |
| inst_lui.data | PASS | PASS | PASS | PASS |
| inst_ori.data | PASS | PASS | PASS | PASS |
| inst_simple.data | PASS | PASS | PASS | PASS |
| inst_slli.data | PASS | PASS | PASS | PASS |
| inst_slti.data | PASS | PASS | PASS | PASS |
| inst_sltiu.data | PASS | PASS | PASS | PASS |
| inst_srai.data | PASS | PASS | PASS | PASS |
| inst_srli.data | PASS | PASS | PASS | PASS |
| inst_xori.data | PASS | PASS | PASS | PASS |

`inst_div.data`、`inst_divu.data`、`inst_rem.data`、`inst_remu.data` 不属于保留指令，
已作为负向用例验证：四核均不得产生成功签名，20 项负向探测（含 LED）全部符合预期。

## 扩展程序结果

| 程序 | YC | YX | PJY | Khoree |
|---|---|---|---|---|
| sID_inst.data | PASS `2025210887` | PASS `2025210895` | PASS `2025210902` | PASS `2025280058` |
| IF_inst.data | PASS `UART=8A, x30=8A` | PASS `UART=8A, x30=0` | PASS `UART=8A, x30=8A` | PASS `UART=8A, x30=0` |
| Temp.data（顺带） | FAIL，UART=`34` | FAIL，UART=`FF` | PASS，UART=`1A` | FAIL，UART=`23` |

PJY 原有效 RTL 曾把 sID 最后一位写成 `5`，本轮已修正为学号
`2025210902`；PJY IF 累加路径曾多加常数 `1`、返回 `0x8E`，本轮已移除该偏置并经
VCS 端到端复测为 `0x8A`。

## PWM 结果

`Other_Example/PWM/PWM_inst.data`：四核 4/4 PASS。四次运行实际访问的均为
`tinyriscv_4core_top.u_shared_pwm`，并非各核私有 PWM；寄存器核对值为：

- period：`100000000, 50000000, 4000000, 8000000`
- duty：`50000000, 25000000, 2000000, 4000000`
- enable：`0x0000000F`

最终服务器回归输出：`RV32I_CASES=20`、`VCS_REGRESSION_PASS`。
