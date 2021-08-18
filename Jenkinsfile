pipeline {
         agent any
         stages {
                 stage('Git checkout') {
                 steps {
                     echo 'This is cloning a simple Python scripts'
                     dir('build_test') {
                        git branch: 'Jenkins_Python', url: 'https://github.com/rodrigopompei/hello-world-pompei'
      }     
                 }
                 }
                 stage('Program execution') {
                 steps {
                    sh 'cd python'
                    sh 'python main.py'
                 }
                 }
              }
}
