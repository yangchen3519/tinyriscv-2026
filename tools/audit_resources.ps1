$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$filelist = Get-Content (Join-Path $root "sim\filelist.f") -Raw
$forbidden = @(
    "pjy_div", "pjy_csr_reg", "pjy_clint", "pjy_jtag", "pjy_timer", "pjy_spi", "pjy_gpio", "pjy_pwm", "pjy_uart_debug", "pjy_regs",
    "khoree_div", "khoree_csr_reg", "khoree_clint", "khoree_jtag", "khoree_pwm", "khoree_uart_debug", "khoree_regs",
    "bridge_FPGA", "fpga_bridge", "mem_bridge_fpga", "ext_rom", "ext_ram"
)
$errors = @()
foreach ($name in $forbidden) {
    if ($filelist -match [regex]::Escape($name)) { $errors += "forbidden PJY entry: $name" }
}
$top = Get-Content (Join-Path $root "rtl\tinyriscv_4core_top.v") -Raw
foreach ($instance in @("yc_regs u_shared_regs", "yc_pwm u_shared_pwm", "yc_uart_debug u_shared_uart_debug")) {
    if (([regex]::Matches($top, [regex]::Escape($instance))).Count -ne 1) { $errors += "shared instance count: $instance" }
}
foreach ($instance in @("yc_bridge_core u_yc_mem_bridge", "yx_bridge u_yx_mem_bridge", "pjy_mem_bridge_chip u_pjy_mem_bridge", "khoree_mem_bridge_chip u_kh_mem_bridge")) {
    if (([regex]::Matches($top, [regex]::Escape($instance))).Count -ne 1) { $errors += "private bridge instance count: $instance" }
}
$resourceFiles = ($filelist -split "`r?`n") | Where-Object { $_ -match '(?i)(regs|pwm|uart_debug)\.v\s*$' }
$expectedResourceFiles = @('../rtl/shared/yc_pwm.v', '../rtl/shared/yc_regs.v', '../rtl/shared/yc_uart_debug.v')
foreach ($entry in $resourceFiles) {
    if ($expectedResourceFiles -notcontains $entry.Trim()) { $errors += "non-shared resource file in final filelist: $entry" }
}
if ($resourceFiles.Count -ne 3) { $errors += "expected exactly three shared resource source entries, got $($resourceFiles.Count)" }

$wrapperFiles = @(
    "rtl\cores\yc\soc\tinyriscv_soc_top.v",
    "rtl\cores\yx\soc\tinyriscv_soc_top.v",
    "rtl\cores\pjy\soc\tinyriscv_soc_top.v",
    "rtl\cores\khoree\soc\tinyriscv_soc_top.v"
)
foreach ($relative in $wrapperFiles) {
    $wrapper = Get-Content (Join-Path $root $relative) -Raw
    if ($wrapper -match '(?m)^\s*(yc_|yx_|pjy_|khoree_)?pwm\s+\w+\s*\(') { $errors += "private PWM instance in final wrapper: $relative" }
    if ($wrapper -match '(?m)^\s*(yc_|yx_|pjy_|khoree_)?uart_debug\s+\w+\s*\(') { $errors += "private uart_debug instance in final wrapper: $relative" }
}
if ($filelist -match 'tinyriscv_fpga_top\.v') { $errors += "test-only PJY FPGA wrapper is in final filelist" }
$rtlVerilog = Get-ChildItem (Join-Path $root "rtl") -Recurse -File -Filter "*.v"
foreach ($file in $rtlVerilog) {
    if ($file.Name -match '(?i)(^|_)(rom|ram)(_|\.)|fpga.*bridge|bridge.*fpga') {
        $errors += "non-chip source remains under rtl: $($file.FullName)"
    }
}
$effective = Get-Content (Join-Path $root "rtl\cores\pjy\core\tinyriscv.v") -Raw
foreach ($module in @("pjy_div u_", "pjy_csr_reg u_", "pjy_clint u_")) {
    if ($effective -match [regex]::Escape($module)) { $errors += "reachable PJY instance: $module" }
}
$pjyEx = Get-Content (Join-Path $root "rtl\cores\pjy\core\ex.v") -Raw
foreach ($pattern in @('PJY_INST_MUL', 'mul_temp', 'mul_op1', 'mul_op2')) {
    if ($pjyEx -match [regex]::Escape($pattern)) { $errors += "reachable PJY multiplier residue: $pattern" }
}
$khoreeTree = (Get-ChildItem (Join-Path $root "rtl\cores\khoree") -Recurse -File -Filter "*.v" |
    Where-Object { $_.Name -notin @("regs.v", "pwm.v", "uart_debug.v") } |
    ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"
foreach ($pattern in @('khoree_div u_', 'khoree_csr_reg u_', 'khoree_clint u_', 'khoree_jtag_top u_')) {
    if ($khoreeTree -match [regex]::Escape($pattern)) { $errors += "reachable Khoree instance: $pattern" }
}
if ($errors.Count) {
    $errors | ForEach-Object { Write-Host "AUDIT_FAIL $_" }
    exit 1
}
Write-Host "AUDIT_PASS chip_rtl_only; four_private_chip_bridges; no_ROM_RAM_or_FPGA_bridge; no_unused_Verilog; 4cores+3shared; PJY_and_Khoree_forbidden_hierarchy_absent"
