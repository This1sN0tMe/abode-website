# Capstone 1 — requirement → artifact matrix

Committed before any capture. One row per requirement clause; a row with no artifact is a gap, not a
plan. Source: `MandatoryModuleAssignments.md` § "Capstone 1 — End-to-end DevOps lifecycle (Abode
Software)"; product `https://github.com/hshar/website.git`.

## Measured facts about the product (not assumptions)

| Fact | How it was measured |
|---|---|
| One branch only: `master`. No `develop`. | `git branch -a` after cloning `883b439` |
| Two files: `index.html` (193 B) and `images/github3.jpg` (107,935 B) | `git ls-files`, `ls -la` |
| Last commit 2019-02-08 by hshar ("modified") | `git log -1` |
| `index.html` loads `images/github3.jpg` as a body background | `cat index.html` |
| Base image `hshar/webapp` = Ubuntu 18.04, Apache 2.4.29, `CMD apachectl -D FOREGROUND`, `/var/www/html/index.php`, curl present, git **absent** | `docker run --rm --entrypoint sh hshar/webapp -c …` |
| A built image from our Dockerfile serves "Hello world!" and `github3.jpg` (200, 107,935 B) | `docker build` + `curl localhost:8088` + `curl -I /images/github3.jpg` |
| `/var/www/html` is the container's COPY target, **not** the repo layout | the two lines above together |

Consequence: "code resides in /var/www/html" is a destination, and the Dockerfile must copy
`index.html` **and** `images/`.

## Matrix

| # | Requirement (verbatim) | Artifact | Status |
|---|---|---|---|
| 1 | "Install necessary software on the machines using a configuration management tool" | Ansible playbook + inventory from module 5 (`runners/`, `ansible.cfg`), re-pointed at the four workers | pending capture |
| 2 | "Implement a Git workflow" | `master` (prod) + `develop` on the fork at `git@github.com:This1sN0tMe/abode-website.git`; release merge `14db960`; `git ls-remote` inside both captures | **captured** — refs proven, not asserted |
| 3a | "CodeBuild auto-triggers on commit to master or develop · master → test and push to prod" | GitHub push webhook → Jenkins `Job1`; branch condition on the triggered ref decides the prod hop (`PROD_PROMOTED=yes`) | **captured** — `evidence/capstone1/c1-master-push.txt`, verify.py 15/15 |
| 3b | "develop → test only (do not push to prod)" | same `Job1` branch condition; `PROD_PROMOTED=no` printed on `develop`, prod job never invoked | **captured** — `evidence/capstone1/c1-develop-push.txt`, verify.py 15/15 |
| 4 | "Containerize the code with a Dockerfile (built on every GitHub push). Use the pre-built hshar/webapp container; code resides in /var/www/html" | `Dockerfile` (COPY-only), proven locally | **verified locally** — build + serve + asset |
| 5 | "Define the above in a Jenkins Pipeline with jobs: Job1 build, Job2 test, Job3 prod" | three freestyle jobs `Job1-build` / `Job2-test` / `Job3-prod`, chained by parameterised trigger calls so the branch decision travels with the build — the brief names three *jobs*, not three stages | **captured** — both branches, 15/15 each |

## Decision 2026-10-30 — how requirement 3 is implemented

Prior art and primary-document review, 10 published solutions to this exact brief:

- **AWS CodeBuild the service: 0/10.** GitHub webhook into Jenkins: **10/10.**
- The requirement is written in the original handout as two words — "3. Code Build should automatically
  be triggered once commit is made…" — and is CamelCased into the AWS product name only in later
  restatements. Requirement 5 then defines "Job1 : build" inside Jenkins. Read together, clause 3 asks
  for *an automatic build*, and clause 5 says Jenkins owns it. Reading clause 3 as the AWS product makes
  clauses 3 and 5 describe two unrelated CI systems in one deliverable.
- Cost of the literal reading: an AWS CodeConnections (CodeStar) ARN the owner must create in the
  console, a second remote for the fork, and real CodeBuild minutes — none of which any published
  solution needed.

Therefore: requirement 3 is implemented as a GitHub push webhook into Jenkins `Job1`, with the branch
condition taken from the triggered ref. `buildspec.yml` is retained as an archived design, marked
**designed, not executed**, and is excluded from every evidence surface.

**Superseded decision:** the earlier "split of responsibility" (CodeBuild builds and publishes the
image, Jenkins waits on that build) is void. Jenkins owns build, test and prod; no second orchestrator.

## Decisions this design records

