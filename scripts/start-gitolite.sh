#!/usr/bin/env bash
set -e -o pipefail

sshd_base_dir="/home/gitolite/sshd"
sshd_config="${sshd_base_dir:?}/sshd_config"
sshd_host_key="${sshd_base_dir:?}/host_rsa_key"
gitolite_admin_pub_key="$HOME/.gitolite/keydir/key.pub"

setup_gitolite_sshd() {
    echo "Checking for existing Gitolite Host SSH keys ..."
    echo

    if [ -f "${sshd_config:?}" ]; then
        echo "Existing Gitolite SSH configuration \"${sshd_config:?}\" found"
        echo "Not generating any new SSH host keys or any new SSH configurations."
    else
        mkdir -p ${sshd_base_dir:?}
        echo "Generating Gitolite Host SSH key at ${sshd_host_key:?}"
        ssh-keygen -t rsa -b 4096 -f ${sshd_host_key:?} -N ''

        cat << EOF > ${sshd_base_dir:?}/sshd_config
Port 2222
ListenAddress 0.0.0.0
HostKey ${sshd_host_key:?}
AuthorizedKeysFile  .ssh/authorized_keys
ChallengeResponseAuthentication no
PasswordAuthentication no
UsePAM no
PidFile /tmp/gitolite-sshd.pid
EOF
    fi

    echo
    echo
}

setup_gitolite_admin_public_key() {
    if [ -f "${gitolite_admin_pub_key:?}" ]; then
        echo "Existing Gitolite Admin Public key found at ${gitolite_admin_pub_key:?}"
        if [[ "${GITOLITE_ADMIN_SSH_PUBLIC_KEY_FORCE_OVERWRITE}" != "1" ]]; then
            if [[ "${GITOLITE_ADMIN_SSH_PUBLIC_KEY}" != "" ]]; then
                echo "Not using the supplied Gitolite Admin SSH public key since GITOLITE_ADMIN_SSH_PUBLIC_KEY_FORCE_OVERWRITE was not set."
                echo "Running \"gitolite setup\" to fix any inconsistencies ..."
                gitolite setup
                echo
            fi
            return
        else
            echo "Will overwrite existing Gitolite Admin SSH public key since GITOLITE_ADMIN_SSH_PUBLIC_KEY_FORCE_OVERWRITE is set to \"1"\"
        fi
    else
        echo "No existing Gitolite Admin Public key found at ${gitolite_admin_pub_key:?}"
    fi

    if [[ "${GITOLITE_ADMIN_SSH_PUBLIC_KEY}" == "" ]]; then
        echo "GITOLITE_ADMIN_SSH_PUBLIC_KEY environment variable cannot be empty"
        echo "Please set the Gitolite admin user's SSH public key using this environment variable!"
        exit 1
    fi
    echo -e "Using the following public key for Gitolite admin user:\n${GITOLITE_ADMIN_SSH_PUBLIC_KEY}\n\n"

    local admin_key_temp_dir="$(mktemp -d)"
    mkdir -p $HOME/.ssh ${admin_key_temp_dir:?}
    touch $HOME/.ssh/authorized_keys

    echo "${GITOLITE_ADMIN_SSH_PUBLIC_KEY:?}" > ${admin_key_temp_dir:?}/key.pub
    unset GITOLITE_ADMIN_SSH_PUBLIC_KEY
    gitolite setup --pubkey ${admin_key_temp_dir:?}/key.pub
    rm -rf ${admin_key_temp_dir:?}

    echo
}

setup_gitolite() {
    echo "Setting up gitolite ..."

    setup_gitolite_sshd
    setup_gitolite_admin_public_key

    echo
}

start_gitolite_sshd () {
    echo "Starting gitolite sshd ..."
    echo
    exec /usr/sbin/sshd -D -e -f ${sshd_config:?}
}

if [ "$1" = 'gitolite-oneshot' ]; then
    setup_gitolite
    start_gitolite_sshd
else
    exec "$@"
fi
