#!/bin/bash
#
# A script to help with the operation and maintenance of Skycoin-Skywire
#   nodes and clusters.
#
WAT_DO=MINION
USER=skywire
IP_MASTER=192.168.1.1
IP_MINION=192.168.1.2

#UI
# ask for: $USER, IP_MASTER, IP_MINION
# options:
#       status
#       troubleshooting/manual override:
#           manager
#           node
#           networking?
#           reinstall: remove /home/$USER
#       system update
#       skywire update
#           ssh batchmode to restart node?
#               add user '$superuser_thats_not_skywire' to automate updates (noshell?)?
#       convert existing
#       add/remove minion, to-master
#       hostnames
#       keys
#           backup/regen/copy
                https://github.com/skycoin/skywire/wiki/Backup-.skywire-folders-(public-keys)
#       replicate existing user and rename
# notes: connecting IP's with different subnets


# Before making changes
    cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.orig    # Backup
    cp /etc/ssh/sshd_config.orig /etc/ssh/sshd_config       # Use fresh copy

    cp -n /etc/ssh/ssh_config /etc/ssh/ssh_config.orig      # Backup
    cp /etc/ssh/ssh_config.orig /etc/ssh/ssh_config         # Fresh copy



userhome_ssh=/home/${USER}/.ssh
# Conditions
if [[ $WAT_DO = MASTER ]]; then
    # SSH to $MINION and add keys:
    ssh-copy-id $(ls "$userhome_ssh")@${IP_MINION}  # something something
fi



# SSH to $MINION; copy public key to .ssh/authorized_keys;
    #   make directory and set permissions:
    cat ${userhome}/.ssh/${key}.pub | ssh ${USER}@${IP_MINION} \
    "mkdir -p ${userhome}/.ssh && chmod 700 ${userhome}/.ssh && \
    cat >> ${userhome}/.ssh/authorized_keys"
# OR
    userhome=/home/${USER}
    su "$USER"
    ssh-copy-id ${USER}@${IP_MINION}    # *only works for user executing command

    cat ${userhome}/.ssh/${key}.pub | ssh ${USER}@${IP_MINION} "${userhome}/someScript" # or use sshd forcecommand; .bashrc for non interactive login shell

main ()
{

}
main


#knownhosts, host, batch mode, hashknownhosts, 

# Should a connection always be on?

# `ssh-copy-id` for $USER instead of this:
    # List for Authorized for 
    #sed "33s/.*/AuthorizedKeysFile \/home\/${USER}\/.ssh\/authorized_keys/" \
    #/etc/ssh/sshd_config  

        # SSH to $MINION and add keys:
    ssh-copy-id ${USER}@${IP_MINION}
    else
        echo "minion things"
        # SSH to master and add keys:
        ssh-copy-id ${USER}@${IP_MASTER}
    fi

    # force command to execute scripts:
#   batchmode_master
#   batchmode_minion