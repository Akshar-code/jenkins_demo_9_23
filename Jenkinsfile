pipeline {
    agent any
    
    environment {
        QUAY_REPO = "quay.io/rh-ee-akottuva/jenkins-testing-9-23"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        COSIGN_URL = "https://cli-server-trusted-artifact-signer.apps.cluster-t55vs.t55vs.sandbox1621.opentlc.com/clients/linux/cosign-amd64.gz"
    }
    
    stages {
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${QUAY_REPO}:${IMAGE_TAG}")
                }
            }
        }

        stage('Login to Quay.io') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'quay-credentials', usernameVariable: 'QUAY_USER', passwordVariable: 'QUAY_PASS')]) {
                        sh "echo \$QUAY_PASS | docker login quay.io -u \$QUAY_USER --password-stdin"
                    }
                }
            }
        }

        stage('Push to Quay.io') {
            steps {
                sh "docker push ${QUAY_REPO}:${IMAGE_TAG}"
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

        stage('Sign Docker Image') {
            steps {
                script {
                    withCredentials([
                        file(credentialsId: 'cosign-private-key', variable: 'COSIGN_PRIVATE_KEY'),
                        string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
                    ]) {
                        sh """
                            echo "Getting image digest..."
                            IMAGE_DIGEST=\$(docker inspect --format='{{index .RepoDigests 0}}' ${QUAY_REPO}:${IMAGE_TAG})
                            echo "Image digest: \$IMAGE_DIGEST"

                            echo "Signing the image..."
                            echo \$COSIGN_PASSWORD | ./cosign sign --key \$COSIGN_PRIVATE_KEY --tlog-upload=false \$IMAGE_DIGEST
                        """
                    }
                }
            }
        }

        stage('Verify Signature') {
    steps {
        script {
            withCredentials([file(credentialsId: 'cosign-public-key', variable: 'COSIGN_PUBLIC_KEY')]) {
                        sh """
                            echo "Getting image digest..."
                            IMAGE_DIGEST=\$(docker inspect --format='{{index .RepoDigests 0}}' ${QUAY_REPO}:${IMAGE_TAG})
                            echo "Image digest: \$IMAGE_DIGEST"

                            echo "Verifying the signature..."
                            ./cosign verify --key \$COSIGN_PUBLIC_KEY --insecure-ignore-tlog=true \$IMAGE_DIGEST

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
    }
    
    post {
        always {
            sh "docker logout quay.io"
            sh "rm -f cosign cosign.gz"
        }
    }
}
