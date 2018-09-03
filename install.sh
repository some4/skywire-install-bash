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

## Global variables
# NAME:         ##  used_in_functions:
IP_HOST=""      #   ip_prompt_host, ntp_config
IP_MANAGER=""   #   ip_prompt_manager, ntp_config
IP_SUBNET=""    #
PKG_MANAGER=""  #   distro_check, prereq_check
PKG_UPDATE=""   #   distro_check
PKG_UPGRADE=""  #   distro_check
USER="skywire"  #   default User that will run Skywire
WAT_DO=""       #   main

## Functions
distro_check ()         # System compatibility check for this script
{
    # Set Global variables based on package manager:
    #   If apt exists = Debian
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE=""$PKG_MANAGER" update"
        PKG_UPGRADE=""$PKG_MANAGER" upgrade -y" # -y yes to all
    #elif Some other distro goes here...maybe
    else
        echo "Your distribution is not supported by this script."
        exit
    fi
    
    # Check for systemd:
    if command -v systemctl &> /dev/null; then
        echo "This script requires systemd."
        exit
    fi
}
distro_update ()        # Base update and upgrade
{
    echo -e             # Create empty line
    echo "Updating package lists..."
    eval "$PKG_UPDATE"  # Create a command using variable from distro_check

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
}
user_create ()          # Create User/Group 'skywire'; set GOPATH, permissions
{
    echo "Creating user "$USER""
    useradd "$USER"
    usermod -aG "$USER" "$USER"         # Create group and add User
    usermod -u 5154 "$USER"             # Change UID
    groupmod -g 5154 "$USER"            # Change GID
    usermod -aG ssh "$USER"             # Add User to group SSH
    mkdir -p /home/${USER}/go           # Create /home and GOPATH directory
    touch /home/${USER}/.bash_profile   # To set User GOPATH

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

ip_validate ()          # Check format of IP entry
{
    local ip=$1         # Assign to local variable
    local stat=1        # Initial exit status; if an entry doesn't pass it will
                        #   return to ask User again

    # Check if follows format (nnn.nnn.nnn.nnn):
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS       # Save current Internal Field Separator
        IFS='.'         # Split string with new IFS
        ip=($ip)        # Assign to array
        IFS=$OIFS       # Revert IFS

        # Test values to see if they're within IP range:
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
        && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]

        stat=$?         # $? = most recent pipline exit status; 0
    fi
    return $stat        # Send status down to ip_prompt_* ()
}
ip_bad_entry ()         # Alert User and require action for an invalid entry
{
    # Prompt User action (n1 = read any single byte; s = turn off echo):
    read -p "Invalid IP. Press any key to try again... " -n1 -s
}
ip_prompt_host ()       # Ask User to enter IP they would like to set for node
{
    local entry_host=""
    clear

    # Ask for input and set as local variable:
    read -p "Enter the IP address for this node:" entry_host
    
    # Check if valid entry:
    ip_validate "$entry_host"

    if [[ $? -ne 0 ]]; then # Start over (output from ip_validate)
        ip_bad_entry
        ip_prompt_host      # To the top and ask again
    else
        IP_HOST="$entry_host"
    fi
}
ip_prompt_manager ()    # Ask User to enter a Node Manager IP
{
    local entry_manager=""
    echo -e

    # Ask for input and set local variable:
    read -p "Enter the IP of a Skywire Manager:" entry_manager
    
    # Check if valid entry:
    ip_validate "$entry_manager"

    if [[ $? -ne 0 ]]; then         # Start over
        ip_bad_entry
        ip_prompt_manager           # To the top and ask again
    else
        IP_MANAGER="$entry_manager"
    fi
}

menu ()                 # Presentation and options;
{
    clear
    local choice=""             # set by User

    ui_menu                     # Display options to User
    
    read -p "" choice           # -p for prompt
    case "$choice" in
        z|Z ) WAT_DO="MASTER";;
        p|P ) WAT_DO="MINION";;
        q|Q ) exit;;
        * ) . install.sh;;      # sigh...
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

