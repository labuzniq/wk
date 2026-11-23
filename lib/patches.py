"""Recorded patches for third-party skills and agents: patches/<kind>/<name>.patch in the kit."""
import hashlib
import subprocess
import sys
from pathlib import Path


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def patch_for(kit: Path, kind: str, name: str) -> Path | None:
    patch = kit / "patches" / kind / f"{name}.patch"
    return patch if patch.exists() else None


def path_outside(patch: Path) -> str | None:
    """The first path in the patch that would land outside the folder it is applied in, if any."""
    for line in patch.read_text().splitlines():
        if line.startswith(("--- ", "+++ ")):
            path = line[4:].split("\t")[0].strip()
            if path != "/dev/null" and (path.startswith("/") or ".." in Path(path).parts):
                return path
    return None


def apply(patch: Path, folder: Path, what: str) -> None:
    """Apply the patch to the files in the folder, or stop and name what it no longer fits."""
    outside = path_outside(patch)
    if outside:
        sys.exit(f"{what}: {patch} names a path outside the folder it patches ({outside}); keep its paths inside.")
    for extra in (["--dry-run"], []):
        result = subprocess.run(
            ["patch", "-p1", "-s", "-F", "0", "-E", "--no-backup-if-mismatch", *extra, "-d", str(folder), "-i", str(patch)],
            check=False, capture_output=True, text=True,
        )
        if result.returncode != 0:
            sys.exit(
                f"{what}: {patch} no longer applies; change the patch to fit the new upstream text, or delete it.\n"
                + (result.stdout + result.stderr).strip()
            )
