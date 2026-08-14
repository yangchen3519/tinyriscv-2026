# tinyriscv_4core 使用与交付手册

## 1. 先选对顶层和 filelist

ASIC 综合/后端使用：

```text
top      = tinyriscv_4core_top
filelist = sim/filelist.f
include  = rtl/include
```

`sim/filelist.f` 第一行 `+incdir+../rtl/include` 是宏头文件搜索路径，后续每行是一个
Verilog 源文件；相对路径以 `sim/` 为当前目录。`.f` 不是 Verilog 文件，不能设置为顶层。
如果误删，可在工程根目录执行 `python tools/build_filelist.py` 重建。

FPGA 综合或端到端仿真额外使用：

```text
top      = tinyriscv_4core_fpga_top
filelist = fpga/filelist.f
```

`fpga/filelist.f` 先引用 ASIC 清单，再加入 YC/YX/PJY/Khoree 四套 FPGA-side bridge、
唯一 YC ROM/RAM 与包装顶层。
不要再加入旧的四套 `sim/models`；最终交付中也已删除该目录。

## 2. 五个 testbench

| 文件 / Simulation Top | 作用 | 参数与通过条件 |
|---|---|---|
| `shared_arbiter_tb.v` | `chip_sel`、复位隔离、共享 regs/PWM、非法选择 | 无；`TEST_PASS shared_arbiter` |
| `shared_uart_debug_tb.v` | 35-byte UART debug 下载、CRC/ACK、四核选择 | `+CHIP_SEL=0..3`；`TEST_PASS shared_uart_debug_35byte_crc_ack` |
| `fourcore_rv32i_smoke_tb.v` | 同一共享 YC ROM 中的程序依次在四核运行 | `+INST_FILE=...`；`TEST_PASS fourcore_RV32I` |
| `fourcore_pwm_program_tb.v` | 四核端到端访问唯一 YC PWM，核对周期/占空比/使能 | `+INST_FILE=.../PWM_inst.data`；`TEST_PASS fourcore_PWM_program shared_yc_pwm` |
| `fourcore_program_probe_tb.v` | DIV/DIVU/REM/REMU、LED/GPIO 删除功能的有界负测 | `+INST_FILE=... +CORE=0..3`；必须同时出现 `status=NO_PASS` 和 `TEST_PASS bounded_program_probe` |

端到端 TB 例化 `tinyriscv_4core_fpga_top`，并通过 `dut.u_rom._rom` 加载唯一共享 ROM。
四个 core 的访问先分别经过自己协议对应的 chip-side/FPGA-side bridge，再仲裁到共享存储。

## 3. 仿真脚本

| 文件 | 用途 |
|---|---|
| `run_modelsim.ps1` | 20 个 RV32I × 4 核、PWM、UART debug、仲裁 |
| `run_vcs_regression.sh` | 服务器 VCS 全回归并生成代表性 FSDB |
| `run_verdi_checks.sh` | 批量加载 RV32I、PWM、UART debug FSDB |
| `check_vcs_results.sh` | 扫描已有 VCS 日志 |
| `Makefile` | 单项 VCS 编译/运行入口 |

脚本会在工程外部或 `output/` 产生过程文件；这些不属于交付源码。建议显式指定临时目录：

```bash
cd sim
BUILD_ROOT=/tmp/$USER-tinyriscv-4core ./run_vcs_regression.sh
./run_verdi_checks.sh /tmp/$USER-tinyriscv-4core ../output
```

## 4. Vivado 添加方法

在已打开的 Vivado 工程 Tcl Console 中，ASIC 模式：

```tcl
set TINYRISCV_TARGET chip
source D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/tools/vivado_add_sources.tcl
```

FPGA 模式：

```tcl
set TINYRISCV_TARGET fpga
source D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/tools/vivado_add_sources.tcl
```

PAD 包装层展开/后端交接模式：

```tcl
set TINYRISCV_TARGET chip_io
source D:/tiny_riscv/tinyriscv_4core/tools/vivado_add_sources.tcl
```

`chip_io` 只添加 `tinyriscv_4core_top_IO.v` 并设置顶层，不会自动添加工艺库。综合前必须
加入课程提供的真实 `PDDW0204CDG` PAD library 模型或网表。`tb/pddw0204cdg_stub.v` 只用于
RTL 展开检查，绝不能加入综合或后端 Design Sources。

XSim 运行 RV32I 示例：

```tcl
set TINYRISCV_TARGET fpga
set TINYRISCV_SIM_TB fourcore_rv32i_smoke_tb
source D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/tools/vivado_add_sources.tcl
```

然后在 Simulation Settings 中加入：

```text
+INST_FILE=D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/firmware/test_command/Baisc_Inst_Example/inst_add.data
```

脚本会自动设置 `rtl/include`。手工添加时也必须把该目录设置为 Verilog Include
Directory，否则 `*_defines.vh` 无法找到。

## 5. 后端与 FPGA 的边界

- 后端只取 `rtl/`、`sim/filelist.f`、`rtl/include/`，顶层是
  `tinyriscv_4core_top`；插入 TSMC180 PAD 时改用 `tinyriscv_4core_top_IO`，并加入课程
  PAD library 模型/网表。不要用普通 RTL 仿真的 `000..011` 直接解释包装层物理编码。
- FPGA 再取 `fpga/` 和程序文件，顶层是 `tinyriscv_4core_fpga_top`。
- `tb/`、仿真脚本、FSDB 代码不加入 Design Sources。
- 当前无 XDC；必须按实际板卡新建，不能猜测或复用旧单核引脚。
- 扩展指令不是本轮验收范围；基础 RV32I、共享外设与删除功能负测结果见
  `VERIFICATION_REPORT.md`。
