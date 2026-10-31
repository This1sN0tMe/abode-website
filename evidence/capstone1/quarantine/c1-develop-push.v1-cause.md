# Quarantined capture — 2026-10-31, first develop attempt

Transcript: `c1-develop-push.v1-quarantined.txt`
Builds it recorded: Job1-build #3 (SUCCESS), Job2-test #4 (SUCCESS)
Contract in force at capture: `capture-develop.checks` @ `ff34ef49…` (v1)

## Why this is quarantined, not graded

Three separate faults, all real:

1. **The contract was unparseable.** `verify.py` requires `mode :: regex :: expected`; v1's `absent` lines
   carried two fields (`absent :: ^TRIGGERED Job3-prod`), so the grader exited with a usage error before
   evaluating anything. A contract the grader cannot read is not a pass.
2. **The cause line did not match the predicate.** Job1 printed `Started by an SCM change`, not
   `Started by GitHub push by …`. The github plugin's push trigger schedules an SCM poll, and on this run
   the poll won the race — same push, different cause string. The webhook was working: the controller log
   shows `Received PushEvent for https://github.com/This1sN0tMe/abode-website` and `Poked Job1-build`.
3. **The transcript contained a prod deploy from a different run.** The runner printed
   `Job3-prod/lastBuild/consoleText` unconditionally, so a develop capture carries the console of
   Job3-prod #2 — a **master** build (`branch=master commit=14db960`) left behind by an earlier push. A
   prod deploy sitting inside test-only evidence is fabricated provenance, however accidental.

## Disposition

Not re-graded under the repaired contract — that is the route 2.3 was denied. The v2 contract and the v2
runner are committed *after* this file, and the replacement capture derives every number from its own build
window: Job2 and Job3 consoles are printed only when their build numbers exceed the values recorded at the
start of that run.
