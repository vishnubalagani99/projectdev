#!/bin/bash
echo "=============================="
echo " Jenkins Auto-Install Script"
echo " Amazon Linux 2 + Java 21"
echo "=============================="

set -e  # Exit on any error

# Step 1: Update system
echo "[1/9] Updating system..."
sudo yum update -y

# Step 2: Add Corretto repo and Install Java 21
echo "[2/9] Installing Java 21 (Amazon Corretto)..."
sudo rpm --import https://yum.corretto.aws/corretto.key
sudo curl -Lo /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
sudo yum install -y java-21-amazon-corretto-devel

# Force Java 21 as default
sudo alternatives --set java /usr/lib/jvm/java-21-amazon-corretto.x86_64/bin/java 2>/dev/null || true
sudo alternatives --set javac /usr/lib/jvm/java-21-amazon-corretto.x86_64/bin/javac 2>/dev/null || true
echo "JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto" | sudo tee -a /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto
export PATH=$JAVA_HOME/bin:$PATH
java -version

# Step 3: Add Jenkins repo
echo "[3/9] Adding Jenkins repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
  https://pkg.jenkins.io/rpm-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Step 4: Install Jenkins (exclude any auto JDK pull-in)
echo "[4/9] Installing Jenkins..."
sudo yum install jenkins -y --exclude=java*openjdk*

# Step 5: Point Jenkins to Java 21 explicitly
echo "[5/9] Configuring Jenkins to use Java 21..."
sudo mkdir -p /etc/systemd/system/jenkins.service.d
cat <<OVERRIDE | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
Environment="JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto"
Environment="PATH=/usr/lib/jvm/java-21-amazon-corretto/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
OVERRIDE

# Step 6: Install fontconfig (prevents startup issues)
echo "[6/9] Installing fontconfig..."
sudo yum install fontconfig -y

# Step 7: Install Git
echo "[7/9] Installing Git..."
sudo yum install git -y
git --version

# Step 8: Install Maven
echo "[8/9] Installing Maven..."
sudo wget -O /etc/yum.repos.d/epel-apache-maven.repo \
  https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo
sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
sudo yum install -y apache-maven
mvn -version

# Step 9: Open port 8080 in firewall
echo "[9/9] Opening port 8080..."
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

# Start and enable Jenkins
echo "Starting Jenkins..."
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to fully start
echo ""
echo "Waiting 90 seconds for Jenkins to fully start..."
sleep 90

# Print result
PUBLIC_IP=$(curl -s ifconfig.me)
ADMIN_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not ready yet — run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword")

echo ""
echo "=============================="
echo " Jenkins Installation Complete!"
echo " URL: http://$PUBLIC_IP:8080"
echo " Admin Password: $ADMIN_PASS"
echo "=============================="
echo " Java version:  $(java -version 2>&1 | head -n 1)"
echo " Git version:   $(git --version)"
echo " Maven version: $(mvn -version 2>&1 | head -n 1)"
echo "=============================="
echo " NOTE: Also open port 8080 in your AWS Security Group!"
echo "=============================="
