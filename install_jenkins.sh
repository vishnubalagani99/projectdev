#!/bin/bash

echo "=============================="
echo " Jenkins Auto-Install Script"
echo " Amazon Linux 2 + Java 21"
echo "=============================="

# Step 1: Update system
echo "[1/7] Updating system..."
sudo yum update -y

# Step 2: Install Java 21 (Amazon Corretto)
echo "[2/7] Installing Java 21 (Amazon Corretto)..."
sudo yum install -y https://corretto.aws/downloads/latest/amazon-corretto-21-x64-linux-jdk.rpm
java -version

# Step 3: Add Jenkins repo
echo "[3/7] Adding Jenkins repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Step 4: Install Jenkins
echo "[4/7] Installing Jenkins..."
sudo yum install jenkins -y

# Step 5: Install fontconfig (prevents startup issues)
echo "[5/7] Installing fontconfig..."
sudo yum install fontconfig -y

# Step 6: Open port 8080 in firewall
echo "[6/7] Opening port 8080..."
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# Step 7: Start and enable Jenkins
echo "[7/7] Starting Jenkins..."
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
echo " NOTE: Also open port 8080 in your AWS Security Group!"
echo "=============================="