- **Three freestyle jobs, not one Jenkinsfile with three stages.** Requirement 5 says "jobs: Job1 build,
  Job2 test, Job3 prod" — three jobs, chained. A single declarative pipeline with three stages is a
  different artifact from the one the brief names. The chain is an authenticated trigger call carrying
  branch, image and image id as parameters, because a downstream job cannot inherit the branch that
  triggered its upstream from its own checkout. (`jenkins/*.Jenkinsfile` is kept as reference material and
  as the Capstone 2 script; it is not the Capstone 1 deliverable.)
- **"test" is an assertion, not a stage name.** Job2 pulls the image, runs it, and greps the served
  bytes for `Hello world!` plus a 200 on `images/github3.jpg`. A green pipeline with no assertion proves
  only that `docker build` exited 0.
- **Prod promotes one digest.** Job3 compares the digest it pulled against the digest Job2 verified and
  fails on a mismatch (`SAME_ARTIFACT`), so retag drift is caught rather than assumed away.
- **COPY only in the Dockerfile.** The base's apt mirrors answer today, but nothing here needs a
  package; an image that installs nothing cannot break when a 2019 mirror retires.
- **Branch conditioning is read from the event, not from the default branch.** A develop push that
  merely *looks* like master because the workspace is on master is the failure this avoids.
- **Cost guard.** No AWS build runs, nothing provisions EC2. Terraform, and with it the durable spend,
  belongs to Capstone 2 and is capped there.
- **Namespace.** Docker Hub user is `this1sn0tme` (read from `~/.docker/config.json`, username only —
  the token is never printed or committed). Image: `this1sn0tme/abode-website`.

## Archived — designed, not executed

These exist in the tree as design records. They are **not** evidence: no transcript, no grader verdict,
no row in any claims table, and they must never appear under `evidence/`.

| Artifact | What it is | Why it is not executed |
|---|---|---|
| `buildspec.yml` | AWS CodeBuild build + Docker Hub push, branch-conditioned `PROMOTED_TO_PROD` | requires a CodeConnections ARN the owner must create; 0/10 prior art; superseded by the webhook reading of clause 3 |
| `jenkins/Capstone1.Jenkinsfile`, `job1..job3.Jenkinsfile` | declarative pipeline version of the three jobs | kept as reference and for Capstone 2; clause 5 asks for three jobs, not stages |

## Deviations to record when the capture lands

1. The product fork lives under `This1sN0tMe`, not `hshar`; upstream is kept as the `upstream` remote
   and `develop` exists only in the fork. Requirement 2 is satisfied in the fork.
2. `hshar/webapp` is a 2019 single-tag image; the Dockerfile inherits it unmodified (COPY only) and
   documents the base's age.
3. Requirement 3 is executed as a GitHub webhook into Jenkins rather than the AWS CodeBuild service —
   see the decision above for the wording and the prior-art counts.

## Pre-flight 2026-10-30 — NOT evidence

A dry run of the three job scripts against the local clone, to prove the chain logic before the fork
exists. No transcript was filed, no grader was run, and nothing here counts toward any status: the graded
artifact must be a push-triggered build against the GitHub remote.

Measured, in the Jenkins console:

| run | Job1 | Job2 | Job3 | observation |
|---|---|---|---|---|
| `BRANCH_OVERRIDE=develop` | PASS | SUCCESS | not invoked | `PROD_PROMOTED=no`, `PROD_SKIPPED=yes` — test only, prod untouched |
| `BRANCH_OVERRIDE=master` | PASS | SUCCESS | SUCCESS | `SAME_ARTIFACT=yes`, prod 200, body `Hello world!` on :80 |

Assertions that actually fired: `home_status=200`, `asset_status=200`, `asset_bytes=107935`,
`body=Hello world! PASS`, and on the prod hop the pulled image id matched the one Job2 tested.

Three things this dry run settled, each paid for:

- **Jobs must reference their scripts by absolute path.** An inline shell step has to be XML-escaped, and a
  bare `2>&1` inside `<command>` is invalid XML — createItem returned 500 with an HTML page while the
  script printed "CREATED". Bodies now live in `runners/job{1,2,3}-*.sh`.
- **A job `authToken` is not enough to trigger a downstream build.** Anonymous holds no Job/Build
  permission, so `/buildWithParameters?token=…` returns 403. The trigger needs basic auth **and** a CSRF
  crumb; plain basic-auth POST is also 403. Production would use an API token bound to a build user.
- **`file://` SCM is refused by the git plugin** ("references a local directory, which may be insecure")
  unless `ALLOW_LOCAL_CHECKOUT` is set. Not worked around on purpose — relaxing a controller security
  flag to serve a temporary dry run would outlive the dry run. The real path is the GitHub remote.
