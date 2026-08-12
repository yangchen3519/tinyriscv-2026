# tinyriscv_4core 最终交付

本目录只保留后端/FPGA 接手需要的源码、testbench、测试程序、脚本和说明文档，不含
VCS/ModelSim work 库、日志、FSDB、Vivado 工程缓存或服务器过程文件。

## 两个顶层

| 顶层 | 文件 | 用途 |
|---|---|---|
| `tinyriscv_4core_top` | `rtl/tinyriscv_4core_top.v` | ASIC/流片顶层；不含 ROM、RAM 和 FPGA-side bridge |
| `tinyriscv_4core_fpga_top` | `fpga/rtl/tinyriscv_4core_fpga_top.v` | FPGA/端到端仿真顶层；含唯一 YC FPGA bridge、ROM、RAM |

四核共享的资源均采用 YC 实现：`yc_regs`、`yc_pwm`、`yc_uart_debug`、
`yc_bridge_core`。FPGA 包装层再共享一份 `yc_bridge_FPGA`、一份 `yc_rom` 和一份
`yc_ram`，不存在四套私有存储。

`chip_sel`：`000=YC`、`001=YX`、`010=PJY`、`011=Khoree`，`100~111` 禁用。
只允许在低有效复位 `rst=0` 时改变选择。

## 目录

| 路径 | 内容 |
|---|---|
| `rtl/` | 最终流片 RTL（59 文件、60 模块） |
| `fpga/` | 共享 YC bridge/ROM/RAM 与 FPGA 包装层，不进入 ASIC |
| `tb/` | 5 个实际使用的 testbench |
| `firmware/` | 指令、PWM 和负向测试程序 |
| `sim/filelist.f` | ASIC RTL 编译清单；路径按 `sim/` 目录解析 |
| `fpga/filelist.f` | FPGA/端到端仿真附加清单 |
| `sim/*.sh`, `sim/*.ps1`, `sim/Makefile` | VCS、Verdi、ModelSim 回归入口 |
| `tools/` | filelist、资源审计及 Vivado 导入脚本 |

本交付不含 XDC。旧单核约束与新的四核/FPGA 顶层端口不匹配，不能复用；上板同学应
依据实际开发板原理图建立新 XDC。

## 快速使用

资源审计：

```powershell
python tools/build_filelist.py
powershell -ExecutionPolicy Bypass -File tools/audit_resources.ps1
```

ModelSim：

```powershell
cd sim
powershell -ExecutionPolicy Bypass -File run_modelsim.ps1
```

VCS/Verdi：

```bash
cd sim
BUILD_ROOT=/tmp/$USER-tinyriscv-4core bash run_vcs_regression.sh
bash run_verdi_checks.sh /tmp/$USER-tinyriscv-4core ../output
```

Vivado 导入、filelist 解释和每个 testbench 的作用见 `HANDOFF.md`；上板步骤见
`FPGA_BOARD_GUIDE.md`；本轮验证明细见 `VERIFICATION_REPORT.md`。
