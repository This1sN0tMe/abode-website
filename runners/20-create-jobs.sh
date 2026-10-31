#!/usr/bin/env bash
# 20-create-jobs.sh — Capstone 1's three freestyle jobs, created through the REST API.
#
#   bash runners/20-create-jobs.sh                                   # SCM = the fork on GitHub
#   REPO_URL=file:///Users/user/dev/labs/devops/capstones/capstone1 \
#     bash runners/20-create-jobs.sh                                 # pre-flight against the local clone
#
# Why freestyle and not a Jenkinsfile: requirement 5 says "a Jenkins Pipeline with jobs: Job1 build,
# Job2 test, Job3 prod" — three jobs, chained. A single declarative pipeline with three stages is a
# different artifact. Freestyle also sidesteps the module-6 defect where github-plugin 1.47.0 logs
# "Poked <job>" and starts nothing on Pipeline jobs; on a freestyle job the same payload builds, and it
# prints "Started by GitHub push by <user>", which is the textual proof requirement 3 needs.
#
# All three run on the built-in node: it is the only one with a working docker context (colima).
# Requirement 5 names jobs, not machines — the two-agent topology belongs to module 6.2 and Capstone 2.
#
# The shell bodies live in runners/job{1,2,3}-*.sh and each job only runs `bash runners/<script>`. An
# inline command block has to be XML-escaped — a bare `2>&1` is invalid XML and made createItem return
# 500 with an HTML error page while this script printed "CREATED". Bodies in files cannot be mis-escaped.
set -u

