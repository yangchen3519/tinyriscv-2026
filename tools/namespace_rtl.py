from __future__ import annotations

import re
import shutil
import argparse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUTS = ROOT / "inputs"
OUTPUT = ROOT / "rtl" / "cores"
INCLUDE = ROOT / "rtl" / "include"

CONFIG = {
    "yc": INPUTS / "yc" / "rtl",
    "yx": INPUTS / "yx",
    "pjy": INPUTS / "pjy" / "rtl",
    "khoree": INPUTS / "khoree" / "khoree_soc",
}


def source_files(owner: str, base: Path) -> list[Path]:
    if owner == "khoree":
        roots = [base / name for name in ("core", "debug", "perips", "soc", "utils")]
    else:
        roots = [base]
    return sorted(p for root in roots for p in root.rglob("*.v"))


def defines_file(owner: str, base: Path) -> Path:
    if owner == "khoree":
        return base / "header" / "defines.vh"
    if owner == "yx":
        return base / "core" / "defines.v"
    return base / "core" / "defines.v"


def defined_macros(text: str) -> list[str]:
    return re.findall(r"(?m)^\s*`define\s+([A-Za-z_]\w*)", text)


def module_names(files: list[Path]) -> list[str]:
    result: set[str] = set()
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        result.update(re.findall(r"(?m)^\s*module\s+([A-Za-z_]\w*)", text))
    return sorted(result, key=len, reverse=True)


def namespace_text(text: str, owner: str, macros: list[str], modules: list[str]) -> str:
    prefix = owner.upper()
    for macro in sorted(macros, key=len, reverse=True):
        text = re.sub(
            rf"(?m)^([ \t]*`define[ \t]+){re.escape(macro)}\b",
            rf"\1{prefix}_{macro}",
            text,
        )
        text = re.sub(rf"`{re.escape(macro)}\b", f"`{prefix}_{macro}", text)

    text = re.sub(
        r'`include\s+["<][^">]*(?:defines\.v|defines\.vh)[">]',
        f'`include "{owner}_defines.vh"',
        text,
    )

    for module in modules:
        renamed = f"{owner}_{module}"
        text = re.sub(
            rf"(?m)^(\s*module\s+){re.escape(module)}\b",
            rf"\1{renamed}",
            text,
        )
        text = re.sub(
            rf"(?m)^(\s*){re.escape(module)}(\s*(?:#\s*\(|[A-Za-z_]\w*\s*\())",
            rf"\1{renamed}\2",
            text,
        )
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("owners", nargs="*", choices=sorted(CONFIG),
                        help="owners to regenerate; default: all")
    args = parser.parse_args()
    owners = args.owners or [owner for owner in CONFIG if owner != "khoree"]
    if "khoree" in owners:
        raise SystemExit(
            "Khoree is integration-managed after namespacing; generic regeneration "
            "would overwrite the shared-reg/PWM/debug wrapper adaptations."
        )

    OUTPUT.mkdir(parents=True, exist_ok=True)
    INCLUDE.mkdir(parents=True, exist_ok=True)

    for owner in owners:
        base = CONFIG[owner]
        owner_output = OUTPUT / owner
        if owner_output.exists():
            shutil.rmtree(owner_output)
        files = source_files(owner, base)
        define_path = defines_file(owner, base)
        define_text = define_path.read_text(encoding="utf-8", errors="replace")
        macros = defined_macros(define_text)
        modules = module_names(files)

        header = namespace_text(define_text, owner, macros, modules)
        (INCLUDE / f"{owner}_defines.vh").write_text(header, encoding="utf-8", newline="\n")

        for path in files:
            if path.resolve() == define_path.resolve():
                continue
            rel = path.relative_to(base)
            if owner == "khoree" and rel.as_posix() in {
                "core/regs.v", "perips/pwm.v", "debug/uart_debug.v"
            }:
                continue
            target = OUTPUT / owner / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            text = path.read_text(encoding="utf-8", errors="replace")
            target.write_text(
                namespace_text(text, owner, macros, modules),
                encoding="utf-8",
                newline="\n",
            )

        print(f"{owner}: {len(files)} Verilog files, {len(modules)} modules, {len(macros)} macros")


if __name__ == "__main__":
    main()
