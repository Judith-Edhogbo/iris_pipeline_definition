#!/bin/bash
export JENKINS_USER="api"
export JENKINS_USER_API_TOKEN=$(gcloud secrets versions access 1 --secret="jenkins_api_token")
export JENKINS_ADDRESS="35.228.3.36"
export BASIC_AUTH=${JENKINS_USER}:$JENKINS_USER_API_TOKEN
export CREDENTIALS_NAME="api_credentials_$RANDOM"

export BRANCH_NAME="main"
export BRANCH_NAME2="main"

####################VARIABLES FROM VARIABLES FILE#################################
export PIPELINE_NAME=$(jq ".PIPELINE_NAME" var.json| tr -d '"')
export GITHUB_URL=$(jq ".GITHUB_URL" var.json| tr -d '"')
export GITHUB_URL2=$(jq ".GITHUB_URL2" var.json| tr -d '"')

###################VARIABLES BY ASKING USER#################################
#echo "Please provide a name for the pipeline"
#read PIPELINE_NAME
#export PIPELINE_NAME=$PIPELINE_NAME
#echo "Please provide the https link to the github repository containing your training Jenkinsfile" 
#read GITHUB_URL
#export GITHUB_URL=$GITHUB_URL
#echo "Please provide the https link to the github repository containing your deployment Jenkinsfile" 
#read GITHUB_URL2
#export GITHUB_URL2=$GITHUB_URL2
##########################################################################

export TRAIN_PIPELINE_NAME="${PIPELINE_NAME}_train"
export DEPLOY_PIPELINE_NAME="${PIPELINE_NAME}_deploy"

printf "Please provide your github personal access token"
stty -echo
read TOKEN
stty echo

export TOKEN=$TOKEN

########## Uncomment the 2 lines below if using another jenkins server (You need to get the xml template from an existing pipeline in you Jenkins environment)
#export EXISTING_PIPELINE=Train_v2
#curl -X GET  http://${BASIC_AUTH}@${JENKINS_ADDRESS}/job/{EXISTING_PIPELINE}/config.xml -o jenkinsconfig.xml

#Create github credentials variable on Jenkins
curl -X POST http://${BASIC_AUTH}@${JENKINS_ADDRESS}/credentials/store/system/domain/_/createCredentials \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "'"$CREDENTIALS_NAME"'",
    "username": "jenkins",
    "password": "'"$TOKEN"'",
    "description": "github token",
    "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}'

#echo "Please provide the path to your terraform folder." 
#read TERRAFORM_FOLDER

export TERRAFORM_TRAIN_FOLDER="train_build"
export TERRAFORM_DEPLOY_FOLDER="deploy_build"

terraform workspace new train
terraform workspace new deploy

############################### TRAINING ENVIRONMENT ###############################################
terraform workspace select train

terraform -chdir=$TERRAFORM_TRAIN_FOLDER init
export TERRAFORM_PLAN=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER plan)

printf "$TERRAFORM_PLAN"

echo "Do you want to perform these actions?
  Terraform will perform the actions described above in the 'train' workspace.
  Only 'yes' will be accepted to approve " 

read yn

  case $yn in 
	"Y" | "y" | "YES" | "Yes" | "yes") echo ok, we will proceed;
		;;
    *) echo exiting...;
		exit;;
esac

export TERRAFORM_APPLY=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER apply -auto-approve)

printf "$TERRAFORM_APPLY"

VM_IP_ADDRESS=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output gcp_vm_ip_address)
VM_GCP_PROJECT=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output gcp_vm_gcp_project)
VM_NAME=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output gcp_vm_name)
VM_GCP_ZONE=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output gcp_vm_zone)
BUCKET_URL=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output storage_url)
BUCKET_NAME=$(terraform -chdir=$TERRAFORM_TRAIN_FOLDER output storage_name)

############################### DEPLOY ENVIRONMENT ###############################################
terraform workspace select deploy

terraform -chdir=$TERRAFORM_DEPLOY_FOLDER init
export TERRAFORM_PLAN=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER plan)
printf "$TERRAFORM_PLAN"

echo "Do you want to perform these actions?
  Terraform will perform the actions described above in the 'deploy' workspace.
  Only 'yes' will be accepted to approve " 

