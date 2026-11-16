#!/usr/bin/env python3
"""Compare the software on this Mac with what the dotfiles repo declares.

Usage:
    python3 scripts/inventory.py

Declared (expected) software comes from:
    Brewfile                 Homebrew formulae and casks
    inventory/software.tsv   apps and tools installed by hand
    conda/*.yml              named Conda environments (optional)

Output:
    Unlisted install   found on this Mac but not declared in the repo
    Missing locally    declared in the repo but not found on this Mac

Patterns in inventory/exclude.txt are ignored on both sides. The script only
reads; it never installs or removes anything.

Exit status: 0 when both lists are empty, 1 when they differ, 2 when a
required repo file is missing or unreadable.
"""

import argparse
import csv
import fnmatch
import json
import os
import re
import sys
from pathlib import Path

# ------------------------------------------------------------------------------
#  Settings
# ------------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parents[1]  # repo root
HOME = Path.home()

BREWFILE = ROOT / "Brewfile"
SOFTWARE = ROOT / "inventory/software.tsv"
EXCLUDE = ROOT / "inventory/exclude.txt"
DISCOVERY_COLUMN = "Discovery names"

# Conda roots, in the same order as .zshrc and install.sh.
CONDA_ROOTS = [Path(p) for p in (os.environ.get("CONDA_ROOT"), "/opt/miniconda3", HOME / "miniconda3") if p]

# ------------------------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------------------------


class InventoryError(Exception):
    """A required repo file is missing or cannot be used."""


def read_json(path):
    """Return the parsed content of a JSON file, or None if it is unreadable."""
    try:
        return json.loads(path.read_bytes())
    except (OSError, ValueError) as error:
        print(f"Skipped unreadable file: {path} ({error})", file=sys.stderr)
        return None


def read_repo_text(path):
    """Return the text of a file that the repo must contain."""
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        raise InventoryError(f"Cannot read {path.relative_to(ROOT)}: {error.strerror}") from error


def brew_name(name, receipt, default_tap):
    """Return the Brewfile name: short for core taps, tap-qualified otherwise.

    Older receipts have no source tap; those are treated as core packages.
    """
    tap = (receipt.get("source") or {}).get("tap") or default_tap
    return name if tap in ("homebrew/core", "homebrew/cask") else f"{tap}/{name}"


# ------------------------------------------------------------------------------
#  Declared software (from the repo)
# ------------------------------------------------------------------------------


def load_exclusions():
    """Return the lower-cased patterns from inventory/exclude.txt."""
    lines = (line.strip() for line in read_repo_text(EXCLUDE).splitlines())
    return [line.casefold() for line in lines if line and not line.startswith("#")]


def load_declared():
    """Return every "<kind>:<name>" key the repo declares."""
    declared = set()

    # Software installed by hand
    rows = csv.DictReader(read_repo_text(SOFTWARE).splitlines(), delimiter="\t")
    if DISCOVERY_COLUMN not in (rows.fieldnames or []):
        raise InventoryError(f'{SOFTWARE.relative_to(ROOT)} has no "{DISCOVERY_COLUMN}" column')
    for row in rows:
        declared.update(key for key in (row[DISCOVERY_COLUMN] or "").split("|") if key)

    # Homebrew formulae and casks
    for kind, name in re.findall(r'^(brew|cask) "([^"]+)"', read_repo_text(BREWFILE), re.M):
        declared.add(f"{kind}:{name}")

    # Receipt-only entries are informational, never required installations.
    declared = {key for key in declared if not key.startswith("receipt:")}

    # Conda environments
    declared.update("conda:" + file.stem for file in (ROOT / "conda").glob("*.yml"))
    return declared


# ------------------------------------------------------------------------------
#  Found software (on this Mac)
# ------------------------------------------------------------------------------


