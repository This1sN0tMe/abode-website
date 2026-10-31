// Capstone 1 — Job1 build. Jenkins does not build; CodeBuild does. This job starts the CodeBuild
// project for the pushed commit and waits for it, so "the container is built on every GitHub push"
// is CodeBuild's work and Jenkins' chain still has a build step with a real exit code.
//
// The CodeBuild project is triggered independently by its own webhook on the same push (that is what
// requirement 3 asks for). If the webhook build for this commit already exists, this job adopts it
// instead of starting a second one.
pipeline {
  agent any
  parameters {
    string(name: 'GIT_SHA', defaultValue: '', description: 'commit to build; empty = HEAD of develop')
  }
  environment {
    PROJECT = 'abode-website'
    REGION  = 'us-east-1'
    IMAGE   = 'docker.io/this1sn0tme/abode-website'
  }
  stages {
    stage('resolve commit') {
      steps {
        script {
          def sha = params.GIT_SHA ?: sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
          env.BUILT_SHA = sha
          echo "commit ${sha}"
        }
      }
    }
    stage('start or adopt the CodeBuild build') {
      steps {
        script {
          def existing = sh(returnStdout: true, script: """
            aws codebuild list-builds-for-project --project-name \$PROJECT --region \$REGION \
              --query 'ids' --output text 2>/dev/null | tr '\\t' '\\n' | head -20
          """).trim().split('\n').findAll { it }
          def adopted = ''
          for (id in existing) {
            def src = sh(returnStdout: true, script: """
              aws codebuild batch-get-builds --ids $id --region \$REGION \
                --query 'builds[0].{src:sourceVersion,ver:sourceVersion}' --output text 2>/dev/null
            """).trim()
            if (src.contains(env.BUILT_SHA)) { adopted = id; break }
          }
          if (adopted) {
            echo "adopting the webhook build for this commit: $adopted"
            env.BUILD_ID = adopted
          } else {
            def out = sh(returnStdout: true, script: """
              aws codebuild start-build --project-name \$PROJECT --region \$REGION \
                --source-version \$BUILT_SHA --query 'build.id' --output text
            """).trim()
            echo "started CodeBuild: $out"
            env.BUILD_ID = out
          }
        }
      }
    }
    stage('wait for CodeBuild') {
      steps {
        script {
          def status = 'IN_PROGRESS'
          for (int i = 0; i < 90 && status == 'IN_PROGRESS'; i++) {
            sleep 10
            status = sh(returnStdout: true, script: """
              aws codebuild batch-get-builds --ids \$BUILD_ID --region \$REGION \
                --query 'builds[0].buildStatus' --output text
            """).trim()
          }
          echo "CodeBuild status: ${status}"
          if (status != 'SUCCEEDED') { error("CodeBuild finished ${status} for ${env.BUILT_SHA}") }
          env.IMAGE_URI = sh(returnStdout: true, script: """
            aws codebuild batch-get-builds --ids \$BUILD_ID --region \$REGION \
              --query 'builds[0].{image:environment.environmentVariables[?name==`IMAGE_REPO`].value|[0]}' \
              --output text
          """).trim()
          echo "image: ${env.IMAGE}@${env.BUILT_SHA}"
        }
      }
    }
  }
}
