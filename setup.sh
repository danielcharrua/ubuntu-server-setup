#!/bin/bash

set -e

function getCurrentDir() {
    local current_dir="${BASH_SOURCE%/*}"
    if [[ ! -d "${current_dir}" ]]; then current_dir="$PWD"; fi
    echo "${current_dir}"
}

function includeDependencies() {
    # shellcheck source=./setupLibrary.sh
    source "${current_dir}/setupLibrary.sh"
}

current_dir=$(getCurrentDir)
includeDependencies
output_file="output.log"

function main() {
    echo "Welcome to the Host initialization script\n"
    createUser

    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    read -rp "Enter the username of the new user account: " username
    addUserAccount "${username}"


    read -rp $'Paste in the public SSH key for the new user:\n' sshKey
    read -rp $'Select the SSH port:\n' sshPort
    echo 'Running setup script...'
    logTimestamp "${output_file}"

    exec 3>&1 >>"${output_file}" 2>&1


    disableSudoPassword "${username}"
    addSSHKey "${username}" "${sshKey}"
    changeSSHConfig "${sshPort}"
    
    setupUfw "${sshPort}"
    
    setupTimezone

    echo "Configuring System Time... " >&3
    configureNTP

    service ssh restart

    cleanup

    echo "Setup Done! Log file is located at ${output_file}" >&3
}

function cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        revertSudoers
    fi
}

function logTimestamp() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}

function setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'Madrid/Europe'):\n" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="Madrid/Europe"
    fi
    setTimezone "${timezone}"
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}

main