ntp_config ()   # Network Time Protocol (NTP)
{
    # NTP daemon (ntpd) on a Master node syncs to an outside, low-stratum pool.
    #   Systemd-timesyncd on Minions are prioritized to sync to Master-ntpd
    #   and will fallback to the Debian pool.

    # Stop timesyncd:
    systemctl stop systemd-timesyncd.service

    # Backup (but don't overwrite an existing) config. If not, sed will keep
    #   appending file:
    cp -n /etc/systemd/timesyncd.conf /etc/systemd/timesyncd.orig
    # Use fresh copy in case installer used on existing system
    cp /etc/systemd/timesyncd.orig /etc/systemd/timesyncd.conf

    # When system is set to sync with RTC the time can't be updated and NTP is
    #   crippled. Switch off that setting with:
    timedatectl set-local-rtc 0

    timedatectl set-ntp on

    # Menu choices:
    if [[ $WAT_DO = MASTER ]]; then # Configure ntpd for choice $MASTER
        echo "Installing Network Time Protocol daemon (NTP)..."
        "$PKG_MANAGER" install ntp -y

        echo "Configuring NTP..."
        # Backup (but don't overwrite an existing)
        cp -n /etc/ntp.conf /etc/ntp.orig
        # Fresh copy
        cp /etc/ntp.orig /etc/ntp.conf

        # Set a standard polling interval (n^2 seconds)
        sed -i '/.org iburst/ s/$/ minpoll 6 maxpoll 8/' \
        /etc/ntp.conf

        # Disable timesyncd because it conflicts with ntpd
        systemctl disable systemd-timesyncd.service

        echo "Restarting NTP..."
        systemctl restart ntp.service
    else                            # Configure timesyncd for choice $MINION
        echo "Configuring to sync with Master node..."
        sed -i 's/#NTP=/NTP='"$IP_MANAGER"'/' \
        /etc/systemd/timesyncd.conf

        # Fallback on Debian pools
        sed -i 's/#Fall/Fall/' \
        /etc/systemd/timesyncd.conf

        echo "Restarting timesyncd..."
        systemctl restart systemd-timesyncd.service
    fi

    # Set hardware clock to UTC (which doesn't have daylight savings):
    hwclock -w
}

go_install ()   # Detect CPU architecture, install Go and update system PATH
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

        # -c resumes partial downloads and doesn't restart if exists
        wget -c https://dl.google.com/go/${link}

        check_hash

        # Loop twice if initial fails; possible exit codes: {-1,2}
        #   (remember, variable "tries" first declared as integer 2)
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

git_build_skywire ()    # Clone Skywire repo; build binaries; set permissions
{
    mkdir -p ${GOPATH}/src/github.com/skycoin
    cd ${GOPATH}/src/github.com/skycoin
    git clone https://github.com/skycoin/skywire.git

    cd ${GOPATH}/src/github.com/skycoin/skywire/cmd
    echo "Building Skywire binaries please wait..."
    /usr/local/go/bin/go install ./... | \
    while read line; do                     # Progress indicator
        x=$((x+1))
        echo -en ""$x"\r"
    done

    # Finally, set home permissions:
    chown "$USER":"$USER" -R /home/${USER}  # Change owner:group
    chmod 754 -R /home/${USER}              # Set directory permissions
}



main () #
{
    distro_check                    # Check compatibility; Debian, Systemd?
    menu                            # Show User some choices

    # Check for permission:
    #   if EffectiveUserID not zero
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script requires Super User permission"
        exit
    fi

    ip_prompt_host                  # User sets host/node IP

    # Choices from menu ()
    if [[ $WAT_DO = MASTER ]]; then
        IP_MANAGER="$IP_HOST"
    elif [[ $WAT_DO = MINION ]]; then
        ip_prompt_manager
    fi

    distro_update

    # Certificate Authority for SSL
    "$PKG_MANAGER" install ca-certificates -y
    #   `update-ca-certificates` for future reference

    prereq_check            # If no Git, gcc go get

    ntp_config              # Setup appropriate NTP settings

    go_install              # Go download, install and set GOROOT path

    user_create             # Create User and add to Group; set GOPATH

    git_build_skywire       # Clone Skywire repo; build binaries; permissions

    # Github.com/some4/Skywire
}
main