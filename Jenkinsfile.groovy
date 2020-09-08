pipeline {
  agent {
    label "sceptre-builder"
  }

  environment {
    ORG = "TODO" // TODO. Add real org later.
    APP_NAME = "sceptre"
    LANG = "C.UTF-8"
    LC_ALL = "C.UTF-8"
    ARTIFACTORY = "TODO" // TODO. Add real artifactory later. See /var/tmp
  }

  stages {
    stage("CI build") {
      when {
        branch "master"
      }
      steps {
        container("awscli") {
          sh "pip3 install -r requirements/dev.txt" // Rather not bake this in.
          sh "make lint"
          sh "make test"
          sh "make test-all"
          sh "make test-integration"
          sh "make coverage"
        }
      }
    }

    stage("Build Release") {
      when {
        branch "master"
      }
      environment {
        VERSION = "xxxx" // TODO.
      }
      steps {
        container("awscli") {
          sh "echo \"[distutils]\nindex-servers =\n    local\n\n[local]\nrepository = https://$ARTIFACTORY/artifactory/sceptre-release-local/au/com/$ORG/$APP_NAME/2.3.0-local$VERSION\nusername = xxx\npassword = $PASSWORD\" > /root/.pypirc"
          sh "make dist" // TODO. See https://www.jfrog.com/confluence/display/JFROG/PyPI+Repositories#PyPIRepositories-Uploading. Makefile may need "upload" etc.
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
