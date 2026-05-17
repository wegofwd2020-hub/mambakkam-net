#!/usr/bin/env python3
"""scripts/docs_index/check_drift.py — DOCS_INDEX.md drift detector.

Walks the three sibling repos (mambakkam-net, studybuddy-docs,
StudyBuddy_OnDemand), discovers all `*.md` files, and diffs the result
against the paths referenced in `mambakkam-net/DOCS_INDEX.md`.

Emits two artefacts:
  - `DRIFT_REPORT.md` in the mambakkam-net repo root (human-readable diff;
    gitignored by default, operator may commit if they want history)
  - Stderr summary

Exit codes:
  0 — index in sync with filesystem
  1 — drift detected (new untracked files OR stale references)
  2 — fatal error (missing sibling repo, malformed index)

Intended to run nightly via local cron — see README.md in this directory.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from fnmatch import fnmatch
from pathlib import Path

# ── Repo layout ──────────────────────────────────────────────────────────────
# This script lives in mambakkam-net/scripts/docs_index/. Resolve siblings
# from there. If the layout ever changes, edit REPOS below.
SCRIPT_DIR = Path(__file__).resolve().parent
MAMBAKKAM = SCRIPT_DIR.parents[1]  # mambakkam-net/
WORKSPACE = MAMBAKKAM.parent  # STEM_studybuddy/

REPOS: dict[str, Path] = {
    "mambakkam-net": MAMBAKKAM,
    "studybuddy-docs": WORKSPACE / "studybuddy-docs",
    "StudyBuddy_OnDemand": WORKSPACE / "StudyBuddy_OnDemand",
}

INDEX_FILE = MAMBAKKAM / "DOCS_INDEX.md"
DRIFT_REPORT = MAMBAKKAM / "DRIFT_REPORT.md"

# Exclude patterns — matches anywhere in the relative path within a repo.
# Keep in lock-step with the "What is NOT indexed" section of DOCS_INDEX.md.
EXCLUDE_GLOBS = [
    "node_modules/*",
    "*/node_modules/*",
    ".venv-decks/*",
    "*/.venv-decks/*",
    "venv/*",
    "*/venv/*",
    ".pytest_cache/*",
    "*/.pytest_cache/*",
    ".claude/worktrees/*",
    "*/.claude/worktrees/*",
    ".claude/commands/*",
    "*/.claude/commands/*",
    "sample_content/*",
    "*/sample_content/*",
    "test-results/*",
    "*/test-results/*",
    "web/docs/PHASE_W*",
    "src/data/*",
    "src/pages/*",
    "vendor/*",
    "LICENSE.md",
    "TRASH-FILES.md",
    "ux_test_data/*",
    "web/tests/*",
    "backend/tests/*",
    "backend/.pytest_cache/*",
]

# Link pattern: matches `(path)` or `(path#anchor)` after a `]`.
# Captures the path portion only.
LINK_RE = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")


@dataclass
class DriftResult:
    """Aggregated drift findings across all three repos."""

    on_disk: dict[str, set[str]] = field(default_factory=dict)  # repo -> {rel_paths}
    in_index: set[str] = field(default_factory=set)  # all index-referenced workspace-relative paths
    untracked: list[tuple[str, str]] = field(default_factory=list)  # [(repo, rel_path), ...]
    stale: list[str] = field(default_factory=list)  # workspace-relative paths in index but missing on disk

    @property
    def total_on_disk(self) -> int:
        return sum(len(v) for v in self.on_disk.values())

    @property
    def has_drift(self) -> bool:
        return bool(self.untracked or self.stale)


def is_excluded(rel_path: str) -> bool:
    """Check rel_path (within a repo) against EXCLUDE_GLOBS."""
    return any(fnmatch(rel_path, pat) for pat in EXCLUDE_GLOBS)


def walk_repo(repo_root: Path) -> set[str]:
    """Return repo-relative paths of all `*.md` files not matching excludes."""
    if not repo_root.exists():
        raise FileNotFoundError(f"Sibling repo not found: {repo_root}")

    found: set[str] = set()
    for md in repo_root.rglob("*.md"):
        if not md.is_file():
            continue
        rel = md.relative_to(repo_root).as_posix()
        if is_excluded(rel):
            continue
        found.add(rel)
    return found


def parse_index_paths(index_path: Path) -> set[str]:
    """Extract all workspace-relative paths from markdown links in the index.

    Index uses relative paths like `Plans/RUNBOOK.md` (= mambakkam-net rel)
    or `../studybuddy-docs/docs/...md`. Normalise both forms into a single
    workspace-relative form: `<repo-name>/<rel-path>`.
    """
    if not index_path.exists():
        raise FileNotFoundError(f"Index not found: {index_path}")

    text = index_path.read_text(encoding="utf-8")
    paths: set[str] = set()

    for match in LINK_RE.finditer(text):
        link = match.group(1)
        # Skip external URLs and anchor-only links
        if link.startswith(("http://", "https://", "mailto:", "#")):
            continue
        # Skip non-markdown targets (images, etc.)
        if not link.endswith(".md"):
            continue

        # Normalise to workspace-relative form. The index lives at
        # mambakkam-net/DOCS_INDEX.md so relative paths resolve from there.
        # - `Plans/RUNBOOK.md` -> `mambakkam-net/Plans/RUNBOOK.md`
        # - `../studybuddy-docs/...` -> `studybuddy-docs/...`
        # - `../StudyBuddy_OnDemand/...` -> `StudyBuddy_OnDemand/...`
        normalised = _normalise_to_workspace(link)
        if normalised:
            paths.add(normalised)

    return paths


def _normalise_to_workspace(link: str) -> str | None:
    """Convert an index link into `<repo>/<rel>` form, or None if outside scope."""
    if link.startswith("../"):
        # Strip leading `../` and require the next segment to be a known repo
        parts = link[3:].split("/", 1)
        if len(parts) == 2 and parts[0] in REPOS:
            return f"{parts[0]}/{parts[1]}"
        return None
    # No `../` prefix — link is relative to mambakkam-net itself
    return f"mambakkam-net/{link}"


def diff(result: DriftResult) -> None:
    """Populate untracked + stale lists on result."""
    on_disk_workspace = {
        f"{repo}/{rel}" for repo, paths in result.on_disk.items() for rel in paths
    }

    untracked_paths = on_disk_workspace - result.in_index
    # Skip the index itself + the drift report (self-reference would loop)
    untracked_paths -= {"mambakkam-net/DOCS_INDEX.md", "mambakkam-net/DRIFT_REPORT.md"}

    for ws_path in sorted(untracked_paths):
        repo, rel = ws_path.split("/", 1)
        result.untracked.append((repo, rel))

    stale_paths = result.in_index - on_disk_workspace
    result.stale = sorted(stale_paths)


def render_report(result: DriftResult) -> str:
    """Render DRIFT_REPORT.md content."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines: list[str] = [
        "# DOCS_INDEX.md Drift Report",
        "",
        f"**Generated:** {now}",
        f"**Generator:** `scripts/docs_index/check_drift.py`",
        "",
    ]

    if not result.has_drift:
        lines += [
            "## ✓ No drift detected",
            "",
            f"All {len(result.in_index)} index entries match existing files; "
            f"all {result.total_on_disk} discoverable docs are indexed.",
            "",
        ]
    else:
        lines.append("## Summary")
        lines.append("")
        lines.append(f"- **Untracked in index:** {len(result.untracked)} file(s) exist on disk but aren't referenced from DOCS_INDEX.md")
        lines.append(f"- **Stale references:** {len(result.stale)} entries in DOCS_INDEX.md point to files that don't exist")
        lines.append("")

        if result.untracked:
            lines += [
                "## Untracked files",
                "",
                "Add these to the appropriate topic table in `DOCS_INDEX.md`, or",
                "add their patterns to `EXCLUDE_GLOBS` in",
                "`scripts/docs_index/check_drift.py` if they shouldn't be indexed.",
                "",
            ]
            current_repo = None
            for repo, rel in result.untracked:
                if repo != current_repo:
                    lines.append(f"### {repo}/")
                    lines.append("")
                    current_repo = repo
                lines.append(f"- `{rel}`")
            lines.append("")

        if result.stale:
            lines += [
                "## Stale references",
                "",
                "These paths appear in `DOCS_INDEX.md` but don't exist on disk.",
                "Either restore the file, remove the index entry, or update the path.",
                "",
            ]
            for path in result.stale:
                lines.append(f"- `{path}`")
            lines.append("")

    lines += [
        "## Repo inventory",
        "",
        "| Repo | `.md` files discovered (post-exclude) |",
        "|---|---|",
    ]
    for repo, files in result.on_disk.items():
        lines.append(f"| `{repo}` | {len(files)} |")
    lines.append(f"| **Total on disk** | **{result.total_on_disk}** |")
    lines.append(f"| **Indexed in DOCS_INDEX.md** | **{len(result.in_index)}** |")
    lines.append("")

    return "\n".join(lines)


def main() -> int:
    result = DriftResult()

    try:
        for repo_name, repo_root in REPOS.items():
            result.on_disk[repo_name] = walk_repo(repo_root)
        result.in_index = parse_index_paths(INDEX_FILE)
    except FileNotFoundError as e:
        print(f"FATAL: {e}", file=sys.stderr)
        return 2

    diff(result)
    report = render_report(result)
    DRIFT_REPORT.write_text(report, encoding="utf-8")

    # Stderr summary for cron logs
    print(f"[docs_index] {result.total_on_disk} docs on disk, {len(result.in_index)} in index", file=sys.stderr)
    if result.has_drift:
        print(f"[docs_index] DRIFT: {len(result.untracked)} untracked, {len(result.stale)} stale", file=sys.stderr)
        print(f"[docs_index] Report written to {DRIFT_REPORT.relative_to(MAMBAKKAM)}", file=sys.stderr)
        return 1
    print(f"[docs_index] No drift", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
