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
//        stage('Pre Test') {
//            steps {
//                echo 'Installing dependencies'
//                sh 'go version'
//                sh 'go clean -cache'
//                sh 'go get -u golang.org/x/lint/golint'
//            }
//        }
        
        stage('Build') {
            steps {
                withEnv(["GOROOT=${GOPATH}", "GOPATH=${JENKINS_HOME}/jobs/${JOB_NAME}/builds/${BUILD_ID}/", "PATH+GO=${GOPATH}/bin"]){
                echo 'Compiling and building'
//                cleanWS ()
                sh 'go version'
                sh 'go clean -cache'
                sh 'go get -u golang.org/x/lint/golint'
                sh 'go build'
                }
            }
        }

        stage('Test') {
            steps {
                withEnv(["PATH+GO=${GOPATH}/bin"]){
                    echo 'Running vetting'
                    sh 'go vet .'
                    echo 'Running linting'
                    sh 'golint .'
                    echo 'Running test'
                    sh 'cd test && go test -v'
                }
            }
        }
        
    }
}