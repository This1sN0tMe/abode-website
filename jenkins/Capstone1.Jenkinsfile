// Capstone 1 — the whole lifecycle as one chain: Job1 build (CodeBuild) -> Job2 test -> Job3 prod.
// agent none: an orchestrator that takes a worker's executor deadlocks when its downstream jobs need
// that same executor (learned the hard way in 6.3).
pipeline {
  agent none
  options { disableConcurrentBuilds() }
  parameters {
    string(name: 'GIT_SHA', defaultValue: '', description: 'commit to run through the lifecycle')
  }
  stages {
    stage('Job1 build') {
      steps {
        build job: 'job1-build', wait: true, propagate: true,
              parameters: [string(name: 'GIT_SHA', value: params.GIT_SHA)]
      }
    }
    stage('Job2 test') {
      steps {
        build job: 'job2-test', wait: true, propagate: true,
              parameters: [string(name: 'GIT_SHA', value: params.GIT_SHA)]
      }
    }
    stage('Job3 prod') {
      steps {
        // prod only runs if test passed: propagate: true on the previous stage is the gate
        build job: 'job3-prod', wait: true, propagate: true,
              parameters: [string(name: 'GIT_SHA', value: params.GIT_SHA)]
      }
    }
  }
  post {
    success { echo 'LIFECYCLE complete: build -> test -> prod' }
    failure { echo 'LIFECYCLE stopped: prod not reached' }
  }
}
