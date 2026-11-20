# -*- coding: utf-8 -*-
"""Repository self-check for the IOSPS project.

Verifies that the docs/task system is internally consistent so that any new
session can resume work from files alone. Run from anywhere:

    python tools/check_repo.py

Exit code 0 = no errors (warnings allowed), 1 = errors found.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

REQUIRED_FILES = [
    "CLAUDE.md",
    "AGENTS.md",
    "STATUS.md",
    "README.md",
    "docs/README.md",
    "docs/charter.md",
    "docs/decisions/README.md",
    "docs/product/prd.md",
    "docs/product/features.md",
    "docs/architecture/overview.md",
    "docs/architecture/modules.md",
    "docs/workflow/session-protocol.md",
    "docs/workflow/task-system.md",
    "docs/workflow/verification.md",
    "docs/workflow/conventions.md",
    "docs/workflow/executor-prompt.md",
    "tasks/BOARD.md",
    "tasks/_TEMPLATE.md",
    "logs/HANDOFF.md",
]

STATUSES = {"backlog", "ready", "in-progress", "blocked", "review", "done", "dropped"}
CARD_FIELDS = ["id", "title", "milestone", "status", "priority", "modules", "depends", "verify", "updated"]
ADR_STATUSES = {"Proposed", "Accepted", "Superseded", "Rejected"}
TASK_ID = re.compile(r"T-\d{4}")
CARD_NAME = re.compile(r"^(T-\d{4})-[a-z0-9-]+\.md$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


# ---------------------------------------------------------------- required files
def check_required() -> None:
    for f in REQUIRED_FILES:
        if not (ROOT / f).is_file():
            err(f"missing required file: {f}")


# ---------------------------------------------------------------- task cards
def parse_front_matter(text: str) -> dict[str, str] | None:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    data: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            return data
        if ":" in line:
            k, v = line.split(":", 1)
            data[k.strip()] = v.strip()
    return None


def load_cards() -> dict[str, dict[str, str]]:
    cards: dict[str, dict[str, str]] = {}
    for p in sorted((ROOT / "tasks").glob("T-*.md")):
        m = CARD_NAME.match(p.name)
        if not m:
            err(f"{rel(p)}: file name must look like T-MMNN-lower-kebab-title.md")
            continue
        fm = parse_front_matter(read(p))
        if fm is None:
            err(f"{rel(p)}: missing or unterminated front matter")
            continue
        for field in CARD_FIELDS:
            if not fm.get(field):
                err(f"{rel(p)}: front matter field '{field}' is missing or empty")
        if fm.get("id") and fm["id"] != m.group(1):
            err(f"{rel(p)}: id '{fm['id']}' does not match file name")
        st = fm.get("status", "")
        if st and st not in STATUSES:
            err(f"{rel(p)}: invalid status '{st}'")
        if st == "backlog":
            warn(f"{rel(p)}: backlog tasks normally have no card; use 'ready' once detailed")
        ms = fm.get("milestone", "")
        if ms and not re.fullmatch(r"M[0-8]", ms):
            err(f"{rel(p)}: invalid milestone '{ms}'")
        elif ms and fm.get("id") and fm["id"][2:4] != f"0{ms[1]}":
            warn(f"{rel(p)}: id prefix differs from milestone {ms} (allowed if the task was moved)")
        if fm.get("updated") and not DATE.match(fm["updated"]):
            err(f"{rel(p)}: 'updated' must be YYYY-MM-DD")
        fm["_path"] = rel(p)
        cards[m.group(1)] = fm
    return cards


# ---------------------------------------------------------------- board
def load_board() -> dict[str, dict[str, str]]:
    board: dict[str, dict[str, str]] = {}
    path = ROOT / "tasks" / "BOARD.md"
    if not path.is_file():
        return board
    for n, line in enumerate(read(path).splitlines(), 1):
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6:
            continue
        m = TASK_ID.search(cells[0])
        if not m:
            continue
        tid = m.group(0)
        if tid in board:
            err(f"tasks/BOARD.md:{n}: duplicate task id {tid}")
        link = re.search(r"\]\(([^)]+)\)", cells[0])
        board[tid] = {"status": cells[2], "depends": cells[5], "link": link.group(1) if link else "", "line": str(n)}
        if cells[2] not in STATUSES:
            err(f"tasks/BOARD.md:{n}: invalid status '{cells[2]}' for {tid}")
    return board


def check_tasks(cards: dict, board: dict) -> None:
    for tid, card in cards.items():
        if tid not in board:
            err(f"{card['_path']}: task {tid} is not listed in tasks/BOARD.md")
            continue
        b = board[tid]
        if b["status"] != card.get("status"):
            err(f"status mismatch for {tid}: BOARD='{b['status']}' card='{card.get('status')}'")
        expected = Path(card["_path"]).name
        if b["link"] != expected:
            err(f"tasks/BOARD.md:{b['line']}: {tid} should link to {expected}")
    for tid, b in board.items():
        if b["status"] != "backlog" and tid not in cards:
            err(f"tasks/BOARD.md:{b['line']}: {tid} is '{b['status']}' but has no task card")
    in_progress = sorted({t for t, b in board.items() if b["status"] == "in-progress"}
                         | {t for t, c in cards.items() if c.get("status") == "in-progress"})
    if len(in_progress) > 1:
        err(f"WIP limit violated: more than one in-progress task: {', '.join(in_progress)}")
    # dependencies
    for tid, card in cards.items():
        deps = TASK_ID.findall(card.get("depends", ""))
        for d in deps:
            if d not in board:
                err(f"{card['_path']}: depends on unknown task {d}")
        if card.get("status") in {"in-progress", "review", "done"}:
            open_deps = [d for d in deps if d in board and board[d]["status"] not in {"done", "dropped"}]
            if open_deps and card.get("status") == "done":
                err(f"{card['_path']}: marked done but dependencies are not done: {', '.join(open_deps)}")
            elif open_deps:
                warn(f"{card['_path']}: is {card['status']} while dependencies are open: {', '.join(open_deps)}")
    for tid, b in board.items():
        for d in TASK_ID.findall(b["depends"]):
            if d not in board:
                err(f"tasks/BOARD.md:{b['line']}: {tid} depends on unknown task {d}")


def check_status_file(cards: dict) -> None:
    path = ROOT / "STATUS.md"
    if not path.is_file():
        return
    text = read(path)
    m = re.search(r"\*\*当前任务\*\*[:：](.*)", text)
    if not m:
        err("STATUS.md: missing '**当前任务**：' line")
        return
    ids = TASK_ID.findall(m.group(1))
    if not ids:
        warn("STATUS.md: current task line has no task id")
        return
    tid = ids[0]
    if tid not in cards:
        err(f"STATUS.md: current task {tid} has no task card")
    elif cards[tid].get("status") not in {"ready", "in-progress", "blocked", "review"}:
        warn(f"STATUS.md: current task {tid} has status '{cards[tid].get('status')}'")
    if not re.search(r"\*\*最后更新\*\*[:：]\s*\d{4}-\d{2}-\d{2}", text):
        err("STATUS.md: missing '**最后更新**：YYYY-MM-DD' line")


# ---------------------------------------------------------------- ADRs
def check_adrs() -> None:
    ddir = ROOT / "docs" / "decisions"
    index_path = ddir / "README.md"
    if not index_path.is_file():
        return
    index: dict[str, str] = {}
    for line in read(index_path).splitlines():
        m = re.match(r"\|\s*\[(ADR-\d{4})\]\(([^)]+)\)\s*\|[^|]*\|\s*([A-Za-z]+)", line)
        if m:
            index[m.group(1)] = m.group(3)
            if not (ddir / m.group(2)).is_file():
                err(f"docs/decisions/README.md: {m.group(1)} links to missing file {m.group(2)}")
    for p in sorted(ddir.glob("ADR-*.md")):
        aid = p.name[:8]
        m = re.search(r"状态[:：]\s*\**\s*([A-Za-z]+)", read(p))
        if not m:
            err(f"{rel(p)}: missing '状态：' line")
            continue
        status = m.group(1)
        if status not in ADR_STATUSES:
            err(f"{rel(p)}: invalid ADR status '{status}'")
        if aid not in index:
            err(f"{rel(p)}: not listed in docs/decisions/README.md")
        elif index[aid] != status:
            err(f"ADR status mismatch for {aid}: index='{index[aid]}' file='{status}'")


# ---------------------------------------------------------------- Swift imports
L1_IMPORTS = {
    "BirthdayCore": set(),
    "GiftKit": {"BirthdayCore"},
    "TemplateKit": {"BirthdayCore"},
    "TimelineKit": {"BirthdayCore"},
}
SWIFT_IMPORT = re.compile(
    r"^\s*(?:@\w+(?:\([^\n)]*\))?\s+)*"
    r"(?:(?:private|fileprivate|internal|package|public)\s+)?"
    r"import\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(\w+)",
    re.MULTILINE,
)


def check_l1_imports() -> None:
    for module, dependencies in L1_IMPORTS.items():
        allowed = {"Swift", "Foundation"} | dependencies
        for path in sorted((ROOT / "app" / "Sources" / module).rglob("*.swift")):
            source = read(path)
            for match in SWIFT_IMPORT.finditer(source):
                imported = match.group(1)
                if imported not in allowed:
                    line = source.count("\n", 0, match.start(1)) + 1
                    err(f"{rel(path)}:{line}: {module} cannot import {imported}")


# ---------------------------------------------------------------- links
LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")


def check_links() -> None:
    for p in sorted(ROOT.rglob("*.md")):
        parts = set(p.relative_to(ROOT).parts)
        if parts & {".git", "node_modules", "artifacts", "private", ".build"}:
            continue
        in_fence = False
        for n, line in enumerate(read(p).splitlines(), 1):
            if line.strip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            line = re.sub(r"`[^`]*`", "", line)
            for target in LINK.findall(line):
                if re.match(r"^(https?:|mailto:|#)", target):
                    continue
                path_part = target.split("#", 1)[0]
                if not path_part:
                    continue
                if not (p.parent / path_part).exists():
                    err(f"{rel(p)}:{n}: broken link -> {target}")


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    check_required()
    cards = load_cards()
    board = load_board()
    check_tasks(cards, board)
    check_status_file(cards)
    check_adrs()
    check_links()
    check_l1_imports()

    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    counts = {s: sum(1 for b in board.values() if b["status"] == s) for s in sorted(STATUSES)}
    summary = ", ".join(f"{k}={v}" for k, v in counts.items() if v)
    print(f"\ncards={len(cards)} board={len(board)} ({summary})")
    print(f"result: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
