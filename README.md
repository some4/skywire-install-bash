
# Skycoin-Skywire scripts
Bash scripts that help with the setup and operation of a Skywire node.

SKY: B96wqyyP17wH4egNrMenU9yuXPSR9Jk9de and watch things grow!

User's are given the choice of installing a Skycoin-Skywire node and configuring as either a: Master or Minion.

Masters and Minions form a Cluster. For now, one Master manages a Cluster. All nodes may be individually logged-into and manually updated. 

A Super User installs Skywire and configures a User that runs Skywire with it's own permissions.

NTP, Go, an SSL Certificate Authority and Skywire-Manager/Node will be: downloaded, installed and configured. SSH keys are also generated.

## install.sh
Tested on x86_64, Debian 9(Stretch)
### Prerequisites
* Debian; systemd; a Super User with sudo permission

please have ready:
* an IP (that's not currently being used) for your Master node
* additional IP's set-aside for Minions
* your Router's IP

IF YOU'RE USING DHCP TO HANDLE IP's: have the IP's established on your router before running the script; if your nodes lose power and/or your router assigns new leases with different IP's IT WILL BREAK THE CLUSTER

### Usage
`wget https://raw.githubusercontent.com/some4/Skywire/master/install.sh`

`chmod +x install.sh`

`sudo ./install.sh`

and follow the prompts
### Post-install
* `http://IP_OF_MASTER_NODE:8000` on your browser and set a manager password (default:1234). Check if your nodes are present 
* for each node: under 'Operations' click 'settings' and check if there is a green checkmark to-the-right-of 'Discovery Address Status'

## update.sh
### Prerequisites

### Usage
