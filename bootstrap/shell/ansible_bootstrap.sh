#!/usr/bin/bash

PACKAGES="epel-release which ansible"

for PKG in ${PACKAGES}; do
  if [ "${PKG}" == "ansible" ]; then
    command -v pipx >/dev/null 2>&1 || dnf -y install pipx && pipx ensurepath --global
    command -v ansible >/dev/null 2>&1 || pipx install --include-deps ansible --global
  else
    dnf list installed ${PKG} &>/dev/null || dnf -y install ${PKG}
  fi
done

CODE_SERVER_YUM_REPO="$(cat << _JEEEX_
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
_JEEEX_
)"

RAMDOM_PASSWD="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)"
CODE_SERVER_CFG="$(cat << _JEEEX_
auth: password
password: ${RAMDOM_PASSWD}
cert: false
_JEEEX_
)"

CODE_USERS="jeeex"

CODE_SERVER_VER="4.102.3"

INSTALL_CODE_SERVER() {
  # if ! [ -e /etc/yum.repos.d/vscode.repo ]; then
  #   echo "${CODE_SERVER_YUM_REPO}" | tee /etc/yum.repos.d/vscode.repo > /dev/null
  # fi
  # rpm --import https://packages.microsoft.com/keys/microsoft.asc
  # dnf -y install code
  if ! [ -e code-server-${CODE_SERVER_VER}-amd64.rpm ]; then
    curl -fOL https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VER}/code-server-${CODE_SERVER_VER}-amd64.rpm
  fi
  rpm -i code-server-${CODE_SERVER_VER}-amd64.rpm
  systemctl daemon-reload
  systemctl enable code-server@$USER
  systemctl start code-server@$USER
  for CODE_USER in ${CODE_USERS}; do
    mkdir -p /home/${CODE_USER}/.config/code-server
    CODE_SERVER_PORT=9991
    echo "bind-addr: 0.0.0.0:${CODE_SERVER_PORT}" | tee /home/${CODE_USER}/.config/code-server/config.yaml > /dev/null
    echo "${CODE_SERVER_CFG}" | tee -a /home/${CODE_USER}/.config/code-server/config.yaml > /dev/null
    firewall-cmd --permanent --add-port=${CODE_SERVER_PORT}/tcp
    firewall-cmd --reload
    CODE_SERVER_PORT++
  done
  systemctl status --no-pager code-server@$USER
}

command -v code || INSTALL_CODE_SERVER

