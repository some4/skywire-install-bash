#!/bin/bash
#
# A script to help with the operation and maintenance of Skycoin-Skywire
#   nodes and clusters.
#
ssh_master ()
{
    # SSH to $MINION; copy public key to .ssh/authorized_keys;
    #   make directory and set permissions:
    cat ${userhome}/.ssh/${master_key}.pub | ssh ${USER}@${IP_MINION} \
    "mkdir -p ${userhome}/.ssh && chmod 700 ${userhome}/.ssh && \
    cat >> ${userhome}/.ssh/authorized_keys"
# OR
    ssh-copy-id ${USER}@${IP_MINION}
}

main ()
{

}