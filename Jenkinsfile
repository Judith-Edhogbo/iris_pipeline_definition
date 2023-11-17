pipeline {
    agent any
    environment {
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
	  
          sudo docker build -t europe-north1-docker.pkg.dev/gbg-nordics-sandbox/jenkins-pipeline-poc/${PIPELINE}_deploy:version_$BUILD_NUMBER .
          sudo gcloud auth print-access-token | sudo docker login -u oauth2accesstoken --password-stdin https://europe-north1-docker.pkg.dev
          sudo docker push europe-north1-docker.pkg.dev/gbg-nordics-sandbox/jenkins-pipeline-poc/${PIPELINE}_deploy:version_$BUILD_NUMBER
	      sudo docker rmi europe-north1-docker.pkg.dev/gbg-nordics-sandbox/jenkins-pipeline-poc/${PIPELINE}_deploy:version_$BUILD_NUMBER
          '''
        }
      }  
        stage('deploy'){
            steps{
                sh '''
                rm -f temporary_deployment_script.sh
                envsubst < deployment_script.sh >> temporary_deployment_script.sh
                cat temporary_deployment_script.sh
                gcloud compute ssh $DEPLOY_VM_NAME \
                --project=$DEPLOY_VM_GCP_PROJECT \
                --zone=$DEPLOY_VM_ZONE \
                --command="bash -s" < temporary_deployment_script.sh -- -tt
		        rm -f temporary_deployment_script.sh
                '''

            }
        }
    }        
} 
