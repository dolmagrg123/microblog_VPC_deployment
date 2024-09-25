pipeline {
  agent any

    environment {
        WEB_SERVER_IP = "${env.WEB_SERVER_IP}" // Access the environment variable
        APPLICATION_SERVER_IP = "${env.APPLICATION_SERVER_IP}" // Access the application server IP
        SSH_KEY = credentials('my-ssh-key')
    }

    stages {
        stage ('Build') {
            steps {
                sh '''#!/bin/bash
                
                python3.9 -m venv venv
                source venv/bin/activate
                pip install pip --upgrade
                pip install -r requirements.txt
                '''
            }
        }
        stage ('Test') {
            steps {
                sh '''#!/bin/bash
                source venv/bin/activate
                py.test ./tests/unit/ --verbose --junit-xml test-reports/results.xml
                '''
            }
            post {
                always {
                    junit 'test-reports/results.xml'
                }
            }
        }
      stage ('OWASP FS SCAN') {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
                
            }
        }
      stage ('Clean') {
            steps {
                sh '''#!/bin/bash
                if [[ $(ps aux | grep -i "gunicorn" | tr -s " " | head -n 1 | cut -d " " -f 2) != 0 ]]
                then
                ps aux | grep -i "gunicorn" | tr -s " " | head -n 1 | cut -d " " -f 2 > pid.txt
                kill $(cat pid.txt)
                exit 0
                fi
                '''
            }
        }
        stage('Deploy') {
            // steps {
            //     // sh 'sudo systemctl restart microblog'
            //     sh '''#!/bin/bash
            //     echo "${SSH_KEY}"
            //     echo "reached here"
            //     scp -i "${SSH_KEY}" scripts/setup.sh ubuntu@${WEB_SERVER_IP}:~/
            //     scp -i "${SSH_KEY}" scripts/start_app.sh ubuntu@${APPLICATION_SERVER_IP}:~/
            //     ssh -i "${SSH_KEY}" ubuntu@${WEB_SERVER_IP} "bash ~/setup.sh ${APPLICATION_SERVER_IP}"
            //     '''

            // }
            steps {
                    sshagent(credentials: ['my-ssh-key']) {
                    sh '''
                        [ -d ~/.ssh ] || mkdir ~/.ssh && chmod 0700 ~/.ssh
                        ssh-keyscan -t rsa,dsa ${WEB_SERVER_IP} >> ~/.ssh/known_hosts
                        scp -o StrictHostKeyChecking=no scripts/setup.sh ubuntu@${WEB_SERVER_IP}:~/
                        scp -o StrictHostKeyChecking=no scripts/start_app.sh ubuntu@${APPLICATION_SERVER_IP}:~/
                        ssh ubuntu@${WEB_SERVER_IP} "bash ~/setup.sh ${APPLICATION_SERVER_IP}"
                    '''
    }
}
        }

        }
}

    