JENKINS=${JENKINS:-http://localhost:8080}
JROOT=${JROOT:-$HOME/dev/labs/devops/jenkins}
PW=$(tr -d '\n' < "$JROOT/.admin_pw")
REPO_URL=${REPO_URL:-git@github.com:This1sN0tMe/abode-website.git}
TRIGGER_FILE=$JROOT/.capstone_trigger_token
CAP=$(cd "$(dirname "$0")/.." && pwd)

crumb() { curl -s -c /tmp/cap-jc.txt -u "admin:$PW" "$JENKINS/crumbIssuer/api/json" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["crumb"])'; }

[ -s "$TRIGGER_FILE" ] || { openssl rand -hex 12 > "$TRIGGER_FILE"; chmod 600 "$TRIGGER_FILE"; }
TOKEN=$(tr -d '\n' < "$TRIGGER_FILE")

SCM_XML="<scm class=\"hudson.plugins.git.GitSCM\" plugin=\"git\">
    <configVersion>2</configVersion>
    <userRemoteConfigs><hudson.plugins.git.UserRemoteConfig><url>$REPO_URL</url></hudson.plugins.git.UserRemoteConfig></userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec><name>*/master</name></hudson.plugins.git.BranchSpec>
      <hudson.plugins.git.BranchSpec><name>*/develop</name></hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class=\"empty-list\"/>
    <extensions/>
  </scm>"

GH_TRIGGER='<com.cloudbees.jenkins.GitHubPushTrigger plugin="github"><spec></spec></com.cloudbees.jenkins.GitHubPushTrigger>'
J1_PARAMS='<hudson.model.ParametersDefinitionProperty><parameterDefinitions><hudson.model.StringParameterDefinition><name>BRANCH_OVERRIDE</name><description>Pre-flight only: force the branch instead of reading GIT_BRANCH from the push.</description><defaultValue></defaultValue><trim>true</trim></hudson.model.StringParameterDefinition></parameterDefinitions></hudson.model.ParametersDefinitionProperty>'
PARAMS='<hudson.model.ParametersDefinitionProperty><parameterDefinitions><hudson.model.StringParameterDefinition><name>BRANCH</name><defaultValue>develop</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition><hudson.model.StringParameterDefinition><name>PROD_PROMOTED</name><defaultValue>no</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition><hudson.model.StringParameterDefinition><name>IMAGE</name><defaultValue>abode-website:latest</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition><hudson.model.StringParameterDefinition><name>IMAGE_ID</name><defaultValue>none</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition><hudson.model.StringParameterDefinition><name>COMMIT</name><defaultValue>none</defaultValue><trim>true</trim></hudson.model.StringParameterDefinition></parameterDefinitions></hudson.model.ParametersDefinitionProperty>'

job_xml() { # $1 job name, $2 description, $3 script, $4 triggers, $5 params, $6 blockUpstream
  cat <<XML
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>$2</description>
  <keepDependencies>false</keepDependencies>
  <properties>$5</properties>
  ${7:-$SCM_XML}
  <assignedNode>built-in</assignedNode>
  <canRoam>false</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>$6</blockBuildWhenUpstreamBuilding>
  <authToken>$TOKEN</authToken>
  <triggers>$4</triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell><command>bash $3</command></hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
XML
}

upsert() { # $1 job name, $2 xml file
  local job=$1 xml=$2 code
  if ! xmllint --noout "$xml" 2>/tmp/cap-xml.err; then
    echo "XML INVALID for $job: $(head -2 /tmp/cap-xml.err)"; return 1
  fi
  code=$(curl -s -o /tmp/cap-resp.out -w '%{http_code}' -b /tmp/cap-jc.txt -u "admin:$PW" \
    -H "Jenkins-Crumb: $(crumb)" -H 'Content-Type: application/xml' \
    --data-binary "@$xml" "$JENKINS/job/$job/config.xml")
  [ "$code" = "200" ] && { echo "UPDATED $job"; return 0; }
  code=$(curl -s -o /tmp/cap-resp.out -w '%{http_code}' -b /tmp/cap-jc.txt -u "admin:$PW" \
    -H "Jenkins-Crumb: $(crumb)" -H 'Content-Type: application/xml' \
    --data-binary "@$xml" "$JENKINS/createItem?name=$job")
  [ "$code" = "200" ] && { echo "CREATED $job"; return 0; }
  echo "FAILED $job (http $code)"; grep -o '<title>[^<]*' /tmp/cap-resp.out | head -1
  return 1
}

echo "== SCM: $REPO_URL"
job_xml Job1-build "Capstone 1 - Job1 build. Triggered by a GitHub push on master or develop." "$CAP/runners/job1-build.sh" "$GH_TRIGGER" "$J1_PARAMS" false > /tmp/job1.xml
job_xml Job2-test  "Capstone 1 - Job2 test. Asserts the served bytes; invokes Job3 only on a master push." "$CAP/runners/job2-test.sh" "" "$PARAMS" true '<scm class="hudson.scm.NullSCM"/>' > /tmp/job2.xml
job_xml Job3-prod  "Capstone 1 - Job3 prod. Deploys the exact image Job2 verified." "$CAP/runners/job3-prod.sh" "" "$PARAMS" true '<scm class="hudson.scm.NullSCM"/>' > /tmp/job3.xml

upsert Job1-build /tmp/job1.xml
upsert Job2-test  /tmp/job2.xml
upsert Job3-prod  /tmp/job3.xml

echo "== read-back"
for j in Job1-build Job2-test Job3-prod; do
  code=$(curl -s -o /tmp/v-$j.xml -w '%{http_code}' -u "admin:$PW" "$JENKINS/job/$j/config.xml")
  printf 'JOB %-11s http=%s ' "$j" "$code"
  if [ "$code" = "200" ]; then
    printf 'bytes=%s node=%s branch_specs=%s gh_trigger=%s cmd=%s\n' \
      "$(wc -c < /tmp/v-$j.xml | tr -d ' ')" \
      "$(grep -o '<assignedNode>[^<]*' /tmp/v-$j.xml | sed 's/.*>//' | head -1)" \
      "$(grep -c '<hudson.plugins.git.BranchSpec>' /tmp/v-$j.xml)" \
      "$(grep -c GitHubPushTrigger /tmp/v-$j.xml)" \
      "$(grep -o '<command>[^<]*' /tmp/v-$j.xml | sed 's/.*>//' | head -1)"
  else
    echo "(config not readable)"
  fi
done
echo "== trigger token: $TRIGGER_FILE (len ${#TOKEN})"
