#! /bin/bash

# Check if the application server IP is provided
APPLICATION_SERVER_IP=$1
if [ -z "$APPLICATION_SERVER_IP" ]; then
    echo "Usage: $0 <APPLICATION_SERVER_IP>"
    exit 1
fi

# Set permissions for the SSH key
chmod 400 workload_4.pem

# SSH into the application server and run start_app.sh
ssh -i "workload_4.pem" ubuntu@${APPLICATION_SERVER_IP} 'bash ~/start_app.sh'
if [ $? -ne 0 ]; then
    echo "Failed to execute start_app.sh on ${APPLICATION_SERVER_IP}"
    exit 1
fi
