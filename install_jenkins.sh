#!/bin/bash
echo "=============================="
echo " Jenkins Auto-Install Script"
echo " Amazon Linux 2 + Java 21"
echo "=============================="

# Step 1: Update system
echo "[1/9] Updating system..."
sudo yum update -y

# Step 2: Install Java 21 (Amazon Corretto)
echo "[2/9] Installing Java 21 (Amazon Corretto)..."
sudo yum install -y https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.rpm
java -version

# Step 3: Add Jenkins repo
echo "[3/9] Adding Jenkins repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Step 4: Install Jenkins
echo "[4/9] Installing Jenkins..."
sudo yum install jenkins -y

# Step 5: Install fontconfig (prevents startup issues)
echo "[5/9] Installing fontconfig..."
sudo yum install fontconfig -y

# Step 6: Install Git
echo "[6/9] Installing Git..."
sudo yum install git -y
git --version

# Step 7: Install Maven
echo "[7/9] Installing Maven..."
sudo wget -O /etc/yum.repos.d/epel-apache-maven.repo \
  https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo
sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven
mvn -version

# Step 8: Open port 8080 in firewall
echo "[8/9] Opening port 8080..."
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# Step 9: Start and enable Jenkins
echo "[9/9] Starting Jenkins..."
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to fully start
echo ""
echo "Waiting 90 seconds for Jenkins to fully start..."
sleep 90

# Print result
PUBLIC_IP=$(curl -s ifconfig.me)
echo ""
echo "=============================="
echo " Jenkins Installation Complete!"
echo " URL: http://$PUBLIC_IP:8080"
echo " Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "=============================="
echo " Git version: $(git --version)"
echo " Maven version: $(mvn -version | head -n 1)"
echo "=============================="
echo " NOTE: Also open port 8080 in your AWS Security Group!"
echo "=============================="
