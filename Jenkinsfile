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
        stage('Clone Terraform code') {
                 steps {
                     echo 'This is cloning Terraform application'
                     sh 'mkdir -p terraform_build'
                     dir('terraform_build') {
                        git branch: 'main', url: 'https://github.com/hashicorp/terraform'
      }     
                 }
        }
        
        stage('Build') {
            steps {
                withEnv(["PATH+GO=${GOPATH}/bin"]){
                echo 'Compiling and building'
//                cleanWS ()
                sh 'go build'
                }
            }
        }

//        stage('Test') {
//            steps {
//                withEnv(["PATH+GO=${GOPATH}/bin"]){
//                    echo 'Running vetting'
//                    sh 'go vet .'
//                    echo 'Running linting'
//                    sh 'golint .'
//                    echo 'Running test'
//                    sh 'cd test && go test -v'
//                }
//            }
//        }
        
    }
}