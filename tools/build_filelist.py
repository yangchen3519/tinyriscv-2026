#!/usr/bin/env python3
"""Build a deterministic filelist containing only the effective 4-core hierarchy."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
OUT = ROOT / "sim" / "filelist.f"

files = list(sorted(RTL.rglob("*.v")))
module_to_file = {}
texts = {}
for path in files:
    text = path.read_text(encoding="utf-8", errors="replace")
    texts[path] = text
    for name in re.findall(r"(?m)^\s*module\s+([A-Za-z_]\w*)", text):
        if name in module_to_file:
            raise SystemExit(f"duplicate module {name}: {module_to_file[name]} and {path}")
        module_to_file[name] = path

roots = ["tinyriscv_4core_top"]
needed_modules = set()
pending = roots[:]
while pending:
    owner = pending.pop()
    if owner in needed_modules:
        continue
    if owner not in module_to_file:
        raise SystemExit(f"missing root/dependency module: {owner}")
    needed_modules.add(owner)
    text = texts[module_to_file[owner]]
    for candidate in module_to_file:
        if candidate == owner or candidate in needed_modules:
            continue
        # Supports ordinary and parameterized Verilog-2000 instantiations.
        pat = rf"\b{re.escape(candidate)}\s*(?:#\s*\(.*?\)\s*)?\w+\s*\("
        if re.search(pat, text, flags=re.S):
            pending.append(candidate)

needed_files = sorted({module_to_file[name] for name in needed_modules})
forbidden_pjy = {"pjy_div", "pjy_csr_reg", "pjy_clint", "pjy_jtag_top",
                 "pjy_jtag_dm", "pjy_jtag_driver", "pjy_timer", "pjy_spi",
                 "pjy_gpio", "pjy_pwm", "pjy_uart_debug", "pjy_regs"}
present_forbidden = forbidden_pjy & needed_modules
if present_forbidden:
    raise SystemExit("forbidden PJY modules remain reachable: " + ", ".join(sorted(present_forbidden)))

forbidden_final = {
    "khoree_regs", "khoree_pwm", "khoree_uart_debug", "khoree_div",
    "khoree_csr_reg", "khoree_clint", "khoree_jtag_top",
    "khoree_jtag_dm", "khoree_jtag_driver",
}
present_forbidden = forbidden_final & needed_modules
if present_forbidden:
    raise SystemExit("forbidden Khoree modules remain reachable: " +
                     ", ".join(sorted(present_forbidden)))

forbidden_nonchip = {
    "yc_bridge_FPGA", "yc_rom", "yc_ram", "yx_fpga_bridge",
    "yx_fpga_rom", "yx_fpga_ram", "pjy_mem_bridge_fpga",
    "pjy_rom", "pjy_ram", "khoree_mem_bridge_fpga",
    "khoree_ext_rom", "khoree_ext_ram",
}
present_nonchip = forbidden_nonchip & needed_modules
if present_nonchip:
    raise SystemExit("simulation-only memory logic remains reachable: " +
                     ", ".join(sorted(present_nonchip)))

unused_files = set(files) - set(needed_files)
if unused_files:
    raise SystemExit("unused Verilog files remain under rtl/: " +
                     ", ".join(str(p.relative_to(RTL)) for p in sorted(unused_files)))

lines = ["+incdir+../rtl/include"]
for path in needed_files:
    lines.append("../" + path.relative_to(ROOT).as_posix())
OUT.write_text("\n".join(lines) + "\n", encoding="ascii")

print(f"wrote {OUT} ({len(needed_modules)} modules in {len(needed_files)} files)")
for owner in ("yc", "yx", "pjy", "khoree"):
    print(f"{owner}: {sum(name.startswith(owner + '_') for name in needed_modules)} modules")
