#!/usr/bin/env python3
"""CI inventory cannot silently omit registered cases or delete duplicates."""
from sera_ci_inventory import audit
from sera_ci_suite import load_tests
result = audit()
assert result["counts"]["py"] == len(load_tests("py"))
assert result["counts"]["gd"] == len(load_tests("gd"))
assert result["counts"]["py"] >= 131
assert result["counts"]["gd"] >= 44
for group in result["exact_duplicate_content"]:
    assert len(group) > 1
    assert all(any(p in load_tests(kind) for kind in ("py", "gd")) for p in group)
assert all(p.startswith("tools/") for p in result["candidate_unregistered"])
print("SERA_CI_INVENTORY_PASS")
