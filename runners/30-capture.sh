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
# commits, pushes, then waits for the builds that push caused, and prints only THOSE builds' consoles.
#
# Two rules this run learned the hard way (v1 violated both):
#   1. Never print a job's `lastBuild` console. v1 printed Job3-prod's console during a *develop* capture
#      because an earlier master push had left a prod build behind — a transcript that puts a prod deploy
#      inside a test-only run is fabricated evidence, however accidental. Every console printed here is
#      a build number that did not exist before this run.
#   2. The cause line is not the only proof. "Started by GitHub push by <user>" appears when the github
#      plugin's trigger wins the race; when the poll it schedules wins instead, the cause reads
#      "Started by an SCM change" for the same push. So the transcript also carries the controller's own
#      log lines from this run's window — the PushEvent receipt and the "Poked <job>" that follow it —
#      which is a stronger statement than any cause string: GitHub delivered a push for THIS repo and it
#      reached THIS job.
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
JLOG=$JROOT/jenkins.log
PW=$(tr -d '\n' < "$JROOT/.admin_pw")
WAIT=${WAIT:-240}

# The provenance line must be the first thing in the transcript.
echo "CHECKS sha256=$(shasum -a 256 "$CHECKS" | cut -d' ' -f1)"

cd "$CAP" || exit 1
echo "STATE branch=$(git branch --show-current) head=$(git rev-parse --short HEAD)"
echo "STATE remote=$(git remote get-url origin)"

# Everything this run must move forward: one build number per job, plus the log offset.
num() { curl -s -u "admin:$PW" "$JENKINS/job/$1/api/json?tree=$2" \
        | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('$2') or 0)"; }
J1_NEXT=$(num Job1-build nextBuildNumber)
J2_LAST=$(curl -s -u "admin:$PW" "$JENKINS/job/Job2-test/api/json?tree=lastBuild%5Bnumber%5D" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin).get("lastBuild");print(d["number"] if d else 0)')
J3_LAST=$(curl -s -u "admin:$PW" "$JENKINS/job/Job3-prod/api/json?tree=lastBuild%5Bnumber%5D" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin).get("lastBuild");print(d["number"] if d else 0)')
LOG_OFFSET=$(wc -l < "$JLOG" | tr -d ' ')
echo "STATE job1_next=$J1_NEXT job2_last=$J2_LAST job3_last=$J3_LAST log_offset=$LOG_OFFSET"

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

# --- the controller's own record of that push --------------------------------------------------------
sleep 3
echo "===== controller log for this run's window ====="
tail -n "+$((LOG_OFFSET + 1))" "$JLOG" | grep -E 'PushEvent|Poked|SCM changes detected' | sed 's/^/LOG /'

# --- wait for Job1's build ---------------------------------------------------------------------------
echo "WAIT for Job1-build to pass build $J1_NEXT"
N="$J1_NEXT"
for _ in $(seq 1 "$WAIT"); do
  N=$(num Job1-build nextBuildNumber)
  [ "${N:-0}" -gt "$J1_NEXT" ] 2>/dev/null && break
  sleep 1
done
if [ "${N:-0}" -le "$J1_NEXT" ]; then
  echo "ERROR no build started within ${WAIT}s — the webhook did not reach this controller"
  echo "RESULT CAPTURE FAIL label=$LABEL reason=no_trigger"
  exit 1
fi
BUILD=$((N - 1))
echo "BUILD job=Job1-build number=$BUILD"

wait_done() { # $1 job, $2 build number
  for _ in $(seq 1 "$WAIT"); do
    curl -s -u "admin:$PW" "$JENKINS/job/$1/$2/api/json?tree=building" | grep -q '"building":false' && return 0
    sleep 2
  done
  return 1
}
result_of() { curl -s -u "admin:$PW" "$JENKINS/job/$1/$2/api/json?tree=result" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin).get("result"))'; }

wait_done Job1-build "$BUILD"
echo "RESULT_BUILD job=Job1-build number=$BUILD result=$(result_of Job1-build "$BUILD")"
echo "===== Job1-build console ====="
curl -s -u "admin:$PW" "$JENKINS/job/Job1-build/$BUILD/consoleText"

# --- Job2: must be a NEW build -----------------------------------------------------------------------
echo "WAIT for Job2-test to exceed build $J2_LAST"
N2="$J2_LAST"
for _ in $(seq 1 "$WAIT"); do
  N2=$(curl -s -u "admin:$PW" "$JENKINS/job/Job2-test/api/json?tree=lastBuild%5Bnumber%5D" \
       | python3 -c 'import json,sys;d=json.load(sys.stdin).get("lastBuild");print(d["number"] if d else 0)')
  [ "${N2:-0}" -gt "$J2_LAST" ] 2>/dev/null && break
  sleep 2
done
if [ "${N2:-0}" -le "$J2_LAST" ]; then
  echo "ERROR Job2-test did not start — Job1 did not hand off"
  echo "RESULT CAPTURE FAIL label=$LABEL reason=no_job2"
  exit 1
fi
wait_done Job2-test "$N2"
echo "RESULT_BUILD job=Job2-test number=$N2 result=$(result_of Job2-test "$N2")"
echo "===== Job2-test console ====="
curl -s -u "admin:$PW" "$JENKINS/job/Job2-test/$N2/consoleText"

# --- Job3: only when this branch is supposed to reach prod --------------------------------------------
if [ "$EXPECT_PROD" = "yes" ]; then
  echo "WAIT for Job3-prod to exceed build $J3_LAST"
  N3="$J3_LAST"
  for _ in $(seq 1 "$WAIT"); do
    N3=$(curl -s -u "admin:$PW" "$JENKINS/job/Job3-prod/api/json?tree=lastBuild%5Bnumber%5D" \
         | python3 -c 'import json,sys;d=json.load(sys.stdin).get("lastBuild");print(d["number"] if d else 0)')
    [ "${N3:-0}" -gt "$J3_LAST" ] 2>/dev/null && break
    sleep 2
  done
  if [ "${N3:-0}" -le "$J3_LAST" ]; then
    echo "ERROR Job3-prod did not start on a master push"
    echo "RESULT CAPTURE FAIL label=$LABEL reason=no_job3"
    exit 1
  fi
  wait_done Job3-prod "$N3"
  echo "RESULT_BUILD job=Job3-prod number=$N3 result=$(result_of Job3-prod "$N3")"
  echo "===== Job3-prod console ====="
  curl -s -u "admin:$PW" "$JENKINS/job/Job3-prod/$N3/consoleText"
else
  echo "OBSERVED prod_builds_before=$J3_LAST prod_builds_after=$(curl -s -u "admin:$PW" \
    "$JENKINS/job/Job3-prod/api/json?tree=lastBuild%5Bnumber%5D" \
    | python3 -c 'import json,sys;d=json.load(sys.stdin).get("lastBuild");print(d["number"] if d else 0)') — develop must not reach prod"
fi

echo "HTTP_PROD=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:80/)"
echo "RESULT CAPTURE PASS label=$LABEL branch=$BRANCH build=$BUILD"
