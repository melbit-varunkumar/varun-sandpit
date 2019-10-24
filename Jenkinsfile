def srcDir = 'src'
// Do not modify the following two lines without talking to the ADO Team.
def BASE_JENKINSFILE_NAME = "Jenkinsfile-terraform"
def BASE_JENKINSFILE_VERSION = "1.1.0"

/* Setting up some environment stuff:
// Mandatory:
// 1. CREDS - github credentials to use, as identified within Jenkins.
// 2. ACCOUNT - AWS account to use (used for the Vault approle authentication backend unless overridden with
//              VAULT_BACKEND, and to generate the approle username to use (ACCOUNT-deploy)).
//
// Optional:
// 3. ENVIRONMENT - Description for the environment. Used when logging changes. By default, it will use anything
//                  after the final - converted to upper case (so aws-45-dev would use DEV).
// 4. VAULT_BACKEND - Optional vault backend to use. If not specified, defaults to ACCOUNT.
// 5. CHANGE_CONTROL - String identifying change control method to use.
// 6. SLACK_CHANNEL - Slack channel to send notifications to.
// 7. TERRAFORM_CONTAINER_LABEL - Label of the terraform container to use. Defaults to "terraform"
*/

// --------- Red Cross Specific Variables ---------
def TERRAFORM_APPLY_SUCCESS         = ""  // Check if Terraform apply was successful.
def VPC                             = ""
def SUBNET_PUBLIC_A                 = ""
def SUBNET_PUBLIC_B                 = ""
def SUBNET_PUBLIC_C                 = ""
def SUBNET_APP_A                    = ""
def SUBNET_APP_B                    = ""
def SUBNET_APP_C                    = ""
def SUBNET_DATABASE_A               = ""
def SUBNET_DATABASE_B               = ""
def SUBNET_DATABASE_C               = ""
def YAML                            = ""


