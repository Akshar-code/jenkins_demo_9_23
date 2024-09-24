pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                metadata:
                  labels:
                    some-label: some-label-value
                spec:
                  containers:
                  - name: podman
                    image: image-registry.openshift-image-registry.svc:5000/openshift/jenkins-agent-base:latest
                    command:
                    - cat
                    tty: true
            '''
        }
    }
    
    environment {
        QUAY_REPO = "quay.io/rh-ee-akottuva/jenkins-testing-9-23"
        IMAGE_TAG = "v${BUILD_NUMBER}"
        COSIGN_URL = "https://cli-server-trusted-artifact-signer.apps.cluster-t55vs.t55vs.sandbox1621.opentlc.com/clients/linux/cosign-amd64.gz"
    }
    
    stages {
        stage('Build Container Image') {
            steps {
                container('podman') {
                    sh "podman build -t ${QUAY_REPO}:${IMAGE_TAG} ."
                }
            }
        }

        stage('Login to Quay.io') {
            steps {
                container('podman') {
                    withCredentials([usernamePassword(credentialsId: 'quay-credentials', usernameVariable: 'QUAY_USER', passwordVariable: 'QUAY_PASS')]) {
                        sh "echo \$QUAY_PASS | podman login quay.io -u \$QUAY_USER --password-stdin"
                    }
                }
            }
        }

        stage('Push to Quay.io') {
            steps {
                container('podman') {
                    sh "podman push ${QUAY_REPO}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Download and Setup Cosign') {
            steps {
                container('podman') {
                    sh """
                        curl -L ${COSIGN_URL} -o cosign.gz
                        gunzip cosign.gz
                        chmod +x cosign
                        ./cosign version
                    """
                }
            }
        }

        stage('Sign Container Image') {
            steps {
                container('podman') {
                    withCredentials([
                        file(credentialsId: 'cosign-private-key', variable: 'COSIGN_PRIVATE_KEY'),
                        string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD')
                    ]) {
                        sh """
                            echo "Getting image digest..."
                            IMAGE_DIGEST=\$(podman inspect --format='{{index .RepoDigests 0}}' ${QUAY_REPO}:${IMAGE_TAG})
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
                container('podman') {
                    withCredentials([file(credentialsId: 'cosign-public-key', variable: 'COSIGN_PUBLIC_KEY')]) {
                        sh """
                            echo "Getting image digest..."
                            IMAGE_DIGEST=\$(podman inspect --format='{{index .RepoDigests 0}}' ${QUAY_REPO}:${IMAGE_TAG})
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
        node {
            container('podman') {
                sh "podman logout quay.io"
            }
            sh "rm -f cosign cosign.gz"
        }
    }
}
