#!/usr/bin/env bash
# 30-capture.sh — capture one push-triggered Capstone 1 run as evidence.
#
#   bash runners/30-capture.sh develop
#   bash runners/30-capture.sh master
#
# Run it UNDER `bash -v` through the lab capture wrapper so the source lines land in the transcript:
#   runners/capture.sh evidence/capstone1/c1-develop-push.txt bash -v runners/30-capture.sh develop
#
# What makes this evidence and not a demo: the build is started by GitHub, not by this script. The script
# commits, pushes, then waits for the build GitHub's webhook caused, and prints that build's console. The
# console's first line — "Started by GitHub push by <user>" — is the proof of requirement 3, and nothing
# this script prints can manufacture it.
#
# The contract is frozen in runners/checks/capture-<label>.checks and must be COMMITTED before this runs;
# its sha256 is printed as the transcript's first line so the grader can prove which contract applied.
set -u

LABEL="${1:-}"
case "$LABEL" in
  develop) BRANCH=develop; EXPECT_PROD=no ;;
  master)  BRANCH=master;  EXPECT_PROD=yes ;;
  *) echo "usage: 30-capture.sh develop|master" >&2; exit 2 ;;
esac

CAP=$(cd "$(dirname "$0")/.." && pwd)
CHECKS="$CAP/runners/checks/capture-$LABEL.checks"
JENKINS=${JENKINS:-http://localhost:8080}
JROOT=${JROOT:-$HOME/dev/labs/devops/jenkins}
PW=$(tr -d '\n' < "$JROOT/.admin_pw")
WAIT=${WAIT:-240}

# The provenance line must be the first thing in the transcript.
echo "CHECKS sha256=$(shasum -a 256 "$CHECKS" | cut -d' ' -f1)"

cd "$CAP" || exit 1
echo "STATE branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"
echo "STATE remote=$(git remote get-url origin)"

# The build number this push must exceed. A push that starts no new build is the failure this measures.
BEFORE=$(curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/api/json?tree=nextBuildNumber" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["nextBuildNumber"])')
echo "STATE next_build_before=$BEFORE"

# --- the change the push carries -------------------------------------------------------------------
git checkout "$BRANCH" 2>&1 | tail -1
if [ "$BRANCH" = "develop" ]; then
  printf 'capture %s %s\n' "$LABEL" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> VERSION.txt
  git add VERSION.txt
  git commit -q -m "build: mark a develop push for the Capstone 1 capture ($(date -u +%Y-%m-%dT%H:%MZ))"
else
  git merge --no-ff develop -m "release: merge develop into master for the Capstone 1 capture"
fi

echo "STATE head_after_commit=$(git rev-parse HEAD)"
git push origin "$BRANCH" 2>&1

# --- wait for the build GitHub started ---------------------------------------------------------------
echo "WAIT for Job1-build to pass build $BEFORE"
N=""
for _ in $(seq 1 "$WAIT"); do
  N=$(curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/api/json?tree=nextBuildNumber" \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["nextBuildNumber"])')
  [ "$N" -gt "$BEFORE" ] 2>/dev/null && break
  sleep 1
done
if [ -z "$N" ] || [ "${N:-0}" -le "$BEFORE" ]; then
  echo "ERROR no build started within ${WAIT}s — the webhook did not reach this controller"
  echo "RESULT CAPTURE FAIL label=$LABEL reason=no_trigger"
  exit 1
fi
BUILD=$((N - 1))
echo "BUILD job=Job1-build number=$BUILD"

for _ in $(seq 1 "$WAIT"); do
  B=$(curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/$BUILD/api/json?tree=building,result")
  echo "$B" | grep -q '"building":false' && break
  sleep 2
done
echo "RESULT_BUILD $(curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/$BUILD/api/json?tree=number,result" | tr -d '\n')"

echo "===== Job1-build console ====="
curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/$BUILD/consoleText"

# Job2 and Job3 are triggered by Job1, so give them their own wait and print each console verbatim.
for J in Job2-test Job3-prod; do
  echo "WAIT for $J"
  for _ in $(seq 1 "$WAIT"); do
    R=$(curl -s -u "admin:$PW" "$JENKINS/job/$J/lastBuild/api/json?tree=number,building,result")
    echo "$R" | grep -q '"building":false' && break
    sleep 2
  done
  echo "===== $J console ====="
  curl -s -u "admin:$PW" "$JENKINS/job/$J/lastBuild/consoleText"
done

# --- what the branches were supposed to do -----------------------------------------------------------
PROD=$(curl -s -u "admin:$PW" "$JENKINS/job/Job3-prod/lastBuild/api/json?tree=number" | head -c 60)
if [ "$EXPECT_PROD" = "yes" ]; then
  echo "$PROD" | grep -q '"number"' && echo "OBSERVED Prod build present" || echo "OBSERVED Prod build absent"
else
  echo "OBSERVED prod was not expected on this branch"
fi

echo "HTTP_PROD=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/)"
echo "RESULT CAPTURE PASS label=$LABEL branch=$BRANCH build=$BUILD"
