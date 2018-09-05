#!/bin/bash
IP_HOST=192.168.1.3
IP_ROUTER=192.168.0.1

network_wired ()
{
    local adapter=""
    local dhcp=0
    local choice_nw
    local router=""

    # Get wired adapter device name:
    adapter=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' \
            | sed 's/ //')

    read -p "Press 'z' to set a Static IP; press 'p' for DHCP/auto" choice_nw
    case "$choice_nw" in
        p|P ) dhcp=1;;
        z|Z ) echo "";;
        * ) network_wired;;
    esac

    touch /etc/network/interfaces.d/${adapter}

    if [[ dhcp = 0 ]]; then
        printf "auto "$adapter"\n`
        `allow-hotplug "$adapter"\n`
        `iface "$adapter" inet "$dhcp"\n`
        `  address "$IP_HOST"\n`
        `  netmask 255.255.255.0\n`
        `  gateway "$IP_ROUTER"\n`
        `  dns-nameservers "$IP_ROUTER"\n" \
        > /etc/network/interfaces.d/${adapter}
    else    # DHCP/auto networking:
        printf "auto "$adapter"\n`
        `allow-hotplug "$adapter"\n`
        `iface "$adapter" inet "$dhcp"\n" \
        > /etc/network/interfaces.d/${adapter}
    fi

    printf /etc/network/interfaces.d/${adapter} | sed 's/*//' /etc/network/interfaces
}
network_wired