def scan_brew():
    """Read Homebrew receipts.

    Returns (installed, requested): every formula and cask present, and the
    subset installed on request rather than as a dependency.
    """
    installed, requested = set(), set()
    prefixes = {Path("/opt/homebrew"), Path("/usr/local")}
    if os.environ.get("HOMEBREW_PREFIX"):
        prefixes.add(Path(os.environ["HOMEBREW_PREFIX"]))
    for prefix in prefixes:
        for path in (prefix / "Cellar").glob("*/*/INSTALL_RECEIPT.json"):
            receipt = read_json(path)
            if receipt is None:
                continue
            key = "brew:" + brew_name(path.parents[1].name, receipt, "homebrew/core")
            installed.add(key)
            if receipt.get("installed_on_request"):
                requested.add(key)
        for path in (prefix / "Caskroom").glob("*/.metadata/INSTALL_RECEIPT.json"):
            receipt = read_json(path)
            if receipt is None:
                continue
            key = "cask:" + brew_name(path.parents[1].name, receipt, "homebrew/cask")
            installed.add(key)
            requested.add(key)
    return installed, requested


def scan_manual():
    """Find software installed outside Homebrew, as "<kind>:<name>" keys."""
    items = set()

    # Application bundles, up to two folders below the Applications directory
    # (vendors such as Logitech nest theirs). Bundles inside another .app are
    # helpers, not separate installs.
    for root in (Path("/Applications"), HOME / "Applications"):
        for pattern in ("*.app", "*/*.app", "*/*/*.app"):
            items.update(
                "app:" + path.stem
                for path in root.glob(pattern)
                if not any(parent.suffix == ".app" for parent in path.parents)
            )

    # Standalone command-line tools
    for directory in (
        Path("/usr/local/bin"),
        HOME / ".local/bin",
        HOME / "go/bin",
        HOME / ".cargo/bin",
        HOME / ".krew/bin",
        HOME / ".npm-global/bin",
    ):
        for path in directory.glob("*"):
            if path.is_file() and os.access(path, os.X_OK):
                items.add("bin:" + path.name)

    # /opt installs, JDKs, Helm plugins and gh extensions
    for kind, directory in (
        ("opt", Path("/opt")),
        ("jdk", Path("/Library/Java/JavaVirtualMachines")),
        ("jdk", HOME / "Library/Java/JavaVirtualMachines"),
        ("helm", HOME / "Library/helm/plugins"),
        ("gh", HOME / ".local/share/gh/extensions"),
    ):
        items.update(f"{kind}:{path.name}" for path in directory.glob("*") if path.is_dir())

    # Fonts (one entry per family: "HackNerdFont-Bold.ttf" -> "HackNerdFont")
    for path in (HOME / "Library/Fonts").glob("*"):
        if path.suffix.lower() in (".ttf", ".otf", ".ttc"):
            items.add("font:" + path.stem.split("-")[0])

    # Ansible collections
    for path in (HOME / ".ansible/collections/ansible_collections").glob("*/*/MANIFEST.json"):
        info = (read_json(path) or {}).get("collection_info") or {}
        if info.get("namespace") and info.get("name"):
            items.add(f"galaxy:{info['namespace']}.{info['name']}")

    # Command Line Tools and Oh My Zsh
    for key, path in (
        ("clt:CommandLineTools", Path("/Library/Developer/CommandLineTools")),
        ("framework:oh-my-zsh", HOME / ".oh-my-zsh"),
    ):
        if path.is_dir():
            items.add(key)

    # Conda environments
    for root in CONDA_ROOTS:
        items.update("conda:" + path.parents[1].name for path in (root / "envs").glob("*/conda-meta/history"))
    return items


# ------------------------------------------------------------------------------
#  Comparison
# ------------------------------------------------------------------------------


def compare():
    """Print the differences and return the exit status."""
    patterns = load_exclusions()
    expected = load_declared()
    installed, requested = scan_brew()
    observed = scan_manual()

    def included(key):
        return not any(fnmatch.fnmatchcase(key.casefold(), pattern) for pattern in patterns)

    new = sorted(filter(included, (observed | requested) - expected))
    missing = sorted(filter(included, expected - (observed | installed)))
    for item in new:
        print("Unlisted install   " + item)
    for item in missing:
        print("Missing locally    " + item)
    print(f"{len(new)} unlisted, {len(missing)} declared but absent. Read-only comparison.")
    return int(bool(new or missing))


def main():
    """Parse the command line and run the comparison."""
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.parse_args()
    try:
        return compare()
    except InventoryError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
