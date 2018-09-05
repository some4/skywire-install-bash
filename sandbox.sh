#!/bin/bash
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
    return "$stat"        # Send status down to ip_prompt_* ()
}
ip_bad_entry ()         # Alert User and require action for an invalid entry
{
    # Prompt User action (n1 = read any single byte; s = turn off echo):
    read -p "Invalid IP. Press any key to try again... " -n1 -s
}
ip_check ()    # Ask User to enter a Node Manager IP
{
    local entry_ip=""
    IP_ACTION=""

    # Ask for input and set local variable:
    read -p "Enter the IP address $ACTION" entry_ip

    IP_ACTION=$entry_ip

    # Check if valid entry:
    ip_validate "$entry_ip"

    if [[ $? -ne 0 ]]; then         # Start over
        ip_bad_entry
        ip_check           # To the top and ask again
    fi
}

main ()
{
    menu                            # Show User some choices
    # Choices from menu ()
    if [[ "$WAT_DO" = MASTER ]]; then
        ACTION="of this "$WAT_DO" node:"    # Set IP node
        ip_check "$entry_ip"
        IP_HOST="$IP_ACTION"
        IP_MANAGER="$IP_HOST"
        echo "host $IP_HOST"
        echo "manager $IP_MANAGER"
    
    elif [[ "$WAT_DO" = MINION ]]; then
        ACTION="of this "$WAT_DO" node:"
        ip_check "$entry_ip"
        IP_HOST="$IP_ACTION"
        echo "host $IP_HOST"

        ACTION="of your Router or DHCP server:"
        ip_check "$entry_ip"
        IP_DHCP="$IP_ACTION"
        echo "dhcp $IP_DHCP"

        ACTION="of a Skywire manager."
        ip_check "$entry_ip"
        IP_MANAGER="$IP_ACTION"
        echo "manager $IP_MANAGER"
    fi
}
main