try {

    notifySlack()

    env.BASE_JENKINSFILE_NAME = "${BASE_JENKINSFILE_NAME}"
    env.BASE_JENKINSFILE_VERSION = "${BASE_JENKINSFILE_VERSION}"
    echo "Using ${BASE_JENKINSFILE_NAME} - ${BASE_JENKINSFILE_VERSION}"

    // Check whether a slack channel has been set
    if (env.SLACK_CHANNEL) {
        echo "Sending notifications to ${env.SLACK_CHANNEL}"
    }

    if (!env.VAULT_BACKEND) {
        env.VAULT_BACKEND = env.ACCOUNT
    }
    echo "Using VAULT_BACKEND of ${env.VAULT_BACKEND}"

    if (!env.CREDS) {
        error 'You must set CREDS as an environment variable. This must identify the credentials stored in ' +
                'Jenkins to be used to fetch the repositories from source control.'
    } else {
        echo "Using CREDS of ${env.CREDS}"
    }
    if (!env.ACCOUNT) {
        error 'You must set ACCOUNT as an environment variable. This must identify the AWS Account number (in the form ' +
                'aws-XXX). This is used to identify the Vault approle backend to use, and the customer for change control.'
    } else {
        echo "Using ACCOUNT of ${env.ACCOUNT}"
    }
    if (!env.ENVIRONMENT) {
        env.ENVIRONMENT = env.JOB_NAME.substring(env.JOB_NAME.lastIndexOf("-") + 1).toUpperCase()
    }

    // Use terraform012 container
    echo "Using ENVIRONMENT of ${env.ENVIRONMENT}"
    if (!env.TERRAFORM_CONTAINER_LABEL) {
        env.TERRAFORM_CONTAINER_LABEL = "terraform012"
    }
    echo "Using TERRAFORM_CONTAINER_LABEL of ${env.TERRAFORM_CONTAINER_LABEL}"

    node(env.TERRAFORM_CONTAINER_LABEL) {
        stage('Initialise AWS environment') {
            initAwsEnvironment(env.ACCOUNT, env.VAULT_BACKEND)
        }

        stage('Clone Git repository') {
            checkout scm
        }

        stage('Initialise Terraform') {
            initTerraform(srcDir, env.CREDS)
        }

        stage('Validate Terraform scripts') {
            validateTerraform(srcDir)
        }

        stage('Run Terraform Plan') {
            planOutput = runTerraformPlan(srcDir)
        }
    }

    switch (env.TERRAFORM_EXIT_CODE) {
        case "2":
            stage('Change Control') {
                if (env.CHANGE_CONTROL) {
                    change = env.CHANGE_CONTROL
                } else {
                    change = ""
                }
                echo "Using Change Control approach: ${change}"
                change_number = changeControl(env.ENVIRONMENT, env.ACCOUNT, planOutput, change, "")
            }

            node(env.TERRAFORM_CONTAINER_LABEL) {
                stage('Initialise AWS environment') {
                    initAwsEnvironment(env.ACCOUNT, env.VAULT_BACKEND)
                }

                stage('Clone Git repository') {
                    checkout scm
                }

                stage('Initialise Terraform') {
                    initTerraform(srcDir, env.CREDS)
                }
                stage('Run Terraform apply') {
                    runTerraformApply(srcDir)

                    sh 'terraform output'
                }
                switch (env.TERRAFORM_APPLY_EXIT_CODE) {
                    case "1":
                        closeChange(change_number, false)
                        error("Terraform apply encountered an error, please view the log for more information")
                        break
                    default:
                        closeChange(change_number, true)
                        TERRAFORM_APPLY_SUCCESS = "true"  // Set to true if infra created
                        echo "Terraform applied successfully."
                }
            }
            break;
        case "1":
            error("Terraform plan encountered an error, please view the log for more information")
            break;
        default:
            echo "No changes to infrastructure found, completing"
    }

    // Begin Red Cross Specific code
    /**********
    echo TERRAFORM_APPLY_SUCCESS
    if(TERRAFORM_APPLY_SUCCESS == "true") {
        node(env.TERRAFORM_CONTAINER_LABEL) {
            stage('Export Infrastructure Value') {
                // save vpc id, subnet id etc from terraform to jenkins
                VPC                 = sh 'terraform output vpc_id'
                SUBNET_PUBLIC_A     = sh 'terraform output -json subnets | jq \'.pub[0]\''
                SUBNET_PUBLIC_B     = sh 'terraform output -json subnets | jq \'.pub[1]\''
                SUBNET_PUBLIC_C     = sh 'terraform output -json subnets | jq \'.pub[2]\''
                SUBNET_APP_A        = sh 'terraform output -json subnets | jq \'.app[0]\''
                SUBNET_APP_B        = sh 'terraform output -json subnets | jq \'.app[1]\''
                SUBNET_APP_C        = sh 'terraform output -json subnets | jq \'.app[2]\''
                SUBNET_DATABASE_A   = sh 'terraform output -json subnets | jq \'.data[0]\''
                SUBNET_DATABASE_B   = sh 'terraform output -json subnets | jq \'.data[1]\''
                SUBNET_DATABASE_C   = sh 'terraform output -json subnets | jq \'.data[2]\''
                    // Start HERE
                    // Create service account (same permissions  as admin) for Aurora DBs
                    // Create launch configuration - yum install -y nfs-utils
                    // Create EKS cluster
                    // Update cloudfront
                    // Update imperva
            }

            stage('Apply kubernetes configration') {
                stage('Apply kubeconfig') {
                                // Export terraform output and save to ~/.kube/config file. This is required to access EKS Cluster
                                echo "Applying kubeconfig"
                                sh 'terraform output kubeconfig > ~/.kube/config'
                                echo "kubeconfig applied successfully"
                }
                stage('Apply kubernetes configmap aws-auth') {
                    echo "Saving config_map_aws_auth to config_map_aws_auth.yml"
                    sh 'terraform output config_map_aws_auth > config_map_aws_auth.yml'
                    echo "config_map_aws_auth.yml saved.\nUpdating configmap aws-auth"
                    sh 'kubectl apply -f config_map_aws_auth.yml'
                    echo "Config map updated successfully"
                }
            }
            stage("Show kubernetes cluster") {
                echo "Kubernetes contexts:"
                sh 'kubectl config get-contexts'
                echo "Kubernetes elements"
                sh 'kubectl get all --all-namespaces'
            }
            stage ('Deploy Loadbalancers') {
                node('dind') {
                    git branch: 'develop', credentialsId: 'aws-416-bitbucket', url: 'git@bitbucket.org:outware/lifeblood.git'
                    sh "sed 's/SECURITY_GROUP_ID/TEST/g' loadbalancer-dev-blue.yaml > newtest.yaml"
                    // YAML = readYaml text:"loadbalancer-dev-blue.yaml"
                    // "YAML.metadata.annotations.service.beta.kubernetes.io/aws-load-balancer-extra-security-groups" = "TEST"
                    // writeYaml file: newtest.yaml, data: YAML
                    sh 'echo ========= FILE contents ==============='
                    sh 'cat newtest.yaml'
                    stage("Loadbalancer - Dev") {

                    }
                    stage("Loadbalancer - Staging") {
                    }
                }
            }
            stage('Setup Cloudfront') {
                stage('Cloudfront - Dev') {
                }
                stage('Cloudfront - Staging') {
                }
            }
        }
    }
    ***************/ 
} catch (Exception ex) {
    currentBuild.result = "FAILURE"
    echo "Failure in build. Aborting."
    throw ex
} catch (Error er) {
    currentBuild.result = "FAILURE"
    echo "Failure in build. Aborting."
    throw er
} finally {
    notifySlack(currentBuild.result)
}
