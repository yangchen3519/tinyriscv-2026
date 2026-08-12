# 当前版本与 GitHub 基线合并记录

合并日期：2026-08-12

基线提交：`2da36bd8078c268fab19a7daca161503e78c04f2`

本地集成分支：`integrate/private-bridges-current`

## 采用的版本

- 四核存储接口采用当前 `tinyriscv_4core` 的四套私有 bridge 架构。
- YC/PJY/YX/Khoree 分别使用 `yc_bridge_core`、`pjy_mem_bridge_chip`、`yx_bridge`、
  `khoree_mem_bridge_chip`。
- FPGA/仿真侧保留四个匹配协议解码器，随后仲裁到唯一 YC ROM/RAM。
- 保留当前 PJY 学号 `2025210902` 和 IF 返回 `0x8A` 的修复。
- 保留当前 YC bridge 对未知状态的严格比较修复。

## 从 GitHub 基线保留并适配的内容

- 保留 `tinyriscv_4core_top_IO` 的 TSMC180 PAD 实例和实例名。
- 包装层把旧物理低有效选择编码 `111/110/101/011` 转换为逻辑顶层的
  `000/001/010/011`，其他编码转换为非法选择。
- 逻辑顶层重新导出 I²C 开漏 `drive_low` 信号供 PAD `OEN` 使用。
- 保留 Khoree 在 UART debug 下载期间冻结 CPU、ROM/RAM 请求等待 bridge 完成后再 ACK
  的逻辑，并接到新的 Khoree 私有 bridge。
- 更新 Vivado 导入脚本，支持 `chip`、`chip_io`、`fpga` 三种目标。

## 未合并的过程文件

没有导入 `.vvp`、FSDB、日志、ModelSim work 库、Vivado 缓存、`output/`、`results/`
或旧输入归档。新增 `.gitignore` 防止这些文件后续被误提交。

## 合并后验证

- 资源静态审计 PASS；
- ModelSim 编译 0 error、0 warning；
- 20 个基础程序 × 4 核：80/80 PASS；
- 共享 PWM：4/4 PASS；
- UART debug 35-byte packet：4/4 PASS；
- 共享仲裁/非法选择：PASS；
- PAD 包装顶层展开与选择映射：PASS。

合并后已在服务器使用 VCS `R-2020.12-SP1_Full64` 完成回归，输出
`VCS_REGRESSION_PASS`；Verdi 成功批量加载 RV32I、PWM、UART debug 代表性 FSDB，输出
`VERDI_BATCH_LOAD_PASS`。本轮没有执行 Vivado 综合或后端实现。
