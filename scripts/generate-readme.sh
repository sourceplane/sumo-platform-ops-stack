#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_mode="${1:-}"

python3 - "$repo_root" "$check_mode" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
check_mode = sys.argv[2] == "--check"
dirty: list[str] = []


def extract(pattern: str, text: str) -> str:
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise SystemExit(f"missing pattern: {pattern!r}")
    return match.group(1).strip()


def write_or_check(path: Path, content: str) -> None:
    normalized = content.rstrip() + "\n"
    current = path.read_text() if path.exists() else None
    if current == normalized:
        return
    dirty.append(str(path.relative_to(root)))
    if not check_mode:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(normalized)


for contract in sorted((root / "compositions").glob("*/compositions.yaml")):
    text = contract.read_text()
    name = extract(r"^  name:\s*(.+)$", text)
    description = extract(r"^  description:\s*(.+)$", text)
    comp_dir = contract.parent

    readme = f"""# {name}

`{name}` is an exported Orun composition in the Sumo Platform Ops catalog.

## Purpose

{description}

## Contract

- **Type:** `{name}`
- **Path:** `{comp_dir.relative_to(root)}`
- **Definition:** `compositions.yaml`

## Catalog status

This folder is intentionally self-contained so examples, smoke coverage, and future registry metadata can live beside the composition contract.

## Next steps

- add runnable example assets under `examples/`
- add composition-specific smoke coverage under `tests/`
- keep the contract description in `compositions.yaml` aligned with the repo scorecard
"""

    examples_readme = f"""# Examples for {name}

Put consumer-facing example assets for `{name}` here.

The scorecard only counts example assets beyond this placeholder README.
"""

    tests_readme = f"""# Tests for {name}

Put composition-specific smoke tests or validation fixtures for `{name}` here.

The scorecard only counts test assets beyond this placeholder README.
"""

    write_or_check(comp_dir / "README.md", readme)
    write_or_check(comp_dir / "examples" / "README.md", examples_readme)
    write_or_check(comp_dir / "tests" / "README.md", tests_readme)

if check_mode and dirty:
    print("Generated composition docs are stale:")
    for item in dirty:
        print(f" - {item}")
    raise SystemExit(1)
PY
