def call(Map pipelineParams) {

  pipeline {
    agent any
    stages {
      stage('Test') {
        steps {
        echo "Test successfull"
        echo pipelineParams.variable
        }
     }
    } 
  }    
}