read yn

  case $yn in 
	"Y" | "y" | "YES" | "Yes" | "yes") echo ok, we will proceed;
		;;
    *) echo exiting...;
		exit;;
esac

export TERRAFORM_APPLY=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER apply -auto-approve)
printf "$TERRAFORM_APPLY"

VM_IP_ADDRESS_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output gcp_vm_ip_address)
VM_GCP_PROJECT_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output gcp_vm_gcp_project)
VM_NAME_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output gcp_vm_name)
VM_GCP_ZONE_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output gcp_vm_zone)
BUCKET_URL_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output storage_url)
BUCKET_NAME_2=$(terraform -chdir=$TERRAFORM_DEPLOY_FOLDER output storage_name)

#############CREATE ENV VARIABLE FILE ON GCS FOR JENKINS#############################
touch $PIPELINE_NAME.groovy  

cat > $PIPELINE_NAME.groovy  <<- EOM
env.TRAINING_VM_NAME = $VM_NAME
env.TRAINING_VM_GCP_PROJECT = $VM_GCP_PROJECT
env.TRAINING_VM_ZONE = $VM_GCP_ZONE
env.TRAINING_REPO_URL = "$GITHUB_URL"
env.DEPLOY_VM_NAME = $VM_NAME_2
env.DEPLOY_VM_GCP_PROJECT = $VM_GCP_PROJECT_2
env.DEPLOY_VM_ZONE = $VM_GCP_ZONE_2
env.DEPLOY_REPO_URL = "$GITHUB_URL2"
env.BUCKET_NAME = "jenkins-pipeline-test"
env.CREDENTIALS_NAME = "$CREDENTIALS_NAME"
EOM

cat << EOM >> $PIPELINE_NAME.groovy
env.BLOB_NAME = "\${JOB_NAME}_training_build_\${BUILD_NUMBER}" 
EOM

gcloud storage cp $PIPELINE_NAME.groovy   gs://jenkins-pipeline-test/envirinment

############################ CREATE TRAIN PIPELINE ON JENKINS #############################

envsubst < jenkinsconfig.xml >> $TRAIN_PIPELINE_NAME.xml 

curl -X POST http://${BASIC_AUTH}@${JENKINS_ADDRESS}/createItem?name=${TRAIN_PIPELINE_NAME} \
    --header "Content-Type:text/xml" \
    --data-binary @$TRAIN_PIPELINE_NAME.xml

echo "The name of your train pipeline is: $TRAIN_PIPELINE_NAME"

############################ CREATE DEPLOY PIPELINE ON JENKINS #############################
export GITHUB_URL=$GITHUB_URL2
export BRANCH_NAME=$BRANCH_NAME2

envsubst < jenkinsconfig.xml >> $DEPLOY_PIPELINE_NAME.xml 

curl -X POST http://${BASIC_AUTH}@${JENKINS_ADDRESS}/createItem?name=${DEPLOY_PIPELINE_NAME} \
    --header "Content-Type:text/xml" \
    --data-binary @$DEPLOY_PIPELINE_NAME.xml

echo "The name of your deploy pipeline is: $DEPLOY_PIPELINE_NAME"

#######################CLEAN UP ENVIRONMENT##################################################
rm $DEPLOY_PIPELINE_NAME.xml
rm $TRAIN_PIPELINE_NAME.xml
rm $PIPELINE_NAME.groovy
######################CREATE WEBHOOK ON TRAINING REPO#####################################
export WEBHOOK_STRING=$(echo "$GITHUB_URL" | sed -E 's/^\s*.*:\/\/github.com\///g')
export WEBHOOK_STRING=$(echo "$WEBHOOK_STRING" | sed -e "s/".git"//")

curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$WEBHOOK_STRING/hooks" \
  -d '{"name":"web","active":true,"events":["push"],"config":{"url":"'"http://${JENKINS_ADDRESS}/github-webhook/"'","content_type":"json","insecure_ssl":"0"}}'

####################RUN PIPELINE ONCE######################################################
echo "Your pipeline will be run once as a test run"
curl -X POST http://${BASIC_AUTH}@${JENKINS_ADDRESS}/job/${TRAIN_PIPELINE_NAME}/build


exit
