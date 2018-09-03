#!/bin/bash
# disable passwords, root login, outside subnet?, force command to execute scripts
#
# To be run on $MASTER:
IP_MASTER=192.168.1.1
IP_HOST=192.168.1.2
USER=some1
ssh_config ()   # SSH configuration
{
    #
    key=${IP_HOST}.key

    # Create directory .ssh? or is created by ssh package?

    chmod 700 /home/${USER}/.ssh    # Set folder permission

    # RSA keys:
    ssh-keygen -t rsa -N "" -f "$key"   # keygen -type -Nopassword -filename ""
    chown "$USER":"$USER" ${key}*       # Change ownership otherwise belongs
                                        #   to Super User
    chmod 600 ${key}*                   # Set permissions
    mv ${key}* .ssh/                    # Move to .ssh/

    cp -n /etc/ssh/ssh_config /etc/ssh/ssh_config.orig
    cp /etc/ssh/ssh_config.orig /etc/ssh/ssh_config

    cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
    cp /etc/ssh/sshd_config.orig /etc/ssh/sshd_config

    # disable root login? no passwords?
    # -i to write
    sed 's/#NTP=/NTP='"$IP_MANAGER"'/' /etc/ssh/sshd_config
    sed 's/#NTP=/NTP='"$IP_MANAGER"'/' /etc/ssh/sshd_config
    sed 's/#NTP=/NTP='"$IP_MANAGER"'/' /etc/ssh/sshd_config
    sed 's/#NTP=/NTP='"$IP_MANAGER"'/' /etc/ssh/sshd_config

    #AuthorizedKeysFile; 

    if [[ $WAT_DO = MASTER ]]; then
        # ssh_config
    elif [[ $WAT_DO = MINION ]]; then
        # sshd_config
    fi
    #
    
    systemctl reload sshd.service
    # Use update.sh for Cluster configuration
}
ssh_minion