#! /bin/bash

APPLICATION_SERVER_IP=$1

# Set permissions for the SSH key
chmod 400 workload_4.pem

# SSH into the application server and run start_app.sh
ssh -i "workload_4.pem" ubuntu@${APPLICATION_SERVER_IP} 'curl -o https://github.com/dolmagrg123/microblog_VPC_deployment/blob/main/scripts/start_app.sh && bash ~/start_app.sh'
if [ $? -ne 0 ]; then
    echo "Failed to execute start_app.sh on ${APPLICATION_SERVER_IP}"
    exit 1
fi
