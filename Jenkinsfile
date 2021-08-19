pipeline {
    agent any
    tools {
        go 'go1.14'
    }
    environment {
        GO114MODULE = 'on'
        CGO_ENABLED = 0 
        GOPATH = "${JENKINS_HOME}/jobs/${JOB_NAME}/builds/${BUILD_ID}"
    }
    stages {        
        stage('Pre Test') {
            steps {
                echo 'Installing dependencies'
                sh 'go version'
                sh 'go clean -cache'
                sh 'go get -u golang.org/x/lint/golint'
            }
        }
        
        stage('Build') {
            steps {
                echo 'Compiling and building'
 //               cleanWS ()
                sh 'cd ${GOPATH}/src/golang.org/x/lint/ && go build'
            }
        }

        stage('Test') {
            steps {
                withEnv(["PATH+GO=${GOPATH}/bin"]){
                    echo 'Running vetting'
                    sh 'cd ${GOPATH}/src/golang.org/x/lint/ && go vet .'
                    echo 'Running linting'
                    sh 'cd ${GOPATH}/src/golang.org/x/lint/ && golint .'
                    echo 'Running test'
                    sh 'cd ${GOPATH}/src/golang.org/x/lint/testdata && go test -v'
                }
            }
        }
        
    }
}
