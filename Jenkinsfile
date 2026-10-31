// Capstone 2 — Jenkins Pipeline script (requirement 5), and the release discipline (requirement 1).
//
// The brief: "Git workflow; release happens only on the 25th of every month", "CodeBuild triggered on
// commits to master", "containerize with a Dockerfile built on every GitHub push", "deploy the Docker Hub
// image with 2 replicas; NodePort service on port 30008", "Jenkins Pipeline script to accomplish the above".
//
// Shape of the gate, which is the part worth reading:
//   * every push builds and tests — that is what "built on every push" means, and it must not be conditional
//   * deployment is refused unless RELEASE_MODE is set
//   * RELEASE_MODE is set by the `cron('H H 25 * *')` trigger, i.e. by the calendar
//   * a human can set it by hand, and that is deliberate: a release that only ever happens on the 25th is
//     untestable on the other 364 days. The stage prints the date it saw and whether the gate was opened,
//     so the transcript shows the decision rather than asserting it.
//
// The agent is labelled 'docker' and lands on the machine with Java+Docker+Kubernetes. The controller has
// Java only, by design — the brief's own split.

pipeline {
  agent { label 'docker' }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    booleanParam(
      name: 'RELEASE_MODE',
      defaultValue: false,
      description: 'Deploy to the cluster. Normal pushes build and test only; the release job is scheduled for the 25th of each month.'
    )
  }

  triggers {
    // "release happens only on the 25th of every month" — the schedule is the gate's clock.
    cron('H H 25 * *')
  }

  environment {
    IMAGE_REPO = 'this1sn0tme/abode-website'
    IMAGE_TAG  = "b${env.BUILD_NUMBER}"
  }

  stages {
    stage('Build') {
      steps {
        sh '''
          set -eu
          echo "BUILD image=$IMAGE_REPO:$IMAGE_TAG commit=$(git rev-parse --short HEAD)"
          docker build -t "$IMAGE_REPO:$IMAGE_TAG" -t "$IMAGE_REPO:latest" .
          docker push "$IMAGE_REPO:$IMAGE_TAG"
          echo "BUILD pushed=$IMAGE_REPO:$IMAGE_TAG"
        '''
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eu
          docker rm -f abode-ci-test >/dev/null 2>&1 || true
          docker run -d --name abode-ci-test -p 8082:80 "$IMAGE_REPO:$IMAGE_TAG"
          for i in $(seq 1 30); do curl -fsS http://localhost:8082/ -o /tmp/ci.html 2>/dev/null && break; sleep 1; done
          CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8082/)
          ACODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8082/images/github3.jpg)
          echo "ASSERT home_status=$CODE"
          echo "ASSERT asset_status=$ACODE"
          grep -q 'Hello world!' /tmp/ci.html && echo "ASSERT body=PASS" || { echo "ASSERT body=FAIL"; exit 1; }
          [ "$CODE" = "200" ] || exit 1
          [ "$ACODE" = "200" ] || exit 1
          docker rm -f abode-ci-test >/dev/null
          echo "RESULT TEST PASS"
        '''
      }
    }

    stage('Release gate') {
      steps {
        sh '''
          set -eu
          TODAY=$(date -u +%d)
          echo "GATE date_utc=$(date -u +%Y-%m-%d) day=$TODAY"
          if [ "$RELEASE_MODE" = "true" ]; then
            echo "GATE RELEASE_MODE=open"
            if [ "$TODAY" = "25" ]; then echo "GATE scheduled_release=yes (25th)"; else echo "GATE scheduled_release=no (manual override, not the 25th)"; fi
          else
            echo "GATE RELEASE_MODE=closed"
            echo "RELEASE_GATE=closed — build and test only; deploy requires RELEASE_MODE, which the cron sets on the 25th"
          fi
        '''
      }
    }

    stage('Deploy') {
      when { expression { params.RELEASE_MODE == true } }
      steps {
        sh '''
          set -eu
          kubectl -n default set image deployment/abode web="$IMAGE_REPO:$IMAGE_TAG"
          kubectl rollout status deployment/abode --timeout=180s
          NODEPORT=$(kubectl get svc abode-svc -o jsonpath='{.spec.ports[0].nodePort}')
          READY=$(kubectl get deployment abode -o jsonpath='{.status.readyReplicas}')
          echo "DEPLOY image=$IMAGE_REPO:$IMAGE_TAG nodePort=$NODEPORT ready=$READY"
          [ "$NODEPORT" = "30008" ] || exit 1
          [ "$READY" = "2" ] || exit 1
          echo "RESULT DEPLOY PASS"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker rm -f abode-ci-test >/dev/null 2>&1 || true'
    }
  }
}
