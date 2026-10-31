#!/usr/bin/env bash
# Job2 test — the test stage of Capstone 1.
#
# "test" is an assertion, not a stage name: the image is run and the served bytes are checked, so a green
# build means the product answers, not that docker build exited 0.
#
# The prod hand-off is gated here because this is where the tested branch is known. A develop push is
# test-only by requirement 3b, and the console says so rather than silently skipping.
set -eu

JENKINS=${JENKINS:-http://localhost:8080}
JROOT=${JROOT:-$HOME/dev/labs/devops/jenkins}
PW=$(tr -d '\n' < "$JROOT/.admin_pw")
TEST_PORT=${TEST_PORT:-8081}

crumb_post() { # $1 full URL — basic auth plus a CSRF crumb; a job authToken alone returns 403 here
  local jar http c
  jar=$(mktemp)
  c=$(curl -s -c "$jar" -u "admin:$PW" "$JENKINS/crumbIssuer/api/json" \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["crumb"])')
  http=$(curl -s -o /dev/null -w '%{http_code}' -b "$jar" -u "admin:$PW" \
      -H "Jenkins-Crumb: $c" -X POST "$1")
  rm -f "$jar"
  echo "$http"
}

echo "BRANCH=${BRANCH:-unset} PROD_PROMOTED=${PROD_PROMOTED:-unset}"
echo "IMAGE=${IMAGE:-unset} COMMIT=${COMMIT:-unset}"

docker rm -f abode-test >/dev/null 2>&1 || true
docker run -d --name abode-test -p "$TEST_PORT:80" "$IMAGE"

for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:$TEST_PORT/" -o /tmp/abode-test.html 2>/dev/null; then break; fi
  sleep 1
done

CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$TEST_PORT/")
ACODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$TEST_PORT/images/github3.jpg")
ABYTES=$(curl -s -o /dev/null -w '%{size_download}' "http://localhost:$TEST_PORT/images/github3.jpg")

echo "ASSERT home_status=$CODE"
echo "ASSERT asset_status=$ACODE"
echo "ASSERT asset_bytes=$ABYTES"

[ "$CODE" = "200" ] || { echo "RESULT FAIL home_status"; exit 1; }
[ "$ACODE" = "200" ] || { echo "RESULT FAIL asset_status"; exit 1; }
grep -q 'Hello world!' /tmp/abode-test.html \
  && echo "ASSERT body=Hello world! PASS" \
  || { echo "ASSERT body=Hello world! FAIL"; exit 1; }
echo "RESULT TEST PASS image=$IMAGE"

if [ "${PROD_PROMOTED:-no}" = "yes" ]; then
  HTTP=$(crumb_post "$JENKINS/job/Job3-prod/buildWithParameters?BRANCH=$BRANCH&IMAGE=$IMAGE&IMAGE_ID=$IMAGE_ID&COMMIT=$COMMIT")
  echo "JOB3_TRIGGER_HTTP=$HTTP"
  [ "$HTTP" = "201" ] || { echo "RESULT FAIL could not trigger Job3-prod"; exit 1; }
  echo "TRIGGERED Job3-prod (branch $BRANCH)"
else
  echo "PROD_PROMOTED=no - Job3-prod not invoked; a develop push is test-only"
  echo "PROD_SKIPPED=yes"
fi
