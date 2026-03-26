#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: normalize-stow-links.py <repo-root> <packages>", file=sys.stderr)
        return 1

    repo = Path(sys.argv[1]).resolve()
    packages = sys.argv[2].split()
    home = Path.home().resolve()

    for package in packages:
        package_root = repo / package
        if not package_root.exists():
            continue

        for source in package_root.rglob("*"):
            if source.is_dir():
                continue

            target = home / source.relative_to(package_root)
            if not target.is_symlink():
                continue

            raw_target = Path(os.readlink(target))
            resolved_target = (target.parent / raw_target).resolve() if not raw_target.is_absolute() else raw_target.resolve()
            if resolved_target != source.resolve():
                continue

            expected = os.path.relpath(source, start=target.parent)
            if str(raw_target) == expected:
                continue

            print(f"normalizing {target}")
            target.unlink()
            target.symlink_to(expected)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
