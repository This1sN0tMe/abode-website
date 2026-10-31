#!/usr/bin/env bash
# Job1 build — the build stage of Capstone 1.
#
# Runs inside the Jenkins workspace (the job checks the product repo out). Decides PROD_PROMOTED from the
# pushed ref and hands off to Job2 with the parameters Job2 needs, so the branch decision travels with the
# build instead of being re-derived downstream from whatever branch a checkout happened to land on.
#
# BRANCH_OVERRIDE exists for a manual pre-flight run before the fork has a webhook; when it is empty the
# branch comes from GIT_BRANCH, which is what a real push produces. The log says which source was used.
set -eu

JENKINS=${JENKINS:-http://localhost:8080}
JROOT=${JROOT:-$HOME/dev/labs/devops/jenkins}
PW=$(tr -d '\n' < "$JROOT/.admin_pw")

# Trigger the next job with basic auth plus a CSRF crumb. A job authToken alone is not enough here:
# anonymous has no Job/Build permission, and a plain basic-auth POST is rejected 403 without a crumb.
# Production would use a Jenkins API token bound to a build user; the lab reads the 0600 password file.
crumb_post() { # $1 full URL
  local jar http
  jar=$(mktemp)
  local c
  c=$(curl -s -c "$jar" -u "admin:$PW" "$JENKINS/crumbIssuer/api/json" \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["crumb"])')
  http=$(curl -s -o /dev/null -w '%{http_code}' -b "$jar" -u "admin:$PW" \
      -H "Jenkins-Crumb: $c" -X POST "$1")
  rm -f "$jar"
  echo "$http"
}

if [ -n "${BRANCH_OVERRIDE:-}" ]; then
  BRANCH="$BRANCH_OVERRIDE"; BRANCH_SOURCE=parameter
else
  BRANCH="${GIT_BRANCH#origin/}"; BRANCH_SOURCE=scm
fi

PROD_PROMOTED=no
[ "$BRANCH" = "master" ] && PROD_PROMOTED=yes

COMMIT=$(git rev-parse --short HEAD)
IMAGE="abode-website:b${BUILD_NUMBER}"

echo "BRANCH=$BRANCH"
echo "BRANCH_SOURCE=$BRANCH_SOURCE"
echo "REF=${GIT_BRANCH:-none}"
echo "COMMIT=$COMMIT"
echo "PROD_PROMOTED=$PROD_PROMOTED"

docker build -t "$IMAGE" -t abode-website:latest .
IMAGE_ID=$(docker image inspect --format '{{.Id}}' "$IMAGE")
echo "IMAGE=$IMAGE"
echo "IMAGE_ID=$IMAGE_ID"

HTTP=$(crumb_post "$JENKINS/job/Job2-test/buildWithParameters?BRANCH=$BRANCH&PROD_PROMOTED=$PROD_PROMOTED&IMAGE=$IMAGE&IMAGE_ID=$IMAGE_ID&COMMIT=$COMMIT")
echo "JOB2_TRIGGER_HTTP=$HTTP"
[ "$HTTP" = "201" ] || { echo "RESULT FAIL could not trigger Job2-test (http $HTTP)"; exit 1; }
echo "RESULT BUILD PASS image=$IMAGE"
