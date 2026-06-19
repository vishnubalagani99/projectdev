#!/bin/bash
echo "=============================================="
echo " Jenkins / Tomcat Auto-Install Script"
echo " Amazon Linux 2 + Java 21"
echo "=============================================="
echo ""
echo "What do you want to install?"
echo "  1 - Jenkins only"
echo "  2 - Jenkins + Tomcat (port 8081)"
read -p "Enter your choice (1 or 2, default 1): " INSTALL_CHOICE
INSTALL_CHOICE=${INSTALL_CHOICE:-1}

if [[ "$INSTALL_CHOICE" != "1" && "$INSTALL_CHOICE" != "2" ]]; then
    echo "Invalid choice. Defaulting to Jenkins only."
    INSTALL_CHOICE=1
fi

if [ "$INSTALL_CHOICE" == "2" ]; then
    echo "Selected: Jenkins + Tomcat"
else
    echo "Selected: Jenkins only"
fi

# Step 1: Update system
echo ""
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
sudo yum install -y maven
mvn -version

# Step 8 (conditional): Install and configure Tomcat 11
TOMCAT_PORT="8081"
if [ "$INSTALL_CHOICE" == "2" ]; then
    echo "[8/9] Installing Apache Tomcat 11..."
    TOMCAT_MAJOR="11"
    TOMCAT_VERSION="11.0.22"
    TOMCAT_USER="tomcat"
    TOMCAT_HOME="/opt/tomcat"

    if ! id "$TOMCAT_USER" &>/dev/null; then
        sudo useradd -m -d "$TOMCAT_HOME" -U -s /bin/false "$TOMCAT_USER"
    fi

    cd /tmp
    TOMCAT_TARBALL="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
    TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/${TOMCAT_TARBALL}"
    TOMCAT_URL_FALLBACK="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/${TOMCAT_TARBALL}"

    echo "Downloading Tomcat ${TOMCAT_VERSION}..."
    sudo wget -O "$TOMCAT_TARBALL" "$TOMCAT_URL" || sudo wget -O "$TOMCAT_TARBALL" "$TOMCAT_URL_FALLBACK"

    sudo mkdir -p "$TOMCAT_HOME"
    sudo tar xzf "$TOMCAT_TARBALL" -C "$TOMCAT_HOME" --strip-components=1
    sudo chown -R "$TOMCAT_USER":"$TOMCAT_USER" "$TOMCAT_HOME"
    sudo chmod +x "$TOMCAT_HOME"/bin/*.sh

    echo "Configuring Tomcat to run on port ${TOMCAT_PORT}..."
    sudo sed -i "s/port=\"8080\"/port=\"${TOMCAT_PORT}\"/" "$TOMCAT_HOME/conf/server.xml"

    echo "Creating systemd service for Tomcat..."
    JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))

    sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat ${TOMCAT_VERSION}
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=${JAVA_HOME_PATH}
Environment=CATALINA_PID=${TOMCAT_HOME}/temp/tomcat.pid
Environment=CATALINA_HOME=${TOMCAT_HOME}
Environment=CATALINA_BASE=${TOMCAT_HOME}
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true'

ExecStart=${TOMCAT_HOME}/bin/startup.sh
ExecStop=${TOMCAT_HOME}/bin/shutdown.sh

User=${TOMCAT_USER}
Group=${TOMCAT_USER}
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
else
    echo "[8/9] Skipping Tomcat installation (Jenkins only selected)."
fi

# Step 9: Open ports, start and enable services
echo "[9/9] Opening firewall ports and starting services..."
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT

sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins

if [ "$INSTALL_CHOICE" == "2" ]; then
    sudo iptables -I INPUT -p tcp --dport "${TOMCAT_PORT}" -j ACCEPT
    sudo systemctl start tomcat
    sudo systemctl enable tomcat
fi

# Wait for services to fully start
echo ""
echo "Waiting 90 seconds for services to fully start..."
sleep 90

# Print result
PUBLIC_IP=$(curl -s ifconfig.me)
echo ""
echo "=============================================="
echo " Installation Complete!"
echo "=============================================="
echo " Jenkins URL : http://$PUBLIC_IP:8080"
echo " Jenkins Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

if [ "$INSTALL_CHOICE" == "2" ]; then
    echo "----------------------------------------------"
    echo " Tomcat URL  : http://$PUBLIC_IP:${TOMCAT_PORT}"
    echo " Tomcat Status: $(sudo systemctl is-active tomcat)"
fi

echo "=============================================="
echo " Git version  : $(git --version)"
echo " Maven version: $(mvn -version | head -n 1)"
echo "=============================================="
echo " NOTE:"
echo " - Jenkins -> IP: $PUBLIC_IP   PORT: 8080"
if [ "$INSTALL_CHOICE" == "2" ]; then
    echo " - Tomcat  -> IP: $PUBLIC_IP   PORT: ${TOMCAT_PORT}"
    echo " - Open ports 8080 AND ${TOMCAT_PORT} in your AWS Security Group inbound rules!"
else
    echo " - Open port 8080 in your AWS Security Group inbound rules!"
fi
echo "=============================================="
