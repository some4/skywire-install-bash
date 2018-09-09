#!/bin/bash
#
# A script to help with installation of a Skycoin-Skywire node.
#
# User's are given the choice of installing a Skycoin-Skywire node
#   and configuring as either a: Master or Minion.
#
# Masters and Minions form a Cluster. For now, one Master manages a Cluster.
#   All nodes may be individually logged-into and manually updated. 
#
# A Super User installs Skywire and configures a User that runs Skywire with
#   it's own permissions.
#
# UserRunningScript will be given a choice of manual IP entry or using
#   the current (DHCP?) assignment for This node's IP.

## Global variables:
# NAME          ##  used to:
#               #   used in functions:
IP_HOST=""      #   ip_entry, ntp_config
IP_MANAGER=""   #   ip_prompt_manager, ntp_config
IP_ACTION=""    ##  set local IP variables
PKG_MANAGER=""  #   distro_check, prereq_check
PKG_UPDATE=""   #   distro_check
PKG_UPGRADE=""  #   distro_check
USER="skywire"  ##  assign User to Skywire
WAT_DO=""       #   main

## Presentation and options:
menu ()
{
    clear
    local choice=""             # set by User

    ui_menu                     # display options to User

    read -p "" choice           # -p for prompt
    case "$choice" in
        z|Z ) WAT_DO="MASTER";;
        p|P ) WAT_DO="MINION";;
        q|Q ) exit;;
        * ) . install.sh
    esac
}
ui_menu ()              # separated from menu () to keep things tidy
{
cat <<MENU
Welcome to some Skywire install script!
Press:
    'z' to setup a MASTER node.
    'p' to setup as a MINION node.
    'q' to quit
MENU
}

## A set of functions for checking format of an IP address entry:
ip_validate ()  # Check format/values of IP entry
{
    local ip=$1         # assign to local variable
    local stat=1        # initial exit status; if an entry doesn't pass it will
                        #   return to ask User again

    # Check if follows format (nnn.nnn.nnn.nnn):
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS       # save current Internal Field Separator
        IFS='.'         # split string with new IFS
        ip=($ip)        # assign to array
        IFS=$OIFS       # revert IFS

    #   test values to see if they're within IP range:
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
        && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]

        stat=$?         # $? = most recent pipline exit status; 0
    fi
    return "$stat"      # send status down to ip_prompt_* ()
}
ip_bad_entry () # Alert User and require action for an invalid entry
{
    sleep 3     # to slow spam
    
    # Prompt User action (n1 = read any single byte; s = turn off echo):
    read -p "Invalid IP. Press any key to try again... "``$'\n' -n1 -s
}
ip_check ()     # Ask User to enter an IP and check it's value
{
    local entry_ip=""
    IP_ACTION=""    # used to set values outside, post-function after success

    # Ask for input and set local variable:
    read -p "Enter the IP address $ACTION"``$'\n' entry_ip

    IP_ACTION=$entry_ip

    # Check if valid entry:
    ip_validate "$entry_ip"

    if [[ $? -ne 0 ]]; then # start over
        ip_bad_entry
        ip_check            # to the top and ask again
    fi
}

