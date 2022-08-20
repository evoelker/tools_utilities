#!/bin/bash

################################################################
# ubuntuDnsFix.sh
# Eryk Voelker
# evoelker81@yahoo.com
#
# This script fixes issues between Ubuntu Network Manager
# and the systemd-resoved DNS sub-systems and sets the correct
# DNS server IP addresses.
#
# v0.01 : Completed first write and testing
# v0.02 : Fixed issue with config location
# v0.03 : Updated /etc/systemd/resolved.conf file update method
# v0.04 : Updated to validate site switch.
#
#################################################################

# Declare / Set Variables
# Site DNS servers
MTV='8.8.8.8 8.8.4.4'
site=""

# Functions

# Help function
function show_help
{
    # Help/Usage
    echo -e -n "\tUsage: ubuntuDnsFix.sh [-MT]\n"
    echo -e -n "\tubuntuDnsFix.sh will update Ubuntu 18.04 LTS desktop DNS settings to IT standards.\n"
    echo -e -n "\tTo run ubuntuDnsFix.sh, you must specify you site with the correct site switch:\n\n"
    echo -e -n "\n"
    echo -e -n "\t\t-M\t\tMountain View Site (Terra Bella).\n"
    echo -e -n "\t\t-T\t\tTexas Site (Lancaster/Dallas).\n"
    echo -e -n "\n\n\t\t\tExample: ubuntuDnsFix.sh -M  --- tubuntuDnsFix.sh -T\n\n"
}

function main
{
    # Check if script is run as root
    if [[ $EUID -ne 0 ]]; then
        echo -e -n "\nThis script must be run as root. Re-run using sudo.\n\nExiting!"
        exit 1
    fi

	# Check for site switch
	if [[ -z "$site" ]]
	then
		echo -e -n "\nNo site switch was selected. Please rerun the script with the correct site switch.\n"
		echo -e -n "\t\t-M = MTV\n"
		echo -e -n "\nExiting\n\n"
		exit 1
	fi

    # Check for /etc/resov.conf symbolic link
    if [[ -L '/etc/resolv.conf' ]]
    then
        echo -e -n "\n'/etc/resolv.conf' is a symbolic link. Moving on to DNS configuration.\n"
    else
        echo -e -n "\n'/etc/resolv.conf' is a regular file. Backing up original and creating a symbolic link to '/run/systemd/resolve/stub-resolv.conf'.\n\n"

        # Backup file
        mv -f /etc/resolv.conf /etc/resolv.conf.bak

        # Create symbolic link
        sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

        echo -e -n "\nSymbolic created. Moving on to DNS configuration.\n"
    fi

    # Update /etc/systemd/resolved.conf
	cat > /etc/systemd/resolved.conf <<-EOF
	#  This file is part of systemd.
	#
	#  systemd is free software; you can redistribute it and/or modify it
	#  under the terms of the GNU Lesser General Public License as published by
	#  the Free Software Foundation; either version 2.1 of the License, or
	#  (at your option) any later version.
	#
	# Entries in this file show the compile time defaults.
	# You can change settings by editing this file.
	# Defaults can be restored by simply deleting this file.
	#
	# See resolved.conf(5) for details
	[Resolve]
	DNS=$site
	FallbackDNS=8.8.8.8 8.8.4.4
	#Domains=
	#LLMNR=no
	#MulticastDNS=no
	#DNSSEC=no
	Cache=no
	#DNSStubListener=yes
	EOF

    echo -e -n "Done!\n"

    # Restart systemd-resolved
    echo -e -n "\nRestarting DNS client..."
    sudo systemctl restart systemd-resolved
    echo -e -n "\nDone!"

    echo -e -n "\n\nAll changes have been completed. Exiting!\n"
}

# Collect command line options
while getopts "MT" opt;
do
    case $opt in
        M)
            # Seed operations
            site=$MTV
            ;;
        '?')
            show_help >&2
            exit 1
            ;;
    esac
done

main

#EOF
