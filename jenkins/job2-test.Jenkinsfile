// Capstone 1 — Job2 test. Pulls the image CodeBuild just pushed and checks it actually serves the
// product page. This is the "test" that makes the chain meaningful: without an assertion on the
// served bytes, a green pipeline proves only that docker build exited 0.
//
// Runs on the `test` agent, so the thing being tested is reachable from the machine that will run it.
pipeline {
  agent { label 'test' }
  parameters {
    string(name: 'GIT_SHA', defaultValue: '', description: 'image tag to test')
  }
  environment {
    REGISTRY = 'docker.io'
    IMAGE    = 'this1sn0tme/abode-website'
    PORT     = '8091'
  }
  stages {
    stage('pull the built image') {
      steps {
        sh '''
          TAG="${GIT_SHA:-latest}"
          echo "pulling $REGISTRY/$IMAGE:$TAG"
          docker pull "$REGISTRY/$IMAGE:$TAG"
          docker image inspect --format='IMAGE_ID={{.Id}} SIZE={{.Size}}' "$REGISTRY/$IMAGE:$TAG"
        '''
      }
    }
    stage('serve it and assert the page') {
      steps {
        sh '''
          TAG="${GIT_SHA:-latest}"
          docker rm -f capstone1-test >/dev/null 2>&1 || true
          docker run -d --name capstone1-test -p "$PORT:80" "$REGISTRY/$IMAGE:$TAG"
          for i in $(seq 1 20); do
            sleep 2
            if curl -fsS --max-time 5 "http://localhost:$PORT/" > /tmp/page.html 2>/dev/null; then break; fi
          done
          echo "--- served page ---"
          cat /tmp/page.html
          grep -q 'Hello world!' /tmp/page.html || { echo "ASSERT_FAIL: product text missing"; exit 1; }
          echo "ASSERT_PAGE=Hello world!"
          curl -fsS -o /dev/null -w 'ASSERT_ASSET=http=%{http_code} bytes=%{size_download}\n' \
            "http://localhost:$PORT/images/github3.jpg"
        '''
      }
    }
  }
  post {
    always {
      sh 'docker rm -f capstone1-test >/dev/null 2>&1 || true'
    }
  }
}