## System functions:
distro_check ()         # System compatibility check for this script
{
    # Check package manager type and if systemd exists:
    
    #   if `apt` exists = Debian:
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE=""$PKG_MANAGER" update"
        PKG_UPGRADE=""$PKG_MANAGER" upgrade -y" # -y yes to all
    #elif Some other distro goes here...maybe
    else
        echo "Your distribution is not supported by this script."
        exit
    fi

    #   systemd:
    if [[ ! -d /usr/lib/systemd ]]; then
        echo "This script requires systemd."
        exit
    fi
}
net_interface_config () # Configure network adapter
{
    # A file named after the adapter will be added to folder
    #   /etc/network/interfaces.d with an appropriate configuration:
    
    # Option for manual IP entry or using DHCP assignment:
    local choice_nic=""
    local dhcp=0                                # 1=yes,0=no DHCP
    echo "Press 'z' to manually assign IP's."
    read -p "Press 'p' if using DHCP"$'\n' choice_nic # $'\n' moves cursor
    case "$choice_nic" in
        p|P ) dhcp=1;;
        z|Z ) ;;
        * ) net_interface_config;;
    esac

    # Get deviceName:
    local deviceName=""
    #   1st network deviceName; no loopback(lo),virtual(vir),wireless(wl)):
    deviceName=$(ip link | `\
                `awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | `\
                `sed -n '1p' | sed 's/ //') # 2p,3p,4p... for following devices

    # Network configuration:
    if [[ "$WAT_DO" = MASTER && "$dhcp" = 0 ]]; then
    #   From ip_check: "Enter the IP address ...":
        ACTION="of this "$WAT_DO" node:"
        ip_check
        IP_HOST="$IP_ACTION"    # Set host address
        IP_MANAGER="$IP_HOST"   # Set Manager address
    elif [[ "$WAT_DO" = MASTER && "$dhcp" = 1 ]]; then
        IP_HOST=$(ip addr | grep 'state UP' -A2 | tail -n1 | `
        `awk '{print $2}' | cut -f1 -d'/')
        IP_MANAGER="$IP_HOST"
    elif [[ "$WAT_DO" = MINION && "$dhcp" = 0 ]]; then   
    #   "Enter the IP address ...":
        ACTION="of this "$WAT_DO" node:"
        ip_check "$entry_ip"
        IP_HOST="$IP_ACTION"    # Set host address 
    #   "Enter the IP address ...":
        ACTION="of a Skywire manager:"
        ip_check "$entry_ip"
        IP_MANAGER="$IP_ACTION" # Set a Manager address
    elif [[ "$WAT_DO" = MINION && "$dhcp" = 1 ]]; then
        IP_HOST=$(ip addr | grep 'state UP' -A2 | tail -n1 | `
        `awk '{print $2}' | cut -f1 -d'/')
    #   "Enter the IP address ...":
        ACTION="of a Skywire manager:"
        ip_check "$entry_ip"
        IP_MANAGER="$IP_ACTION" # Set a Manager address
    fi

    # Gather information:
    local interfacesd=/etc/network/interfaces.d # 2 make read e z
    local ip_router=""
    if [[ "$dhcp" = 0 ]]; then
    #   from ip_check: "Enter the IP address ...":
        ACTION="of your Router:"
        ip_check
        ip_router="$IP_ACTION"                  # set Router address

        printf "auto "$deviceName"\n`
        `allow-hotplug "$deviceName"\n`
        `iface "$deviceName" inet static\n`
        `address "$IP_HOST"\n`
        `netmask 255.255.255.0\n`               # static subnet for now
        `gateway "$ip_router"\n`
        `dns-nameservers "$ip_router"\n" \
        > "${interfacesd}/${deviceName}.cfg"

    elif [[ "$dhcp" = 1 ]]; then                # DHCP/auto networking:
        printf "auto "$deviceName"\n`
        `allow-hotplug "$deviceName"\n`
        `iface "$deviceName" inet dhcp\n" \
        > "${interfacesd}/${deviceName}.cfg"
    fi

    # Remove lines containing 'dhcp/static' from /etc/network/interfaces
    #   to cripple duplicate entries:
    sed -i '/dhcp/d; /static/d' /etc/network/interfaces
}
distro_update ()        # Base update and upgrade
{
    echo -e             # create empty line
    echo "Updating package lists..."
    eval "$PKG_UPDATE"  # create a command using variable from distro_check

    echo -e
    echo "Upgrading system..."
    eval "$PKG_UPGRADE"
}
prereq_check ()         # Check if Git, gcc installed; install if not
{
    # Is Git in system PATH?
    if git --version >/dev/null 2>&1; then
        echo "Git installed."
    else
        echo "Git not found; installing..."
        "$PKG_MANAGER" install git -y
    fi

    # What about gcc?
    if gcc --version >/dev/null 2>&1; then
        echo "gcc installed."
    else
        echo "gcc not found; installing..."
        "$PKG_MANAGER" install gcc -y
    fi

    # Install Certificate Authority for SSL:
    "$PKG_MANAGER" install ca-certificates -y
    #   `update-ca-certificates` for future reference
}
user_create ()          # Create User/Group 'skywire'; set GOPATH, permissions
{
    # Check if .bash_profile exists; delete:
    if [[ -f /home/${USER}/.bash_profile ]]; then
        rm /home/${USER}/.bash_profile
    fi

    echo "Creating user "$USER""
    useradd "$USER"
    usermod -aG "$USER" "$USER"         # create group and add User
    usermod -u 5154 "$USER"             # change UID
    groupmod -g 5154 "$USER"            # change GID
    usermod -aG ssh "$USER"             # add User to group SSH
    mkdir -p /home/${USER}/go           # create /home and GOPATH directory
    touch /home/${USER}/.bash_profile   # to set User GOPATH

    # Export PATH's for this script; otherwise `source` will set home of 
    #   Super User as PATH:
    export GOPATH=/home/${USER}/go
    export GOBIN=${GOPATH}/bin

    # GOPATH is user-specific; root, SU and the Owner can build/execute/write
    #   to this path. Others may only read and can join group '$USER'
    #   for privilege:
    echo "export GOROOT=/usr/local/go" >> /home/${USER}/.bash_profile
    echo "export GOPATH=/home/${USER}/go" >> /home/${USER}/.bash_profile
    echo "export GOBIN=${GOPATH}/bin" >> /home/${USER}/.bash_profile
    echo "PATH="$PATH":"$GOBIN"" >> /home/${USER}/.bash_profile
    source /home/${USER}/.bash_profile
}
ntp_config ()           # Network Time Protocol (NTP)
{
    # NTP daemon (ntpd) on a Master node syncs to an outside, low-stratum pool.
    #   systemd-timesyncd on Minions are prioritized to sync to Master-ntpd
    #   and will fallback to the Debian pool.

    # Stop timesyncd:
    systemctl stop systemd-timesyncd.service

    # Backup (but don't overwrite an existing) config. If not, sed will keep
    #   appending file:
    cp -n /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.orig
    # Use fresh copy in case installer used on existing system:
    cp /etc/systemd/timesyncd.orig /etc/systemd/timesyncd.conf

    # When system is set to sync with RTC the time can't be updated and NTP
    #   is crippled. Switch off that setting with:
    timedatectl set-local-rtc 0
    timedatectl set-ntp on

    # Menu choices:
    if [[ $WAT_DO = MASTER ]]; then
    #   Configure ntpd for choice $MASTER
        echo "Installing Network Time Protocol daemon (NTP)..."
        "$PKG_MANAGER" install ntp -y

        echo "Configuring NTP..."
    #   Backup (but don't overwrite an existing)
        cp -n /etc/ntp.conf /etc/ntp.orig
        # Fresh copy
        cp /etc/ntp.orig /etc/ntp.conf

    #   Set a standard polling interval (n^2 seconds)
        sed -i '/.org iburst/ s/$/ minpoll 6 maxpoll 8/' \
        /etc/ntp.conf

    #   Disable timesyncd because it conflicts with ntpd
        systemctl disable systemd-timesyncd.service

        echo "Restarting NTP..."
        systemctl restart ntp.service
    else                            # configure timesyncd for choice $MINION
        echo "Configuring to sync with Master node..."
        sed -i 's/#NTP=/NTP='"$IP_MANAGER"'/' \
        /etc/systemd/timesyncd.conf

    #   Fallback on Debian pools:
        sed -i 's/#Fall/Fall/' \
        /etc/systemd/timesyncd.conf

        echo "Restarting timesyncd..."
        systemctl restart systemd-timesyncd.service
    fi

    # Set hardware clock to UTC (which doesn't have daylight savings):
    hwclock -w
}
go_install ()           # Detect CPU; install Go; update system PATH
{
    local cpu=""
    local os="linux"
    local version=1.11
    local link=""       # system binary URL, check_hash, File Archive (.tar.gz)
    local hash=""       # Expected Hash Values copied from https://golang.org/dl/
    local hashCheck=""  # Local Hash Compute Value
    local tries=2       # Go download attempts, exit status counter

    # Get CPU architecture;
    #   `lscpu` | 1st line | 2nd column
    cpu="$(lscpu | sed 1q | awk '{ print $NF }')"
    #   supported types:
    if [ $cpu = "x86_64" ]; then
        cpu=.${os}-amd64
        hash=b3fcf280ff86558e0559e185b601c9eade0fd24c900b4c63cd14d1d38613e499
    elif [ $cpu=*"arm"* ]; then
        cpu=.${os}-armv6l
        hash=8ffeb3577d8ca5477064f1cb8739835973c866487f2bf81df1227eaa96826acd
    else
        echo "Your CPU is not supported by this script."
        exit
    fi

    # For e z URL and filename use:
    link=go${version}${cpu}.tar.gz

    check_hash ()   # Compare (Downloaded vs Expected) hash
    {
        # Checksum references a file with [$hash *$link] in it:
        hashCheck=$(echo "$hash" *"$link" | sha256sum -c)
        case "$hashCheck" in
            *OK )   echo "Checksums match! "$link" OK";
                    tries=-1;;  # Winner!
            *   )   echo "";;
        esac
    }
    # Try to get the appropriate Go binary:
    while [ $tries -ge 0 ]; do  # while $tries>=0

    #   -c resumes partial downloads and doesn't restart if exists
        wget -c https://dl.google.com/go/${link}

        check_hash

    #   Loop twice if initial fails; possible exit codes: {-1,2}
    #       (remember, variable "tries" first declared as integer 2)
        if [ $tries -eq 2 ]; then           # Strike 1
            echo "Retrying download..."     #   maybe interrupted?
        elif [ $tries -eq 1 ]; then         # Strike 2
            echo "Deleting "$link" and starting new download..."
            rm "$link"
        elif [ $tries -eq 0 ]; then         # See ya
            echo "The hash of the Go file archives you've downloaded do not"
            echo "match the Expected Hash."
            rm "$link"
            exit
        elif [ $tries -eq -1 ]; then        # Good to go!
            break
        fi
        ((tries--)) # Tick loop counter down
    done

    # Extract Go file archive (as per golang.org/doc/install):
    echo "Extracting Go to /usr/local..."
    tar xvpf "$link" -C /usr/local 2>&1 | \
    #   -e[x]tract -[v]erbose -[p]reservePermissions -use[f]ileArchive
    #   -[C]hange to directory
    while read line; do                     # Progress indicator
        x=$((x+1))
        echo -en ""$x" extracted\r"
    done

    # Add Go to system PATH:
    cp -n /etc/profile /etc/profile.orig    # Copy but don't overwrite existing
    cp /etc/profile.orig /etc/profile       # Use fresh copy
    echo "export PATH=\$PATH:/usr/local/go/bin/" >> /etc/profile
    echo -e
    echo "Go installed!"
}
git_build_skywire ()    # Clone Skywire repo; build binaries; permissions
{
    mkdir -p ${GOPATH}/src/github.com/skycoin
    cd ${GOPATH}/src/github.com/skycoin
    git clone https://github.com/skycoin/skywire.git

    cd ${GOPATH}/src/github.com/skycoin/skywire/cmd
    echo "Building Skywire binaries please wait..."
    /usr/local/go/bin/go install -a -v ./...    # -a (force rebuild); -verbose
}
skywire_manager ()      # systemd/autostart configuration; permissions
{
    # In order to start an application, systemd wants .service files to
    #   point-to "Absolute Path's."
    # 'ExecStart=' points to a file containing an Absolute Path that starts
    #   the application.
    # 'ExecStop=' contains an Absolute Path that searches for process
    #   'ExecStart=' and kills them (and their duplicates).

    # Create systemd .service file:
    printf "[Unit]\n`
        `Description=Skywire Manager\n`
        `After=network.target\n`
        `\n`
        `[Service]\n`
        `User=${USER}\n`
        `Group=${USER}\n`
        `Type=oneshot\n`
        `RemainAfterExit=yes\n`
        `ExecStart=/home/${USER}/skywire_managerStart\n`
        `ExecStop=/home/${USER}/skywire_managerStop\n`
        `\n`
        `[Install]\n`
        `WantedBy=multi-user.target\n" \
        > /lib/systemd/system/skymanager.service

    # 'ExecStart=' file:
    printf "#!/bin/bash\n`
        `cd "$GOBIN"\n`
        `./manager -web-dir `
        `${GOPATH}/src/github.com/skycoin/skywire/static/skywire-manager `
        `> /dev/null 2>&1 &sleep 3\n" \
        > /home/${USER}/skywire_managerStart
    #   permissions
        chown ${USER}:${USER} /home/${USER}/skywire_managerStart
        chmod 754 /home/${USER}/skywire_managerStart

    # 'ExecStop=' file:
    printf "#!/bin/bash\n`
        `kill -9 $(ps aux | grep '[.]/manager')\n" \
        > /home/${USER}/skywire_managerStop
    #   permissions
        chown ${USER}:${USER} /home/${USER}/skywire_managerStop
        chmod 754 /home/${USER}/skywire_managerStop
}
skywire_node ()         # Create service file for Skywire Node (autostart)
{
    # Make discovery address e z:
    local disc_addr="discovery.skycoin.net:`
    `5999-034b1cd4ebad163e457fb805b3ba43779958bba49f2c5e1e8b062482904bacdb68"

    # Assign a Skywire Manager:
    if [[ "$WAT_DO" = MASTER ]]; then
        local manager_ip="127.0.0.1"
    elif [[ "$WAT_DO" = MINION ]]; then
        local manager_ip="$IP_MANAGER"
    fi

    # Create systemd service file:
    printf "[Unit]\n`
        `Description=Skywire Node\n`
        `After=network.target\n`
        `\n`
        `[Service]\n`
        `User=${USER}\n`
        `Group=${USER}\n`
        `Type=oneshot\n`
        `RemainAfterExit=yes\n`
        `ExecStart=/home/${USER}/skywire_nodeStart\n`
        `ExecStop=/home/${USER}/skywire_nodeStop\n`
        `\n`
        `[Install]\n`
        `WantedBy=multi-user.target\n" \
        > /lib/systemd/system/skynode.service
 
    # 'ExecStart=' file:
    printf "#!/bin/bash\n`
        `manager_ip=\"$manager_ip\"\n`
        `\n`
        `cd "$GOBIN"\n`
        `./node -connect-manager -manager-address \$manager_ip:5998 `
        `-manager-web \$manager_ip:8000 `
        `-discovery-address "$disc_addr" -address :5000 -web-port :6001 `
        `> /dev/null 2>&1 &sleep 3\n" \
        > /home/${USER}/skywire_nodeStart
    #   permissions
        chown ${USER}:${USER} /home/${USER}/skywire_nodeStart
        chmod 754 /home/${USER}/skywire_nodeStart

    # 'ExecStop=' file:
    printf "#!/bin/bash\n`
        `kill -9 $(ps aux | grep '[.]/node')\n" \
        > /home/${USER}/skywire_nodeStop
    #   permissions
        chown ${USER}:${USER} /home/${USER}/skywire_nodeStop
        chmod 754 /home/${USER}/skywire_nodeStop
}
ssh_config ()           # Base configuration for ssh: keys, daemon and client
{
    ssh_userHome=/home/${USER}/.ssh # Make this path e z

    mkdir -p "$ssh_userHome"
    chown ${USER}:${USER} -R "$ssh_userHome"
    chmod 700 "$ssh_userHome"   # set permission    

    ssh-keygen -t rsa -N "" `   # keygen -type rsa no password
    `-f "$IP_HOST" `            # filename
    `-C "$IP_HOST"              # internal comment

    chown "$USER":"$USER" "$IP_HOST"*       # Change ownership otherwise belongs
                                            #  to Super User
    chmod 600 "$IP_HOST"*                   # Set permissions
    mv "$IP_HOST"* "$ssh_userHome"          # Move to .ssh/
}

main ()
{
    sleep 3                         # to slow spam

    distro_check                    # Check compatibility; Debian, systemd?
    
    menu                            # Show User some choices

    # Check for permission:
    if [[ "$EUID" -ne 0 ]]; then    # if EffectiveUserID not zero
        echo "This script requires Super User permission"
        exit
    fi

    net_interface_config

    distro_update

    prereq_check            # If no Git, gcc go get

    ntp_config              # Setup appropriate NTP settings

    go_install              # Go download, install and set GOROOT path

    user_create             # Create User and add to Group; set GOPATH

    git_build_skywire       # Clone Skywire repo; build binaries; permissions

    # Set folder permissions:
    chown "$USER":"$USER" -R /home/${USER}  # Change owner:group
    chmod 754 -R /home/${USER}              # Set base permissions
    
    skywire_node            # Skywire systemd configurations:
    
    skywire_manager

    systemctl daemon-reload
    sleep 3
    # Start Skywire services to generate keys and directories:
    if [[ "$WAT_DO" = MASTER ]]; then
        systemctl enable skynode.service
        systemctl start skynode.service

        systemctl enable skymanager.service
        systemctl start skymanager.service
    elif [[ "$WAT_DO" = MINION ]]; then
        systemctl enable skynode.service
        systemctl start skynode.service
    fi

    ssh_config

    echo "Installation complete."

    # Github.com/some4/Skywire
}
main
