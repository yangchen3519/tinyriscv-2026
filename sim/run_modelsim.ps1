param([string]$ModelSimBin = "D:\modelsim2020.4\win64")
$ErrorActionPreference = "Stop"
$sim = Resolve-Path $PSScriptRoot
$root = Split-Path $sim -Parent
$work = Join-Path $sim "work_regression"
$output = Join-Path $root "output"
New-Item -ItemType Directory -Force $output | Out-Null
if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
& (Join-Path $ModelSimBin "vlib.exe") $work | Out-Null
Push-Location $sim
try {
    & (Join-Path $ModelSimBin "vlog.exe") -work $work -f filelist.f
    & (Join-Path $ModelSimBin "vlog.exe") -work $work "+incdir+../rtl/include" `
        ../fpga/rtl/yc_bridge_FPGA.v ../fpga/rtl/yc_rom.v ../fpga/rtl/yc_ram.v `
        ../fpga/rtl/tinyriscv_4core_fpga_top.v ../tb/shared_arbiter_tb.v ../tb/shared_uart_debug_tb.v `
        ../tb/fourcore_rv32i_smoke_tb.v ../tb/fourcore_pwm_program_tb.v
    & (Join-Path $ModelSimBin "vmap.exe") work_regression $work | Out-Null
    $tests = @("shared_arbiter_tb", "shared_uart_debug_tb")
    foreach ($top in $tests) {
        $log = Join-Path $output "$top.regression.log"
        & (Join-Path $ModelSimBin "vsim.exe") -c -quiet -lib work_regression $top -do "run -all; quit -f" | Set-Content $log
        $text = Get-Content $log -Raw
        if ($text -notmatch "TEST_PASS" -or $text -match "TEST_FAIL") { throw "$top failed" }
    }
    $cases = Get-ChildItem ../firmware/test_command/Baisc_Inst_Example/*.data |
        Where-Object { $_.Name -notmatch '^inst_(div|divu|rem|remu)\.data$' }
    foreach ($case in $cases) {
        $log = Join-Path $output ("fourcore_" + $case.BaseName + ".regression.log")
        $arg = "+INST_FILE=" + $case.FullName.Replace("\", "/")
        & (Join-Path $ModelSimBin "vsim.exe") -c -quiet -lib work_regression fourcore_rv32i_smoke_tb $arg -do "run -all; quit -f" | Set-Content $log
        $text = Get-Content $log -Raw
        if ($text -notmatch "TEST_PASS" -or $text -match "TEST_FAIL") { throw "$($case.Name) failed" }
    }
    $pwmLog = Join-Path $output "fourcore_pwm_program.regression.log"
    & (Join-Path $ModelSimBin "vsim.exe") -c -quiet -lib work_regression fourcore_pwm_program_tb `
        "+INST_FILE=../firmware/test_command/Other_Example/PWM/PWM_inst.data" `
        -do "run -all; quit -f" | Set-Content $pwmLog
    $pwmText = Get-Content $pwmLog -Raw
    if ($pwmText -notmatch "TEST_PASS" -or $pwmText -match "TEST_FAIL") { throw "PWM program failed" }
    Write-Host "MODELSIM_REGRESSION_PASS cases=$($cases.Count) core_runs=$($cases.Count * 4)"
} finally { Pop-Location }
