#!/usr/bin/env python3
"""Verify Peekaboo MVP repository structure and backend/app assets.

This script is intentionally lightweight and dependency-free so it can run in CI,
on a fresh development machine, or during handoff review:

    python3 scripts/verify_project.py

It validates the documented MVP expectations:
- required documentation files
- Flutter Android tablet app files
- E Ink refresh/theme implementation hints
- Supabase migrations, schema tables, storage references, and Edge Functions
- absence of a custom Node.js backend
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REQUIRED_DOCS = [
    "README.md",
    "docs/architecture.md",
    "docs/eink.md",
]

REQUIRED_FLUTTER_PATHS = [
    "pubspec.yaml",
    "lib/main.dart",
    "android",
]

RECOMMENDED_APP_DIRS = [
    "lib/theme",
    "lib/reading",
    "lib/aloud",
    "lib/vocabulary",
    "lib/parent",
    "lib/eink",
    "lib/supabase",
]

EDGE_FUNCTIONS = [
    "whisper-feedback",
    "vocabulary-lookup",
    "parent-summary",
]

REQUIRED_TABLE_GROUPS = {
    "profiles/family boundary": ["profiles", "families"],
    "children": ["children"],
    "books": ["books"],
    "book uploads/assignments": ["book_uploads", "book_assignments"],
    "reading sessions": ["reading_sessions"],
    "reading progress": ["reading_progress"],
    "vocabulary": ["vocabulary_words", "vocabulary_lookups", "difficult_words"],
    "pronunciation attempts": ["pronunciation_attempts", "word_attempts"],
    "parent dashboard": ["parent_dashboard_metrics"],
}

EXPECTED_STORAGE_BUCKET_GROUPS = {
    "EPUB/book files": ["epubs", "ebooks"],
    "read-aloud audio": ["audio-attempts", "audio-snippets"],
    "book/vocabulary image assets": ["book-assets", "word-images"],
}

NODE_BACKEND_MARKERS = [
    "package.json",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    "server.js",
    "server.ts",
    "app.js",
    "express.js",
]

# Some package.json files may be created by tools under generated/build folders.
IGNORED_DIR_PARTS = {
    ".git",
    ".dart_tool",
    "build",
    ".idea",
    ".vscode",
    "node_modules",
}


@dataclass
class Result:
    label: str
    ok: bool
    detail: str = ""
    severity: str = "error"  # error or warning


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""


def iter_files(root: Path) -> Iterable[Path]:
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in IGNORED_DIR_PARTS]
        for filename in filenames:
            yield Path(dirpath) / filename


def check_paths(root: Path, paths: list[str], label: str, severity: str = "error") -> list[Result]:
    results: list[Result] = []
    for item in paths:
        path = root / item
        results.append(
            Result(
                label=f"{label}: {item}",
                ok=path.exists(),
                detail="found" if path.exists() else "missing",
                severity=severity,
            )
        )
    return results


def detect_flutter_root(root: Path) -> Path:
    """Return the Flutter project root.

    The current MVP repository uses a top-level Flutter layout. Some handoffs use
    a nested app/ layout, so support both without weakening the checks.
    """
    if (root / "pubspec.yaml").exists():
        return root
    if (root / "app" / "pubspec.yaml").exists():
        return root / "app"
    return root


def combined_sql(root: Path) -> tuple[str, list[Path]]:
    migrations = sorted((root / "supabase" / "migrations").glob("*.sql"))
    text = "\n".join(read_text(path) for path in migrations)
    return text.lower(), migrations


def table_declared(sql: str, table: str) -> bool:
    escaped = re.escape(table.lower())
    patterns = [
        rf"create\s+table\s+(if\s+not\s+exists\s+)?(?:public\.)?{escaped}\b",
        rf"create\s+table\s+(if\s+not\s+exists\s+)?\"{escaped}\"\b",
    ]
    return any(re.search(pattern, sql, flags=re.IGNORECASE) for pattern in patterns)


def check_supabase(root: Path) -> list[Result]:
    results: list[Result] = []
    supabase_dir = root / "supabase"
    migrations_dir = supabase_dir / "migrations"
    functions_dir = supabase_dir / "functions"

    results.append(Result("Supabase directory", supabase_dir.is_dir(), rel(supabase_dir, root)))
    results.append(Result("Supabase migrations directory", migrations_dir.is_dir(), rel(migrations_dir, root)))

    sql, migrations = combined_sql(root)
    results.append(
        Result(
            "Supabase SQL migrations",
            bool(migrations),
            f"{len(migrations)} .sql file(s) found" if migrations else "no .sql migration files found",
        )
    )

    for label, table_names in REQUIRED_TABLE_GROUPS.items():
        found_tables = [table for table in table_names if table_declared(sql, table)]
        results.append(
            Result(
                f"Schema table group: {label}",
                bool(found_tables),
                "found: " + ", ".join(found_tables) if found_tables else "none found; expected one of: " + ", ".join(table_names),
            )
        )

    rls_mentions = len(re.findall(r"enable\s+row\s+level\s+security", sql, flags=re.IGNORECASE))
    results.append(
        Result(
            "RLS enabled in migrations",
            rls_mentions > 0,
            f"{rls_mentions} ENABLE ROW LEVEL SECURITY statement(s) found" if rls_mentions else "no RLS enable statements found",
        )
    )

    for label, bucket_names in EXPECTED_STORAGE_BUCKET_GROUPS.items():
        found_buckets = [bucket for bucket in bucket_names if bucket.lower() in sql]
        results.append(
            Result(
                f"Storage bucket group: {label}",
                bool(found_buckets),
                "referenced: " + ", ".join(found_buckets) if found_buckets else "none referenced; expected one of: " + ", ".join(bucket_names),
                severity="warning",
            )
        )

    results.append(Result("Supabase functions directory", functions_dir.is_dir(), rel(functions_dir, root)))
    for function_name in EDGE_FUNCTIONS:
        function_dir = functions_dir / function_name
        has_entrypoint = any((function_dir / name).exists() for name in ("index.ts", "index.js", "main.ts"))
        results.append(
            Result(
                f"Edge Function: {function_name}",
                function_dir.is_dir() and has_entrypoint,
                "directory and entrypoint found" if function_dir.is_dir() and has_entrypoint else "missing directory or entrypoint",
            )
        )

    return results


def check_flutter(root: Path) -> list[Result]:
    flutter_root = detect_flutter_root(root)
    results = [Result("Flutter project root", flutter_root.exists(), rel(flutter_root, root))]
    results.extend(check_paths(flutter_root, REQUIRED_FLUTTER_PATHS, "Flutter required path"))
    results.extend(check_paths(flutter_root, RECOMMENDED_APP_DIRS, "Flutter recommended module", severity="warning"))

    pubspec = read_text(flutter_root / "pubspec.yaml").lower()
    for keyword in ["flutter", "supabase", "epub"]:
        results.append(
            Result(
                f"pubspec dependency/config mention: {keyword}",
                keyword in pubspec,
                "found" if keyword in pubspec else "not found",
                severity="warning" if keyword == "epub" else "error",
            )
        )

    app_lib = flutter_root / "lib"
    dart_files = list(app_lib.rglob("*.dart")) if app_lib.exists() else []
    dart_text = "\n".join(read_text(path).lower() for path in dart_files)

    feature_terms = {
        "EPUB reading flow": ["epub", "reader", "reading"],
        "Whisper/read-aloud flow": ["whisper", "read aloud", "read_aloud", "pronunciation", "record"],
        "Vocabulary popup": ["vocabulary", "definition", "word"],
        "Parent dashboard": ["parent", "dashboard"],
        "E Ink refresh abstraction": ["eink", "refreshmode", "refresh controller", "refreshcontroller"],
    }
    for label, terms in feature_terms.items():
        found = any(term in dart_text for term in terms)
        results.append(Result(label, found, "implementation hint found" if found else "no implementation hint found"))

    return results


def check_docs(root: Path) -> list[Result]:
    results = check_paths(root, REQUIRED_DOCS, "Documentation")
    combined_docs = "\n".join(read_text(root / path).lower() for path in REQUIRED_DOCS)
    for topic in [
        "performance",
        "child safety",
        "privacy",
        "e ink",
        "whisper",
        "supabase",
        "node.js",
    ]:
        results.append(
            Result(
                f"Documentation topic: {topic}",
                topic in combined_docs,
                "covered" if topic in combined_docs else "not covered",
            )
        )
    return results


def check_no_node_backend(root: Path) -> list[Result]:
    markers: list[Path] = []
    express_mentions: list[Path] = []

    for path in iter_files(root):
        relative_parts = set(path.relative_to(root).parts)
        if relative_parts & IGNORED_DIR_PARTS:
            continue
        if path.name in NODE_BACKEND_MARKERS:
            markers.append(path)
        if path.suffix in {".js", ".ts", ".mjs", ".cjs"}:
            text = read_text(path).lower()
            if "express(" in text or "from 'express'" in text or 'from "express"' in text or "require('express')" in text or 'require("express")' in text:
                express_mentions.append(path)

    # Supabase Edge Functions may use TypeScript and Deno; TypeScript alone is not a Node backend.
    details: list[str] = []
    if markers:
        details.append("markers: " + ", ".join(rel(path, root) for path in markers[:10]))
    if express_mentions:
        details.append("express usage: " + ", ".join(rel(path, root) for path in express_mentions[:10]))

    return [
        Result(
            "No custom Node.js backend",
            not markers and not express_mentions,
            "; ".join(details) if details else "no Node backend markers found",
        )
    ]


def print_results(results: list[Result]) -> None:
    for result in results:
        if result.ok:
            prefix = "PASS"
        elif result.severity == "warning":
            prefix = "WARN"
        else:
            prefix = "FAIL"
        detail = f" - {result.detail}" if result.detail else ""
        print(f"[{prefix}] {result.label}{detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Peekaboo MVP project assets")
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[1]),
        help="Repository root. Defaults to parent of scripts/.",
    )
    parser.add_argument(
        "--warnings-as-errors",
        action="store_true",
        help="Return non-zero when warning checks fail.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Repository root does not exist: {root}", file=sys.stderr)
        return 2

    results: list[Result] = []
    results.extend(check_docs(root))
    results.extend(check_flutter(root))
    results.extend(check_supabase(root))
    results.extend(check_no_node_backend(root))

    print(f"Peekaboo MVP verification for {root}\n")
    print_results(results)

    errors = [r for r in results if not r.ok and r.severity == "error"]
    warnings = [r for r in results if not r.ok and r.severity == "warning"]

    print("\nSummary:")
    print(f"  Passed:   {sum(1 for r in results if r.ok)}")
    print(f"  Warnings: {len(warnings)}")
    print(f"  Errors:   {len(errors)}")

    if errors or (args.warnings_as_errors and warnings):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
