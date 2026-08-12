# FPGA 上板事项

## 1. 已提供的可综合 FPGA 顶层

直接使用 `fpga/rtl/tinyriscv_4core_fpga_top.v`，无需再设计四协议适配器。当前实际结构是：

```text
tinyriscv_4core_fpga_top
├─ tinyriscv_4core_top u_chip
│  ├─ 四个 core（只有 chip_sel 选中的核运行）
│  ├─ 一份 YC regs / PWM / uart_debug
│  └─ 四份各自协议的 chip-side bridge
├─ YC/YX/PJY/Khoree 四份匹配的 FPGA-side bridge
├─ chip_sel 存储仲裁
├─ yc_rom u_rom
└─ yc_ram u_ram
```

因此 ROM/RAM 是共享的 YC 实现，bridge 则按四个 core 的原始协议分别保留。前仿真与
FPGA 上板使用相同的四 bridge + 一份存储结构。

## 2. Vivado Design Sources

推荐在 Tcl Console 执行：

```tcl
set TINYRISCV_TARGET fpga
source D:/tiny_riscv/tinyriscv_4core_chiprtl/tinyriscv_4core/tools/vivado_add_sources.tcl
```

或手工加入 `sim/filelist.f` 和以下文件：

```text
fpga/rtl/yc_bridge_FPGA.v
fpga/rtl/yx_fpga_bridge.v
fpga/rtl/pjy_mem_bridge_fpga.v
fpga/rtl/khoree_mem_bridge_fpga.v
fpga/rtl/yc_rom.v
fpga/rtl/yc_ram.v
fpga/rtl/tinyriscv_4core_fpga_top.v
```

Design Top 设置为 `tinyriscv_4core_fpga_top`，Include Directory 设置为
`rtl/include`。不要把 `tb/` 或 `sim/*.sh` 加入 Design Sources。

## 3. 程序如何进入 ROM

仿真 TB 通过 `$readmemh` 写 `dut.u_rom._rom`。当前 `yc_rom` 本身没有固定初始化文件，
因此实际上板前必须选一种方式：

1. 将目标 `.data` 转为 Vivado `.mem/.coe` 并初始化 BRAM；
2. 在 FPGA 专用 `yc_rom` 中加入可综合、路径稳定的 `$readmemh`；
3. 使用共享 `uart_debug` 下载程序。

测试程序在 `firmware/test_command/`。四核始终使用同一份 ROM，切换 core 时无需准备四份
程序存储，只需在复位期间改变 `chip_sel`。

## 4. XDC 与顶层引脚

本交付没有 XDC，因为旧单核约束不匹配。应根据实际开发板约束这些 FPGA 顶层端口：

```text
clk, rst, chip_sel[2:0], uart_debug_en, uart_rx, uart_tx,
PWM_o[3:0], i2c_scl, i2c_sda, over, succ
```

`rst` 低有效。I2C 是开漏双向信号，需要正确的 IOBUF/外部上拉和电气标准。ROM/RAM bridge
已在 FPGA 顶层内部，不需要绑定外部引脚。不要随意填写 PACKAGE_PIN。

## 5. 上板顺序

1. 加入 FPGA filelist，设置顶层和 include directory。
2. 根据板卡创建 XDC，先完成时钟、复位和 `chip_sel`。
3. 初始化 `inst_add.data`，设置 `rst=0`、选择核、保持数个时钟后再令 `rst=1`。
4. 依次验证 `000/001/010/011`，观察 `over/succ`。
5. 运行其余 20 个 RV32I 程序。
6. 运行 PWM 程序，确认四核控制同一组 `PWM_o[3:0]`。
7. 验证 UART debug 下载、普通 UART 和 I2C。
8. 测试非法 `chip_sel=100~111`，确认无写入副作用。

禁止在 `rst=1`、CPU 正在运行时切换 `chip_sel`。

## 6. 综合后检查

- 顶层只有一个 `tinyriscv_4core_top`；
- YC regs、PWM、uart_debug 各一个；
- 四核各一套 chip-side bridge，各有一个匹配的 FPGA-side bridge；
- YC ROM、RAM 各一个，没有四份私有 ROM/RAM；
- 没有 DIV/REM、乘法器、CSR、CLINT、JTAG、Timer、SPI、GPIO 等已删除 PJY 逻辑；
- 没有多驱动、锁存器、关键悬空端口或未约束 IO；
- 时钟和 I2C 电气约束正确，时序满足目标频率。

如 BRAM 数量不是预期的一份 ROM 加一份 RAM，先检查是否重复加入了旧 wrapper 或手工又
例化了存储。
