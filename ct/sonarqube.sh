#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tyty-the-eyety/ProxmoxVE/dev/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
   _____                         ____        __          
  / ___/____  ____  ____ ______/ __ \__  __/ /_  ___   
  \__ \/ __ \/ __ \/ __ `/ ___/ / / / / / / __ \/ _ \  
 ___/ / /_/ / / / / /_/ / /  / /_/ / /_/ / /_/ /  __/  
/____/\____/_/ /_/\__,_/_/   \___\_\__,_/_.___/\___/   
                                                      
EOF
}
header_info
echo -e "Loading..."
APP="SonarQube"
var_disk="8"
var_cpu="2"
var_ram="4096"
var_os="debian"
var_version="12"
variables
color
catch_errors

msg_info "Host System Requirements"
cat << EOF
SonarQube requires the following settings on the Proxmox host:
vm.max_map_count=262144
fs.file-max=65536

These will be configured during installation.
EOF
msg_ok "Checked host requirements"

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="yes"
  echo_default
}

function update_script() {
header_info
check_container_storage
check_container_resources
if [[ ! -d /opt/sonarqube ]]; then msg_error "No ${APP} Installation Found!"; exit; fi

msg_info "Stopping ${APP}"
systemctl stop sonarqube
msg_ok "Stopped ${APP}"

CURRENT_VERSION=$(cat /opt/${APP}_version.txt)
LATEST_VERSION=$(curl -s https://api.github.com/repos/SonarSource/sonarqube/releases/latest | grep '"tag_name":' | cut -d'"' -f4)

if [[ "${LATEST_VERSION}" != "${CURRENT_VERSION}" ]]; then
  msg_info "Updating ${APP} to ${LATEST_VERSION}"
  
  msg_info "Backing up configuration"
  cp -R /opt/sonarqube/conf /root/sonarqube_conf_backup
  msg_ok "Backed up configuration"
  
  cd /opt
  wget -q https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${LATEST_VERSION#*v}.zip
  unzip -q sonarqube-${LATEST_VERSION#*v}.zip
  rm sonarqube-${LATEST_VERSION#*v}.zip
  rm -rf /opt/sonarqube
  mv sonarqube-${LATEST_VERSION#*v} sonarqube
  
  msg_info "Restoring configuration"
  cp -R /root/sonarqube_conf_backup/* /opt/sonarqube/conf/
  rm -rf /root/sonarqube_conf_backup
  msg_ok "Restored configuration"
  
  chown -R sonarqube:sonarqube /opt/sonarqube
  echo "${LATEST_VERSION}" > /opt/${APP}_version.txt
  msg_ok "Updated ${APP} to ${LATEST_VERSION}"
  
  msg_info "Starting ${APP}"
  systemctl start sonarqube
  msg_ok "Started ${APP}"
  msg_ok "Update Completed Successfully!"
else
  msg_ok "No update required. ${APP} is already at ${LATEST_VERSION}"
fi
}


start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         $http://${IP}:9000 
		 ${BL}SonarQube Default Credentials: admin/admin${CL} \n"
