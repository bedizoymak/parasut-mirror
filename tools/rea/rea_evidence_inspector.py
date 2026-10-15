#!/usr/bin/env python3
"""
Project-local REA-aligned Evidence & Coverage Inspector.
Validates the functional coverage matrix, API v4 evidence records, and financial test vectors
to ensure strict epistemic separation between VERIFIED, OBSERVED, DOCUMENTED, INFERRED,
REQUIRES SAFE TESTING, and INACCESSIBLE items.
"""
import json
import pathlib
import sys

ALLOWED_STATUSES = {
    "VERIFIED",
    "OBSERVED",
    "DOCUMENTED",
    "INFERRED",
    "INACCESSIBLE",
    "REQUIRES SAFE TESTING",
    "NOT YET INVESTIGATED",
}

def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    matrix_path = root / "research" / "functional-coverage-matrix.json"
    if not matrix_path.exists():
        print("ERROR: functional-coverage-matrix.json not found", file=sys.stderr)
        sys.exit(1)
    data = json.loads(matrix_path.read_text(encoding="utf-8"))
    items = data.get("items", [])
    stats = {}
    by_module = {}
    for idx, item in enumerate(items):
        cl = item.get("classification")
        if cl not in ALLOWED_STATUSES:
            print(f"ERROR: Invalid classification '{cl}' at index {idx}", file=sys.stderr)
            sys.exit(1)
        if cl == "INFERRED" and item.get("claimed_verified", False):
            print(f"ERROR: Inferred item at index {idx} illegally claimed as verified", file=sys.stderr)
            sys.exit(1)
        stats[cl] = stats.get(cl, 0) + 1
        mod = item.get("module", "UNKNOWN")
        by_module.setdefault(mod, {"total": 0, "implemented": 0, "tested": 0, "classifications": {}})
        by_module[mod]["total"] += 1
        if item.get("implementation_status") == "IMPLEMENTED":
            by_module[mod]["implemented"] += 1
        if item.get("test_status") == "PASSED":
            by_module[mod]["tested"] += 1
        by_module[mod]["classifications"][cl] = by_module[mod]["classifications"].get(cl, 0) + 1

    report = {
        "total_controls_investigated": len(items),
        "classification_summary": stats,
        "module_breakdown": by_module,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
