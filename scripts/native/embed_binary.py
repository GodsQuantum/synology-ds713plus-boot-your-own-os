#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def emit_c_array(input_path: Path, symbol: str) -> str:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", symbol):
        raise ValueError("invalid C identifier")
    data = input_path.read_bytes()
    rows = []
    for pos in range(0, len(data), 16):
        rows.append("  " + ", ".join(f"0x{b:02x}" for b in data[pos:pos + 16]))
    body = ",\n".join(rows)
    return (
        "#include <Uefi.h>\n\n"
        f"CONST UINT8 {symbol}[] = {{\n{body}\n}};\n"
        f"CONST UINTN {symbol}Size = sizeof ({symbol});\n"
    )


def main() -> None:
    src, symbol, dst = sys.argv[1:4]
    Path(dst).write_text(emit_c_array(Path(src), symbol))


if __name__ == "__main__":
    main()
