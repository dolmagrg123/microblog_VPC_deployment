# Kura Labs Cohort 5- Deployment Workload 4

- [PURPOSE](#purpose)
- [STEPS And Why each was Necessary](#the-steps-taken-and-why-each-was-necessaryimportant)
- [SYSTEM DESIGN DIAGRAM](#system-design-diagram)
- [ISSUES and TROUBLESHOOTING](#issuestroubleshooting)
- [OPTIMIZATION](#optimization)
- [CONCLUSION](#conclusion)

---

### PURPOSE

The purpose of this workload is to deploy an application, making sure that the application server, which has the application code is secure in the private subnet and our webserver is publicly accessible. Also we use Jenkins to automate the deployment process. Finally we use Prometheus and Grafana to ensure monitoring of our application.

## Provisioning Server Infrastructure:

### The "STEPS" taken (and why each was necessary/important)

1. Clone this repo to your GitHub account. IMPORTANT: Make sure that the repository name is "microblog_VPC_deployment"

2. In the AWS console, create a custom VPC with one availability zome, a public and a private subnet.  There should be a NAT Gateway in 1 AZ and no VPC endpoints.  DNS hostnames and DNS resolution should be selected.

![VPC_Setup](Images/VPC_setup.jpg)

3. Navigate to subnets and edit the settings of the public subet you created to auto assign public IPv4 addresses.

4. In the Default VPC, create an EC2 t3.medium called "Jenkins" and install Jenkins onto it.
![instance_launch](Images/t3_medium.jpg)
![Jenkins_EC2](Images/Jenkins_EC2.jpg)

5. Create an EC2 t3.micro called "Web_Server" In the PUBLIC SUBNET of the Custom VPC, and create a security group with ports 22 and 80 open.  

6. Create an EC2 t3.micro called "Application_Server" in the PRIVATE SUBNET of the Custom VPC,  and create a security group with ports 22 and 5000 open. Make sure you create and save the key pair to your local machine.

7. SSH into the "Jenkins" server and run `ssh-keygen`. Copy the public key that was created and append it into the "authorized_keys" file in the Web Server. 

IMPORTANT: Test the connection by SSH'ing into the 'Web_Server' from the 'Jenkins' server.  This will also add the web server instance to the "list of known hosts"

#### This did not work as the two servers were in different VPCs. To resolve this issue we created VPC peering between our two VPC and then we were able to SSH into our webserver through our Jenkins Server

Question: What does it mean to be a known host?

#### To be a known hosts the remote system's public key has to be stored in the local hosts ~/.ssh/known_hosts file. This allows the servers to connect in the future and forms a trust with the server.

8. In the Web Server, install NginX and modify the "sites-enabled/default" file so that the "location" section reads as below:
```
location / {
proxy_pass http://<private_IP>:5000;
proxy_set_header Host $host;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```
IMPORTANT: Be sure to replace `<private_IP>` with the private IP address of the application server. Run the command `sudo nginx -t` to verify. Restart NginX afterward.

This step allowed nginx to run the gunicorn application from the application_server in the public ip of web_server by passing the private ip of application server.

9. Copy the key pair (.pem file) of the "Application_Server" to the "Web_Server".  How you choose to do this is up to you.  (Best practice would be to SCP from your local machine into the Jenkins server but if not, it is possible to nano a new file and copy/paste the contents of the .pem file into it.  MAKE SURE TO INCLUDE EVERYTHING FROM -----BEGIN RSA PRIVATE KEY----- to -----END RSA PRIVATE KEY----- including a new line afterwards if you chose this route)

IMPORTANT: Test the connection by SSH'ing into the "Application_Server" from the "Web_Server".

#### We used the copy/paste into .pem file method to add the key into my server and was able to ssh into application server via the webserver.

10. Create scripts.  2 scripts are required for this Workload and outlined below:

a) a "start_app.sh" script that will run on the application server that will set up the server so that has all of the dependencies that the application needs, clone the GH repository, install the application dependencies from the requirements.txt file as well as [gunicorn, pymysql, cryptography], set ENVIRONMENTAL Variables, flask commands, and finally the gunicorn command that will serve the application IN THE BACKGROUND

```
#! /bin/bash

sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install -y python3.9 python3.9-venv python3-pip nginx git
# Clone the GitHub repository if it doesn't already exist
#if the repo does not exist we will clone it.
if [ ! -d "microblog_VPC_deployment" ]; then
  git clone https://github.com/dolmagrg123/microblog_VPC_deployment.git
fi
cd microblog_VPC_deployment
#pull the latest code in case we already have the repo present(common after first successful build)
git pull
python3.9 -m venv venv
echo "Activating vitual env"
source venv/bin/activate
echo "Installing Requirements of the application"
pip install -r requirements.txt
pip install gunicorn pymysql cryptography
export FLASK_APP=microblog.py
flask translate compile
flask db upgrade
echo "Starting Gunicorn..."
gunicorn -b :5000 -w 4 microblog:app --daemon

```

b) a "setup.sh" script that will run in the "Web_Server" that will SSH into the "Application_Server" to run the "start_app.sh" script.

```
#! /bin/bash

APPLICATION_SERVER_IP=$1

# Set permissions for the SSH key
chmod 400 workload_4.pem

# SSH into the application server and run start_app.sh
echo "logging into application server and running start_app script"
#ssh into the application server, pull the script from GitHub and run the script
ssh -i "workload_4.pem" ubuntu@${APPLICATION_SERVER_IP} "curl -o ~/start_app.sh https://raw.githubusercontent.com/dolmagrg123/microblog_VPC_deployment/refs/heads/main/scripts/start_app.sh && bash ~/start_app.sh"

#checks if exit status is not equal to 0, since a non zero value indicates failure.
if [ $? -ne 0 ]; then
    echo "Failed to execute start_app.sh on ${APPLICATION_SERVER_IP}"
    exit 1
fi

```

(HINT: run the scripts with "source" to avoid issues)

Question: What is the difference between running scripts with the source command and running the scripts either by changing the permissions or by using the 'bash' interpreter?

#### We ran it by changing the permissions to allow the script to be executable. Running with source would allow the script to be executed in current sheel vs changing permissions runs the script ina new subshell.

![script_output](Images/gunicorn_running_terminal.jpg)
![script_output](Images/manual_script_run.jpg)

11. Create a Jenkinsfile that will 'Build' the application, 'Test' the application by running a pytest, run the OWASP dependency checker, and then "Deploy" the application by SSH'ing into the "Web_Server" to run "setup.sh" (which would then run "start_app.sh").

IMPORTANT/QUESTION/HINT: How do you get the scripts onto their respective servers if they are saved in the GitHub Repo?  Do you SECURE COPY the file from one server to the next in the pipeline? Do you C-opy URL the file first as a setup? How much of this process is manual vs. automated?

#### We added curl command to download the scripts from the GitHub repo directly in the Jenkinsfile and the script. So it was all automated with the pipeline.

Question 2: In WL3, a method of "keeping the process alive" after a Jenkins stage completed was necessary.  Is it in this Workload? Why or why not?

#### It is not necessary in this workload as we are running a script through the jenkins pipeline and the script runs the process. So the process does not keep the jenkins pipeline hanging and allows to successfully end the pipeline when the script is ran"

12. Create a MultiBranch Pipeline and run the build. IMPORTANT: Make sure the name of the pipeline is: "workload_4". 

We added credentials in Jenkins Global credential and also installed plugins for ssh-agent and OWASP.

![Jenkins Pipeline](Images/final_pipeline.jpg)

![Jenkins Pipeline](Images/final_pipeline_console.jpg)



### Application accessed from the public IP address of the Web_Server


![Application](Images/application_up_public_ip.jpg)

13. If all is well, create an EC2 t3.micro called "Monitoring" with Prometheus and Grafana and configure it so that it can collect metrics on the application server.

![Prometheus](Images/prometheus_dashboard.jpg)

![Grafana](Images/grafana_dashboard.jpg)


### "SYSTEM DESIGN DIAGRAM"
![Solution](Diagram.jpg)

### "ISSUES/TROUBLESHOOTING"

To install python we needed some additional installations. Had to add it in our script as well to make sure it is installed during our Jenkins pipeline first run.

```
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
```
![Error](Images/python_jenkins_error.jpg)
![Solution](Images/python_install_solution.jpg)

To avoid putting private IPs in code, we added it to Jenkins credentials but were unable to read the private and public ip that were added in the Jenkins credentials. Had to make sure to use {}

```
        WEB_SERVER_IP = "${env.WEB_SERVER_IP}" // Access the environment variable
        APPLICATION_SERVER_IP = "${env.APPLICATION_SERVER_IP}" // Access the application server IP
```
![error](Images/env_jenkins_error.jpg)

During the scan stage, if we do not install the plugin for OWASP Dependency-Check, it fails.

![error](Images/jenkins_DP_CHECK_error.jpg)

Even though we were able to manually ssh from webserver to application server, we were unable to do the same through Jenkins pipeline. To resolve this issue, we added the private key credentials into the Jenkins Global configuration and also installed ssh-agent plugin.

![error](Images/deploy_host_verification_error.jpg)

When trying to use scp to copy our script the pipeline got stuck, so we ended up using curl to download the script instead.

![error](Images/scp_pipeline_stuck_issue.jpg)

### "OPTIMIZATION"

 What are the advantages of separating the deployment environment from the production environment?  Does the infrastructure in this workload address these concerns?  Could the infrastructure created in this workload be considered that of a "good system"?  Why or why not?  How would you optimize this infrastructure to address these issues?


 The main advantage of separating deployment and production environment could be the security aspect, rollback capabilities and better testing environment. Keeping our code in private subnet minimizes the risk of the code being exposed and altered. In our infrastructure we do have different servers for web server and application server but we still do not seem to have a separate production environment. Having a separate deployment/production environment allows testing before we push our code in the production environment. Any issues occurred during development process will not effect the production.

 Our system does not have autoscaling capabilities as we have not enabled autoscaling. Once we have autoscalers, we can also use load balancers to separate the load between different servers. We could add more monitoring and create alarms based on the alerts to notify engineers if any issues arise.


### "CONCLUSION"

This workload was successfully able to segregate our web server and application server by putting them in public and private subnets respectively. We were able to make use VPC to connect multiple VPCs and deploy our application using the Jenkins CI/CD pipeline which help reduce a lot of manual work making our deployment more efficient.
