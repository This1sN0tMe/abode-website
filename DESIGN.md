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
| 2 | "Implement a Git workflow" | `master` (prod) + `develop` + `feature/*` on the fork; git-flow with a release branch; transcript + `git ls-remote` state | branch created locally; push pending the repo |
| 3a | "CodeBuild auto-triggers on commit to master or develop · master → test and push to prod" | `buildspec.yml` branch test on `CODEBUILD_WEBHOOK_HEAD_REF`, `PROMOTED_TO_PROD=yes` path | written; needs the CodeBuild project + webhook |
| 3b | "develop → test only (do not push to prod)" | same buildspec, `PROMOTED_TO_PROD=no` path | written |
| 4 | "Containerize the code with a Dockerfile (built on every GitHub push). Use the pre-built hshar/webapp container; code resides in /var/www/html" | `Dockerfile` (COPY-only), proven locally | **verified locally** — build + serve + asset |
| 5 | "Define the above in a Jenkins Pipeline with jobs: Job1 build, Job2 test, Job3 prod" | `jenkins/Capstone1.Jenkinsfile` + `job1-build` / `job2-test` / `job3-prod` | written; needs Jenkins jobs |

## Decisions this design records

- **Split of responsibility.** CodeBuild builds and publishes the image (a real webhook build on every
  push); Jenkins orchestrates build → test → prod by *waiting on* that build, not by rebuilding. Two
  orchestrators doing the same three jobs is the incoherence this split avoids.
- **"test" is an assertion, not a stage name.** Job2 pulls the image, runs it, and greps the served
  bytes for `Hello world!` plus a 200 on `images/github3.jpg`. A green pipeline with no assertion proves
  only that `docker build` exited 0.
- **Prod promotes one digest.** Job3 compares the digest it pulled against the digest Job2 verified and
  fails on a mismatch (`SAME_ARTIFACT`), so retag drift is caught rather than assumed away.
- **COPY only in the Dockerfile.** The base's apt mirrors answer today, but nothing here needs a
  package; an image that installs nothing cannot break when a 2019 mirror retires.
- **Credential path.** CodeBuild's GitHub source uses an AWS CodeConnections (CodeStar) connection —
  the owner creates it in the console and supplies the ARN. A fine-grained PAT is *not* usable for a
  plain CodeBuild GitHub source (it fails as `CLIENT_ERROR: authentication required for primary
  source`), so the connection, not a token, is the design.
- **Cost guard.** No CodeBuild build runs longer than the buildspec needs (~2 min ≈ well inside the
  100 free minutes/month); the image push costs nothing at this size; nothing here provisions EC2.
  Terraform, and with it the durable spend, belongs to Capstone 2 and is capped there.
- **Namespace.** Docker Hub user is `this1sn0tme` (read from `~/.docker/config.json`, username only —
  the token is never printed or committed). Image: `this1sn0tme/abode-website`.

## Deviations to record when the capture lands

1. The product fork lives under `This1sN0tMe`, not `hshar`; upstream is kept as the `upstream` remote
   and `develop` exists only in the fork. Requirement 2 is satisfied in the fork.
2. `hshar/webapp` is a 2019 single-tag image; the Dockerfile inherits it unmodified (COPY only) and
   documents the base's age.
