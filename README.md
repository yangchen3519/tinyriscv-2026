# tinyriscv_4core 最终交付

本目录只保留后端/FPGA 接手需要的源码、testbench、测试程序、脚本和说明文档，不含
VCS/ModelSim work 库、日志、FSDB、Vivado 工程缓存或服务器过程文件。

## 两个顶层

| 顶层 | 文件 | 用途 |
|---|---|---|
| `tinyriscv_4core_top` | `rtl/tinyriscv_4core_top.v` | ASIC 逻辑顶层；四核各保留自己的 chip-side bridge，不含 ROM/RAM |
| `tinyriscv_4core_top_IO` | `rtl/tinyriscv_4core_top_IO.v` | TSMC180 PAD 包装顶层；实例名与后端 `io.file` 对应 |
| `tinyriscv_4core_fpga_top` | `fpga/rtl/tinyriscv_4core_fpga_top.v` | FPGA/端到端仿真顶层；四套协议解码 bridge 仲裁一份 YC ROM/RAM |

全芯片共享资源采用 YC 实现：唯一 `yc_regs`、`yc_pwm`、`yc_uart_debug`。存储 bridge
不是共享资源：YC/YX/PJY/Khoree 各自保留原协议的 chip-side bridge；FPGA/仿真侧也有
四个匹配解码器，随后按 `chip_sel` 仲裁到唯一 `yc_rom` 和唯一 `yc_ram`。

`chip_sel`：`000=YC`、`001=YX`、`010=PJY`、`011=Khoree`，`100~111` 禁用。
只允许在低有效复位 `rst=0` 时改变选择。

## 目录

| 路径 | 内容 |
|---|---|
| `rtl/` | 流片 RTL：四核、三项 YC 共享资源、四套 chip-side bridge、PAD 包装层 |
| `fpga/` | 四套 FPGA-side bridge、共享 YC ROM/RAM 与 FPGA 包装层，不进入 ASIC |
| `tb/` | 仲裁、UART debug、RV32I、PWM、扩展/负向专项 testbench |
| `firmware/` | 指令、PWM 和负向测试程序 |
| `sim/filelist.f` | ASIC RTL 编译清单；路径按 `sim/` 目录解析 |
| `fpga/filelist.f` | FPGA/端到端仿真附加清单 |
| `sim/*.sh`, `sim/*.ps1`, `sim/Makefile` | VCS、Verdi、ModelSim 回归入口 |
| `tools/` | filelist、资源审计及 Vivado 导入脚本 |
| `docs/` | 使用手册、设计说明、合并记录与验证报告 |

本交付不含 XDC。旧单核约束与新的四核/FPGA 顶层端口不匹配，不能复用；上板同学应
依据实际开发板原理图建立新 XDC。

逻辑顶层的 `chip_sel` 使用 `000/001/010/011`。PAD 包装层保留旧物理低有效选择编码，
并在内部转换 `111/110/101/011 -> 000/001/010/011`；其他物理编码转换成非法选择。

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

Vivado 导入、filelist 解释和每个 testbench 的作用见
[`docs/HANDOFF.md`](docs/HANDOFF.md)；上板步骤见
[`docs/FPGA_BOARD_GUIDE.md`](docs/FPGA_BOARD_GUIDE.md)；本轮验证明细见
[`docs/VERIFICATION_REPORT.md`](docs/VERIFICATION_REPORT.md)。完整文档导航见
[`docs/README.md`](docs/README.md)。
