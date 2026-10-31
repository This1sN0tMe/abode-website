# Quarantined capture — 2026-10-31, second develop attempt (contract v2)

Transcript: `c1-develop-push.v2-quarantined.txt`
Builds: Job1-build #4 (SUCCESS), Job2-test #5 (SUCCESS), Job3-prod untouched (2 → 2)
Contract in force at capture: `capture-develop.checks` @ `4ce1b4bd…` (v2)

## Why this is quarantined

One fault, and it is only in the contract's shape:

- `last :: ^RESULT CAPTURE (PASS|FAIL)` carried two fields. `verify.py` splits on `::` and requires
  exactly three — `expected` is ignored for `last` but the field must still be present — so the grader
  exits with a usage error before evaluating a single predicate.

## What this run nevertheless demonstrated

Everything the contract was written to check came back correct in the console:

- Job1 #4 first line `Started by GitHub push by This1sN0tMe`, `BRANCH=develop`, `PROD_PROMOTED=no`
- Job2 #5 `ASSERT home_status=200`, `asset_status=200`, `asset_bytes=107935`, `body=Hello world! PASS`
- `OBSERVED prod_builds_before=2 prod_builds_after=2` — the develop push did not reach prod
- `RESULT CAPTURE PASS label=develop branch=develop build=4`

That is not evidence and is not counted. A contract the grader cannot parse is not a frozen contract, and
grading this transcript under the corrected file would be the repaired-contract manoeuvre 2.3 was denied.

## Disposition

Contract v3 differs from v2 by exactly one field on one line. The replacement capture recomputes every
number from its own build window; this transcript is kept only as the record of why v3 exists.
