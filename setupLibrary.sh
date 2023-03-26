#!/bin/bash

# Add the new user account
# Arguments:
#   Account Username
function addUserAccount() {
    local username=${1}

    sudo adduser --disabled-password --gecos '' "${username}"

    sudo usermod -aG sudo "${username}"
    sudo passwd -d "${username}"
}

# Add the local machine public SSH Key for the new user account
# Arguments:
#   Account Username
#   Public SSH Key
function addSSHKey() {
    local username=${1}
    local sshKey=${2}

    execAsUser "${username}" "mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys"
    execAsUser "${username}" "echo \"${sshKey}\" | sudo tee -a ~/.ssh/authorized_keys"
    execAsUser "${username}" "chmod 600 ~/.ssh/authorized_keys"
}

# Execute a command as a certain user
# Arguments:
#   Account Username
#   Command to be executed
function execAsUser() {
    local username=${1}
    local exec_command=${2}

    sudo -u "${username}" -H bash -c "${exec_command}"
}

# Modify the sshd_config file
# shellcheck disable=2116
# Arguments:
#   Account SSH Port
function changeSSHConfig() {
    local port=${1}
    
    sudo sed -re 's/^(\#?)(PasswordAuthentication)([[:space:]]+)yes/\2\3no/' -i."$(echo 'old')" /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(PermitRootLogin)([[:space:]]+)(.*)/PermitRootLogin no/' -i /etc/ssh/sshd_config
    sudo sed -re "s/^(\#?)(Port)([[:space:]]+)(.*)/Port ${port}/" -i /etc/ssh/sshd_config
    sudo sed -re 's/^(\#?)(PubkeyAuthentication)([[:space:]]+)(.*)/PubkeyAuthentication yes/' -i /etc/ssh/sshd_config
}

# Setup the Uncomplicated Firewall
# Arguments:
#   Account SSH Port
function setupUfw() {
    local port=${1}
    
    sudo apt-get install ufw
    sudo ufw allow "${port}"
    yes y | sudo ufw enable
}

# Set the machine's timezone
# Arguments:
#   tz data timezone
function setTimezone() {
    local timezone=${1}
    echo "${1}" | sudo tee /etc/timezone
    sudo ln -fs "/usr/share/zoneinfo/${timezone}" /etc/localtime # https://bugs.launchpad.net/ubuntu/+source/tzdata/+bug/1554806
    sudo dpkg-reconfigure -f noninteractive tzdata
}

# Configure Network Time Protocol
function configureNTP() {
    ubuntu_version="$(lsb_release -sr)"

    if [[ $(bc -l <<< "${ubuntu_version} >= 20.04") -eq 1 ]]; then
        sudo systemctl restart systemd-timesyncd
    else
        sudo apt-get update
        sudo apt-get --assume-yes install ntp
        
        # force NTP to sync
        sudo service ntp stop
        sudo ntpd -gq
        sudo service ntp start
    fi
}

# Disables the sudo password prompt for a user account by editing /etc/sudoers
# Arguments:
#   Account username
function disableSudoPassword() {
    local username="${1}"

    sudo cp /etc/sudoers /etc/sudoers.bak
    sudo bash -c "echo '${username} ALL=(ALL) NOPASSWD: ALL' | (EDITOR='tee -a' visudo)"
}

# Reverts the original /etc/sudoers file before this script is ran
function revertSudoers() {
    sudo cp /etc/sudoers.bak /etc/sudoers
    sudo rm -rf /etc/sudoers.bak
}
