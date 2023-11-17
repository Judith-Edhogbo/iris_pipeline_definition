pipeline {
    agent any
    environment {
	   TRAIN_NUMBER = "$params.TRAIN_NUMBER"
            PIPELINE= sh (
                script: 'echo "$JOB_NAME" | sed  -e "s/"_deploy"//"',
                returnStdout: true
            ).trim()
    }
    stages {
    stage('Download variables file'){
        steps{
        	sh '''
	 	      rm -f $PIPELINE.groovy
		      gcloud storage cp gs://jenkins-pipeline-test/envirinment/$PIPELINE.groovy $PIPELINE.groovy
  		    envsubst < $PIPELINE.groovy >> test.groovy
    		  rm $PIPELINE.groovy		
      		cp test.groovy $PIPELINE.groovy
      		rm -rf test.groovy
      		'''
          }
        } 
    stage('load variables file'){
        steps{
		load "${PIPELINE}.groovy"
      	}
      }   
       stage('Cloning repo') {
          steps {
            checkout scmGit(
                branches: [[name: 'main']],
                userRemoteConfigs: [[
                    credentialsId: "${CREDENTIALS_NAME}", 
                    url: env.DEPLOY_REPO_URL
                    ]]
                )
           }
        } 
        stage('build and push docker image'){
        steps{
          sh '''
          rm -rf temp.json
	        echo ${VAR_STRING} >> temp.json   	
	 	cat temp.json
   		echo ${KEYS}
   	      for t in ${KEYS}; do
	        sed -i s+$t+"$( jq .${t} temp.json)"+g app.py
	        done
	        rm -rf temp.json
	 sed -i s+'${BUILD_NUMBER}'+${TRAIN_NUMBER}+g app.py
          cat app.py
	  
          '''
        }
      }  
        
        
    }        
} 
