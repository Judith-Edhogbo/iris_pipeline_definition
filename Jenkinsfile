pipeline {
    agent any
    environment {
	   VAR_STRING_TRAIN = "$params.VAR_STRING_TRAIN"
           KEYS_TRAIN = "$params.KEYS_TRAIN"
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
	        echo $VAR_STRING_TRAIN >> temp.json   	
	 	cat temp.json
   	      for t in $KEYS_TRAIN; do
	        sed -i s+$t+"$( jq .${t} temp.json)"+g app.py
	        done
	        rm -rf temp.json
          cat app.py
	  
          '''
        }
      }  
        
        }
    }        
} 
