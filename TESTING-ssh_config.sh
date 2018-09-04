#!/bin/bash
WAT_DO=MINION
USER=skywire
IP_HOST=192.168.1.0
IP_MASTER=192.168.1.1
IP_MINION=192.168.1.2
USER=some1

ssh_config ()   # Base configuration for ssh: keys, daemon and client
{
    # Name the keys after $IP_HOST:
    userhome_ssh=/home/${USER}/.ssh

    mkdir -p "$userhome_ssh"
    chmod 700 "$userhome_ssh"   # Set permission     

    # RSA keys:
    ssh-keygen -t rsa -N "" -f "${IP_HOST}" # keygen -type -Nopassword -filename ""
    chown "$USER":"$USER" ${IP_HOST}*       # Change ownership otherwise belongs
                                            #  to Super User
    chmod 600 ${IP_HOST}*                   # Set permissions
    mv ${IP_HOST}* "$userhome_ssh"          # Move to .ssh/
    

    if [[ $WAT_DO = MINION ]]; then
        # SSH to $MASTER; copy public key to .ssh/authorized_keys;
        #   make directory and set permissions:
        cat ${userhome_ssh}/${IP_HOST}.pub | ssh ${USER}@${IP_MASTER} \
            "mkdir -p ${userhome_ssh} && ${userhome_ssh} && \
            cat >> ${userhome_ssh}/authorized_keys"
    fi

    systemctl restart sshd.service   # restart systemd service
}
ssh_config