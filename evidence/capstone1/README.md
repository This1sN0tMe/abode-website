# Capstone 1 — evidence set

Five requirement clauses, three CLI transcripts, one GUI annex. Every transcript is graded by
`runners/verify.py` against a contract committed **before** the capture, and each carries the contract's
sha256 as its first line so the grader proves which contract applied rather than inferring it from mtime.

## CLI transcripts (primary evidence)

| file | proves | verdict |
|---|---|---|
| `c1-provision.txt` | requirement 1 — three machines provisioned by Ansible, each reporting its own os and versions; pass 2 changes nothing | verify.py **19/19** |
| `c1-develop-push.txt` | requirement 3b — a develop push builds and tests, and never reaches prod (prod build count 2 → 2) | verify.py **15/15** |
| `c1-master-push.txt` | requirement 3a — a master push builds, tests, then deploys the same image to prod (`SAME_ARTIFACT=yes`) | verify.py **15/15** |

The push transcripts carry the controller's own log window for that specific push — the `PushEvent`
receipt, the `Poked Job1-build` that follows it, and the `Triggering #N` line — because the github plugin
can report either `Started by GitHub push by …` or `Started by an SCM change` for the same push depending
on which of its two paths wins the race. The log window says the thing the cause string only sometimes
does: GitHub delivered a push for this repository and it reached this job.

## GUI annex (`c1-gui-annex.pdf`, 6 pages)

Rule 1 permits GUI capture only where the work is genuinely graphical. These are the pages where the
claim exists nowhere else, plus one render that is the deliverable's own output.

| page | surface | what it shows |
|---|---|---|
| 1 | `/` dashboard | the three jobs exist and are green |
| 2 | `Job1-build/configure` | GitHub push trigger, SCM url, branch specs master + develop, `bash runners/job1-build.sh` |
| 3 | `Job2-test/configure` | the five build parameters; no trigger of its own |
| 4 | `Job3-prod/configure` | the four build parameters; no trigger of its own |
| 5 | `Job1-build/6/console` | the build the master push caused, opening `Started by GitHub push by This1sN0tMe` |
| 6 | `localhost:80` | the deployed product: `🐴 Intellipaat`, body `Hello world!`, background `images/github3.jpg` |

Page 6 is the only one that could not be replaced by text: it is the product actually served from the
container the pipeline deployed. Pages 2–4 are captured with anonymous read — no credential was used or
needed for any screenshot, and none is stored in this repository.

## Screenshots are additive, not a substitute

The transcripts remain the primary artifact: they carry commands, real output, exit state and provenance
a PDF cannot. The annex exists because a trainer opens a PDF, and because four of these claims
(`defined in a Jenkins Pipeline with jobs`, the dashboard state, the served page) are cheapest to read as
a picture.

## Quarantine (`quarantine/`)

Two earlier develop captures are kept with their causes rather than graded under repaired contracts:
`v1` — a contract the grader could not parse, plus a runner that printed a *foreign* build's console
(a master-branch prod deploy inside a test-only transcript); `v2` — a malformed `last` predicate. Neither
was re-graded. The v2 runner only prints build numbers that did not exist when it started, which removes
that defect structurally.
