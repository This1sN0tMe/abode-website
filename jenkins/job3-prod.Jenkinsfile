// Capstone 1 — Job3 prod. Promotes the *same* image digest that Job2 tested: no rebuild, no retag
// drift. The digest is read back from the registry and compared with the one Job2 recorded, so
// "what was tested is what is running" is a checked fact rather than an intention.
pipeline {
  agent { label 'prod' }
  parameters {
    string(name: 'GIT_SHA', defaultValue: '', description: 'image tag that passed test')
    string(name: 'TESTED_DIGEST', defaultValue: '', description: 'digest Job2 verified (may be empty)')
  }
  environment {
    REGISTRY = 'docker.io'
    IMAGE    = 'this1sn0tme/abode-website'
    PORT     = '8092'
  }
  stages {
    stage('resist retag drift') {
      steps {
        sh '''
          TAG="${GIT_SHA:-latest}"
          docker pull "$REGISTRY/$IMAGE:$TAG" >/dev/null
          DIGEST=$(docker image inspect --format='{{index .RepoDigests 0}}' "$REGISTRY/$IMAGE:$TAG" | sed 's/.*@//')
          echo "PROD_DIGEST=$DIGEST"
          if [ -n "${TESTED_DIGEST:-}" ] && [ "$DIGEST" != "$TESTED_DIGEST" ]; then
            echo "ASSERT_FAIL: prod digest $DIGEST != tested digest $TESTED_DIGEST"
            exit 1
          fi
          echo "SAME_ARTIFACT=yes"
        '''
      }
    }
    stage('run it on the prod server') {
      steps {
        sh '''
          TAG="${GIT_SHA:-latest}"
          docker rm -f capstone1-prod >/dev/null 2>&1 || true
          docker run -d --name capstone1-prod -p "$PORT:80" "$REGISTRY/$IMAGE:$TAG"
          for i in $(seq 1 20); do
            sleep 2
            if curl -fsS --max-time 5 "http://localhost:$PORT/" > /tmp/prod.html 2>/dev/null; then break; fi
          done
          grep -q 'Hello world!' /tmp/prod.html || { echo "ASSERT_FAIL: prod page wrong"; exit 1; }
          echo "ASSERT_PROD=Hello world!"
          curl -fsS -o /dev/null -w 'PROD_ASSET=http=%{http_code} bytes=%{size_download}\n' \
            "http://localhost:$PORT/images/github3.jpg"
        '''
      }
    }
  }
}
