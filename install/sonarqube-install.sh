#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y unzip
$STD apt-get install -y postgresql
$STD apt-get install -y postgresql-contrib
msg_ok "Installed Dependencies"

msg_info "Installing Java 17"
$STD apt-get install -y openjdk-17-jdk
msg_ok "Installed Java 17"

msg_info "Setting up PostgreSQL"
$STD systemctl start postgresql
$STD su - postgres -c "createuser sonarqube"
$STD su - postgres -c "createdb -O sonarqube sonarqube"
$STD su - postgres -c "psql -c \"ALTER USER sonarqube WITH ENCRYPTED password 'sonarqube';\""
msg_ok "Set up PostgreSQL"

msg_info "Installing SonarQube"
RELEASE=$(curl -s https://api.github.com/repos/SonarSource/sonarqube/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
VERSION=${RELEASE#*v}

cd /opt
wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${VERSION}.zip
unzip -q sonarqube-${VERSION}.zip
mv sonarqube-${VERSION} sonarqube
rm sonarqube-${VERSION}.zip

# Create sonarqube user
useradd -r -M -d /opt/sonarqube -s /sbin/nologin sonarqube
chown -R sonarqube:sonarqube /opt/sonarqube
echo "${RELEASE}" >/opt/${APPLICATION}_version.txt

msg_info "Configuring System Limits"
# Add security limits only
cat > /etc/security/limits.d/99-sonarqube.conf << EOF || msg_error "Failed to create limits file"
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOF
msg_ok "Configured System Limits"

msg_info "Creating Host System Configuration Instructions"
cat > /root/sonarqube-host-setup.txt << EOF
### Important: SonarQube Host System Requirements ###
Please add the following settings to your Proxmox host's /etc/sysctl.conf:

vm.max_map_count=262144
fs.file-max=65536

Then run: sysctl -p

These settings are required for SonarQube to function properly.
EOF
msg_info "Host system configuration instructions saved to /root/sonarqube-host-setup.txt"

msg_info "Configuring SonarQube"
cat <<EOF >/opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonarqube
sonar.jdbc.password=sonarqube
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError
EOF

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target postgresql.service

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sonarqube
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
