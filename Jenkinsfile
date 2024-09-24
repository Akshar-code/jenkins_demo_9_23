pipeline {
    agent any
    
    environment {
        QUAY_REPO = "quay.io/rh-ee-akottuva/jenkins-testing-9-23"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        COSIGN_URL = "https://cli-server-trusted-artifact-signer.apps.cluster-t55vs.t55vs.sandbox1621.opentlc.com/clients/linux/cosign-amd64.gz"
    }
    
    stages {
        stage('Build Container Image') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject() {
                            def buildConfig = openshift.selector("bc", "jenkins-testing-9-23")
                            if (!buildConfig.exists()) {
                                openshift.newBuild("--name=jenkins-testing-9-23", "--docker-image=quay.io/buildah/stable:latest", "--binary=true")
                            }
                            openshift.startBuild("jenkins-testing-9-23", "--from-dir=.")
                        }
                    }
                }
            }
        }

        stage('Push to Quay.io') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject() {
                            def is = openshift.selector("is", "jenkins-testing-9-23").object()
                            def imageReference = is.status.dockerImageRepository + ":" + IMAGE_TAG
                            openshift.tag(imageReference, "${QUAY_REPO}:${IMAGE_TAG}")
                        }
                    }
                }
            }
        }
        
        stage('Download and Setup Cosign') {
            steps {
                sh """
                    curl -L ${COSIGN_URL} -o cosign.gz
                    gunzip cosign.gz
                    chmod +x cosign
                    ./cosign version
                """
            }
        }

        stage('Sign Container Image') {
            steps {
                withCredentials([
                    file(credentialsId: 'cosign-private-key', variable: 'COSIGN_PRIVATE_KEY'),
                    string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
                ]) {
                    sh """
                        echo "Signing the image..."
                        echo \$COSIGN_PASSWORD | ./cosign sign --key \$COSIGN_PRIVATE_KEY --tlog-upload=false ${QUAY_REPO}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Verify Signature') {
            steps {
                withCredentials([file(credentialsId: 'cosign-public-key', variable: 'COSIGN_PUBLIC_KEY')]) {
                    sh """
                        echo "Verifying the signature..."
                        ./cosign verify --key \$COSIGN_PUBLIC_KEY --insecure-ignore-tlog=true ${QUAY_REPO}:${IMAGE_TAG}

                        if [ \$? -eq 0 ]; then
                            echo "Signature verification successful!"
                        else
                            echo "Signature verification failed!"
                            exit 1
                        fi
                    """
                }
            }
        }
    }
    
    post {
        always {
            sh "rm -f cosign cosign.gz"
        }
    }
}
