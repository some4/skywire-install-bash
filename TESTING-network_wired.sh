#!/bin/bash
IP_HOST=192.168.1.1
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

net_interface_config ()
{
    local choice_nw=""
    local dhcp=0            # 1=yes,0=no
    read -p "Press 'z' to set a Static IP; press 'p' for DHCP/auto" choice_nw
    case "$choice_nw" in
        p|P ) dhcp=1;;
        z|Z ) echo "";;
        * ) net_interface_config;;
    esac

    local adapter=""        # Network device name
    local interfacesd=/etc/network/interfaces.d
    # Get 1st adapter name (not {lo,vir,wl}*):
    adapter=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' \
            | sed -n '1p' | sed 's/ //')    # 2p,3p,etc. for next devices
    touch ${interfacesd}/${adapter}

    local ip_dhcp=""
    if [[ "$dhcp" = 0 ]]; then
        # From ip_check: "Enter the IP address ...":
        ACTION="of your Router or DHCP server:"
        ip_check
        ip_dhcp="$IP_ACTION"    # Set DHCP address
        
        printf "auto "$adapter"\n`
        `allow-hotplug "$adapter"\n`
        `iface "$adapter" inet "$dhcp"\n`
        `  address "$IP_HOST"\n`
        `  netmask 255.255.255.0\n`
        `  gateway "$ip_dhcp"\n`
        `  dns-nameservers "$ip_dhcp"\n" \
        > "${interfacesd}/${adapter}"
    
    else    # DHCP/auto networking:
        printf "auto "$adapter"\n`
        `allow-hotplug "$adapter"\n`
        `iface "$adapter" inet dhcp" \
        > "${interfacesd}/${adapter}"
    fi
}
net_interface_config