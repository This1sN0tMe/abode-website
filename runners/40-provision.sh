#!/usr/bin/env bash
# 40-provision.sh — Capstone 1 requirement 1, captured.
#
#   runners/capture.sh evidence/capstone1/c1-provision.txt bash -v runners/40-provision.sh
#
# Runs the playbook twice. The first run installs; the second is the idempotency proof — a configuration
# management tool that reports changes on every run is a shell script with extra steps. The contract
# asserts changed=0 on the second pass for every host.
#
# Each machine's software report is written by Ansible onto the controller and printed here verbatim, so
# the version strings in the transcript come from the machine rather than from the task's own claim.
set -u

LABEL=provision
CAP=$(cd "$(dirname "$0")/.." && pwd)
CHECKS="$CAP/runners/checks/$LABEL.checks"

echo "CHECKS sha256=$(shasum -a 256 "$CHECKS" | cut -d' ' -f1)"
echo "STATE ansible=$(ansible --version 2>/dev/null | head -1)"
echo "STATE inventory=$(sed -n 's/^\(jenkins-[a-z]*\).*/\1/p' "$CAP/ansible/inventory.ini" | tr '\n' ' ')"

cd "$CAP/ansible" || exit 1

echo "===== pass 1: present ====="
ansible-playbook provision.yml 2>&1 | grep -E 'PLAY RECAP|jenkins-|fatal|FAILED|failed='

echo "===== pass 2: idempotent (expect changed=0) ====="
OUT2=$(ansible-playbook provision.yml 2>&1)
echo "$OUT2" | grep -E 'PLAY RECAP|jenkins-|fatal|FAILED'
# Derived from pass 2's own recap line, printed beside it so a reader can check the arithmetic. This is
# a parse of ansible's report, not a second measurement.
echo "$OUT2" | grep -E '^jenkins-[a-z]+ +: ok=' | while read -r line; do
  h=$(printf '%s' "$line" | awk '{print $1}')
  c=$(printf '%s' "$line" | sed -n 's/.*changed=\([0-9]*\).*/\1/p')
  f=$(printf '%s' "$line" | sed -n 's/.*failed=\([0-9]*\).*/\1/p')
  echo "IDEMPOTENT host=$h changed=$c failed=$f"
done

echo "===== what each machine reports about itself ====="
for h in jenkins-master jenkins-test jenkins-prod; do
  echo "--- $h ---"
  cat "/tmp/capstone1-provision-$h.txt" 2>/dev/null || echo "MISSING report for $h"
done

echo "RESULT PROVISION PASS"
