#!/usr/bin/env python3
import os
import sys
import subprocess
from pathlib import Path

def apply_patch(repo_dir: Path, patch_path: Path):
    rel_patch = patch_path.name
    cmd = ["git", "apply", "--ignore-space-change", "--ignore-whitespace", str(patch_path)]
    result = subprocess.run(cmd, cwd=str(repo_dir), capture_output=True, text=True)
    if result.returncode == 0:
        return True, ""
    
    # Try with patch -p1 as fallback
    patch_cmd = ["patch", "-p1", "--ignore-whitespace", "-f"]
    with open(patch_path, "rb") as f:
        res2 = subprocess.run(patch_cmd, cwd=str(repo_dir), stdin=f, capture_output=True, text=True)
    if res2.returncode == 0:
        return True, ""
    
    return False, result.stderr or res2.stderr

def init_git(repo_dir: Path):
    if not (repo_dir / ".git").is_dir():
        subprocess.run(["git", "init", "-q"], cwd=str(repo_dir), check=True)
        subprocess.run(["git", "config", "user.name", "Termux"], cwd=str(repo_dir), check=True)
        subprocess.run(["git", "config", "user.email", "termux@localhost"], cwd=str(repo_dir), check=True)

def main():
    if len(sys.argv) < 2:
        print("Usage: apply_brave_patches.py <src_dir>")
        sys.exit(1)

    src_dir = Path(sys.argv[1]).resolve()
    brave_patches = src_dir / "brave" / "patches"
    if not brave_patches.is_dir():
        print(f"Error: {brave_patches} does not exist.")
        sys.exit(1)

    init_git(src_dir)

    patch_groups = [
        (src_dir, [p for p in brave_patches.iterdir() if p.is_file() and p.name.endswith(".patch")]),
        (src_dir / "v8", list((brave_patches / "v8").glob("*.patch")) if (brave_patches / "v8").is_dir() else []),
        (src_dir / "third_party" / "catapult", list((brave_patches / "third_party" / "catapult").glob("*.patch")) if (brave_patches / "third_party" / "catapult").is_dir() else []),
        (src_dir / "third_party" / "devtools-frontend" / "src", list((brave_patches / "third_party" / "devtools-frontend" / "src").glob("*.patch")) if (brave_patches / "third_party" / "devtools-frontend" / "src").is_dir() else []),
        (src_dir / "third_party" / "search_engines_data" / "resources", list((brave_patches / "third_party" / "search_engines_data" / "resources").glob("*.patch")) if (brave_patches / "third_party" / "search_engines_data" / "resources").is_dir() else []),
        (src_dir / "third_party" / "tflite" / "src", list((brave_patches / "third_party" / "tflite" / "src").glob("*.patch")) if (brave_patches / "third_party" / "tflite" / "src").is_dir() else []),
    ]

    total_applied = 0
    total_skipped = 0

    for target_dir, patches in patch_groups:
        if not patches:
            continue
        if not target_dir.is_dir():
            print(f"Target dir {target_dir} not present, skipping {len(patches)} patches.")
            total_skipped += len(patches)
            continue

        init_git(target_dir)
        patches.sort()
        print(f"Applying {len(patches)} patches in {target_dir}...")
        for p in patches:
            ok, err = apply_patch(target_dir, p)
            if ok:
                total_applied += 1
            else:
                total_skipped += 1
                print(f"  [WARN] Skipping failed patch {p.name}: {err.strip().splitlines()[0] if err else ''}")

    print(f"Finished applying Brave patches: {total_applied} applied, {total_skipped} skipped/failed.")

if __name__ == "__main__":
    main()
