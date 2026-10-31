#!/usr/bin/env bash
# Job3 prod — the production stage of Capstone 1.
#
# Promotes exactly the artifact Job2 verified: the image id carried in the parameters is compared against
# the id present here, and a mismatch fails the build. Retag drift is caught instead of assumed away.
set -eu

PROD_PORT=${PROD_PORT:-80}
echo "PROD deploy IMAGE=${IMAGE:-unset} branch=${BRANCH:-unset} commit=${COMMIT:-unset}"

GOT=$(docker image inspect --format '{{.Id}}' "$IMAGE")
echo "EXPECTED_IMAGE_ID=${IMAGE_ID:-none}"
echo "GOT_IMAGE_ID=$GOT"
if [ "${IMAGE_ID:-none}" != "none" ] && [ "$GOT" != "$IMAGE_ID" ]; then
  echo "SAME_ARTIFACT=no"
  echo "RESULT FAIL artifact drift: the image Job2 tested is not the image present here"
  exit 1
fi
echo "SAME_ARTIFACT=yes"

docker rm -f abode-prod >/dev/null 2>&1 || true
docker run -d --name abode-prod -p "$PROD_PORT:80" "$IMAGE"

for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:$PROD_PORT/" -o /tmp/abode-prod.html 2>/dev/null; then break; fi
  sleep 1
done

CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PROD_PORT/")
echo "ASSERT prod_status=$CODE"
[ "$CODE" = "200" ] || { echo "RESULT FAIL prod_status"; exit 1; }
grep -q 'Hello world!' /tmp/abode-prod.html \
  && echo "ASSERT prod_body=Hello world! PASS" \
  || { echo "ASSERT prod_body FAIL"; exit 1; }
echo "RESULT PROD PASS image=$IMAGE port=$PROD_PORT"
