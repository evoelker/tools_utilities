#!/bin/bash

##########################################
# ldapDataCollect.sh
# Eryk Voelker
# evoelker81@yahoo.com
#
# Script to pull OU's, Group's and User's from an LDAP directory
#
# v0.01 : Completed first write and testing
# v0.02 : Cleaned and optimized LDAP search
# v0.03 : Added user modification and enablement data set
# v0.04 : Cleaned up user/cli output
# v0.05 : Added show_help function
# v0.06 : Fixed selected option output (line 801)
# v0.07 : Update to use dynamically generated ldapSearch base DN
## #v0.XX : Add ldap test search to validate user creds
##########################################

# Declare / Set Variables
Start=0
End=0
TTime=0
rnum=`shuf -i 1-9999 -n 1` # Set random number
outDir="$HOME/ldapDataOut" # Script output directory
srcDomain="" # Long name for the source domain
sdnShort="" # Short name for the source domain
dstDomain="" # Long name for the destination domain
ddnShort="" # Short name for the destination domain
ldapSearchBase="" # LDAP search base
ldapSearchUser="" # LDAP search user account
ldapSearchStart="ldapsearch -L -c -E pr=2000/noprompt -o ldif-wrap=no -x -s sub" # LDAP search base command and options
ouOutFile="" # Set OU output file
groupOutFile="" # Set group output file
userOutFile="" # Set user output file
groupMbrOutFile="" # Set memberOf output file

# Declare Arrays
declare -a exclOUs
declare -a exclGroups
declare -a exclUsers
declare -a exclLdap

# Build excluded OU array - Default AD OU's
exclOUs[0]="# Computers"
exclOUs[1]="# Domain Controllers"
exclOUs[2]="# ForeignSecurityPrincipals"
exclOUs[3]="# LostAndFound"
exclOUs[4]="# NTDS Quotas"
exclOUs[5]="# Program Data"
exclOUs[6]="# Users"
exclOUs[7]=".*Builtin"

# Build excluded Group array - Default AD Group's
exclGroups[0]="# Access Control"
exclGroups[1]="# Authenticated Users"
exclGroups[2]="# Batch"
exclGroups[3]="# Allowed RODC"
exclGroups[4]="# Denied RODC"
exclGroups[5]="# Cert Server Admins"
exclGroups[6]="# Cert Requesters"
exclGroups[7]="# Cert Publishers"
exclGroups[8]="# Creator Group"
exclGroups[9]="# Cloneable Domain Controllers"
exclGroups[10]="# ConfigMgr Remote Control Users"
exclGroups[11]="# Dialup"
exclGroups[12]="# DnsAdmins"
exclGroups[13]="# DnsUpdateProxy"
exclGroups[14]="# Domain Admins"
exclGroups[15]="# Enterprise Admins"
exclGroups[16]="# Domain Computers"
exclGroups[17]="# Domain Controllers"
exclGroups[18]="# Domain Guests"
exclGroups[19]="# Domain Users"
exclGroups[20]="# Enterprise Controllers"
exclGroups[21]="# Everyone"
exclGroups[22]="# Group Policy Creator"
exclGroups[23]="# Interactive"
exclGroups[24]="# Network"
exclGroups[25]="# Power Users"
exclGroups[26]="# Protected Users"
exclGroups[27]="# RAS and IAS Servers"
exclGroups[28]="# Schema Admins"
exclGroups[29]="# Service"
exclGroups[30]="# WinRMRemoteWMIUsers"
exclGroups[31]="# Read-only Domain Controllers"
exclGroups[32]="# Enterprise Read-only Domain Controllers"
exclGroups[33]=".*Builtin"

# Build excluded User array - Default AD User's
exclUsers[0]="# Administrator"
exclUsers[1]="# Anonymous"
exclUsers[2]="# Creator"
exclUsers[3]="# Owner"
exclUsers[4]="# Guest"
exclUsers[5]="# KRBTGT"
exclUsers[6]="# krbtgt"
exclUsers[7]="# Local System"
exclUsers[8]="# Nobody"
exclUsers[9]="# Principal Self"
exclUsers[10]="# Self"

# # LDAP lines to remove
exclLdap[0]="version: 1"
exclLdap[1]="# search reference"
exclLdap[2]="# refldap"
exclLdap[3]="# control:"
exclLdap[4]="# LDAPv3"
exclLdap[5]="# base"
exclLdap[6]="# filter:"
exclLdap[7]="# requesting:"
exclLdap[8]="# with pagedResults"
exclLdap[9]='#$'
exclLdap[10]="# search result"
exclLdap[11]="# pagedresults"
exclLdap[12]="# numResponses"
exclLdap[13]="# numEntries"
exclLdap[14]="# numReferences"
exclLdap[14]='^$'

# Functions

# Help function
function show_help
{
     # Help/Usage
	echo -e -n "\tUsage: ldapDataCollect.sh [-SBAOGUME] [-s <Source Directory>] [-d <Destination Directory>] [-u <Full Qualified User Name] [-o <Path to Output Directory>]\n"
	echo -e -n "\tLdapDataCollect.sh will connect to the source LDAP directory, collect the selected data sets and prepare them for import into a second directory.\n"
	echo -e -n "\tLdapDataCollect.sh runs in two modes; Seed and Backup:\n\n"
     echo -e -n "\t\tSeed: Preps the data sets for import into a new LDAP directory specified with the [-d <Destination Domain>] option.\n\t\t-\n"
     echo -e -n "\t\tBackup: Preps the data set for re-import into the same or import into a 'clone' directory. [-d <Destination Domain>] is ignored.\n\n"
     echo -e -n "\tAll data sets are prepared for import into Windows Active Directory. Standard Windows Active Directory OU's, Group's and users are removed from the data sets\n"
     # echo -e -n "\t\tStandard Windows Active Directory OU's, Group's and users are removed from the data sets.\n"
	echo -e -n "\n\tCommand line options can be combined to create custom data sets.\n"
	echo -e -n "\n"
	echo -e -n "\t\t-S\t\tSeed Operations Mode.\n"
	echo -e -n "\t\t-B\t\tBackup Operations Mode.\n"
	echo -e -n "\t\t-A\t\tAll data sets will be retrieved and prepared in the selected operations mode.\n"
	echo -e -n "\t\t-O\t\tOU data set will be retrieved and prepared in the selected operations mode.\n"
	echo -e -n "\t\t-G\t\tGroup data set will be retrieved and prepared in the selected operations mode.\n"
	echo -e -n "\t\t-U\t\tUser data set will be retrieved and prepared in the selected operations mode.\n"
	echo -e -n "\t\t-M\t\tGroup membership data set will be retrieved and prepared in the selected operations mode.\n"
     echo -e -n "\t\t-E\t\tData needed to enable user accounts will be retrieved and prepared in the selected operations mode.\n"
	echo -e -n "\t\t-s\t\tFQDN of Source Directory\n"
	echo -e -n "\t\t-d\t\tFQDN of Destination Directory\n"
	echo -e -n "\t\t-u\t\tFull Qualified User Name: administrator@tailspin.com\n"
	echo -e -n "\t\t-O\t\tLDAP Dataset Output Directory. Default: ${outDir}\n"
     echo -e -n "\n\n\t\t\tExample: ldapDataCollect.sh -S -A -s tailspin.com -d tailspin.com -u eryk@tailspin.com\n\n"
}

### ldif Cleanup
# Clean up standard/default objects in provided ldif files
function stdObjectClean
{
     # Take array and file as parameters and clean file
     if [ -f $1 ]
     then
          workFile="${1}"
          local tmpArr=("$@")
          if [ $tmpArr ]
          then
               # Log
               echo -e -n "\nRemoving standard/default objects from ${workFile} \nPlease wait..."
               for rmObject in "${@:2}"
               do
                    sed --in-place -re "/^$rmObject.*$/,/^$/d" ${workFile}
               done
               # Log
               echo -e -n "\t...Done!\n"
          fi
     fi
}

# Add 'changetype=<action>' after 'dn'
function addChangeType
{
     # Take changetype and file action from parameter and update file - add/modify/remove
     if [ ! -z "${1}" ]
     then
          if [ ! -z "${2}" ]
          then
               if [ -f "${3}" ]
               then
                    ## Log
                    echo -e -n "\n\nInserting changetype: $2 \nPlease wait..."
                    sed --in-place -re "/$1/a changetype: $2" $3
                    echo -e -n "\t...Done!\n"

                    if [ "${2}" = "modify" ]
                    then
                         echo -e -n "\n\nInserting changetype method: ${4} \nPlease wait..."
                         sed --in-place -re "/^changetype/a $4" $3
                         echo -e -n "\t...Done!\n"
                    fi
               fi
          fi
     fi
}

# Update LDAP objects with new domain DN
function updateDN
{
     # Replace the src domain DN with the dst domain
     srcDN=""
     dstDN=""
     # Get old DN
     srcDomainSplit=(${srcDomain//./ })
     for dn in "${srcDomainSplit[@]}"
     do
          srcDN+=",DC=${dn}"
     done
     # Create new DN
     dstDomainSplit=(${dstDomain//./ })
     for dn in "${dstDomainSplit[@]}"
     do
          dstDN+=",DC=${dn}"
     done

     # Variable Cleanup
     srcDN=${srcDN#?}
     dstDN=${dstDN#?}

     # Search for old DN and replace it with new DN
     # Log
     echo -e -n "\n\nUpdating LDAP object DN to: ${dstDN} \nPlease wait..."
     sed --in-place -re "s/$srcDN/$dstDN/g" $1
     echo -e -n "\t...Done!\n"
     # Update msSFU30NisDomain
     if [ "${2}" = "msSFU30" ]
     then
          echo -e -n "\n\nUpdating LDAP object msSFU30NisDomain attrabutes to: ${ddnShort} \nPlease wait..."
          sed --in-place -re "s/^msSFU30NisDomain: $sdnShort/msSFU30NisDomain: $ddnShort/g" $1
          echo -e -n "\t...Done!\n"
     fi
}

### LDAP Search
# LDAP OU's search
function ldapOuSearch
{
     # Set output file
     ouOutFile="${outDir}/ou.${sdnShort}.`date +"%m.%d.%y"`.ldif" # Set OU output file
     # Set backup
     if [ "${opMode}" = "backup" ]
     then
           ouOutFile+=.bak
     fi

     # Check for existing out put and rename it
     if [ -f ${ouOutFile} ]
     then
          # Move old file to .old
          echo -e -n "\nLDAP OU output file exists.\nMoving ${ouOutFile} to ${ouOutFile}.old.${rnum}"
          mv ${ouOutFile} ${ouOutFile}.old.${rnum}
          echo -e -n "\nCreating new LDAP data file: ${ouOutFile}"
          touch ${ouOutFile}
     else
          # Log
          echo -e -n "\nLDAP data file doesn't exist. Creating LDAP data file: ${ouOutFile}"
          touch ${ouOutFile}
     fi

     # Log
     echo -e -n "\n\nCollecting OU data from source LDAP directory: ${srcDomain}\nPlease wait..."
     # LDAP search for user accounts
     ldapsearch -L -c -E pr=2000/noprompt -o ldif-wrap=no -x -s sub -h "${srcDomain}" -b ${ldapSearchBase} -D ${ldapSearchUser} -w ${srcDomainPasswd} "(objectCategory=organizationalUnit)" \
     name \
     ou \
     dn \
     distinguishedName \
     objectClass \
     objectCategory \
     >> ${ouOutFile}

     # Wait for command to complete
     sleep 5
     # Log
     echo -e -n "\t...Done!\n"
}

# LDAP Group's search
function ldapGroupSearch
{
     # Set output file
     groupOutFile="${outDir}/group.${sdnShort}.`date +"%m.%d.%y"`.ldif" # Set group output file
     # Set backup
     if [ "${opMode}" = "backup" ]
     then
           groupOutFile+=.bak
     fi

     # Check for existing out put and rename it
     if [ -f ${groupOutFile} ]
     then
          # Move old file to .old
          echo -e -n "\nLDAP Group output file exists.\nMoving ${groupOutFile} to ${groupOutFile}.old.${rnum}"
          mv ${groupOutFile} ${groupOutFile}.old.${rnum}
          echo -e -n "\nCreating new LDAP data file: ${groupOutFile}"
          touch ${groupOutFile}
     else
          # Log
          echo -e -n "\nLDAP data file doesn't exist. Creating LDAP data file: ${groupOutFile}"
          touch ${groupOutFile}
     fi

     # Log
     echo -e -n "\n\nCollecting Group data from source LDAP directory: ${srcDomain}\nPlease wait..."
     # LDAP search for user accounts
     ldapsearch -L -c -E pr=2000/noprompt -o ldif-wrap=no -x -s sub -h ${srcDomain} -b ${ldapSearchBase} -D ${ldapSearchUser} -w ${srcDomainPasswd} "(objectCategory=group)" \
     name \
     dn \
     distinguishedName \
     cn \
     description \
     sAMAccountName \
     objectCategory \
     objectClass \
     msSFU30Name \
     msSFU30NisDomain \
     gidNumber \
     memberUid \
     >> ${groupOutFile}

     # Wait for command to complete
     sleep 5
     # Log
     echo -e -n "\t...Done!\n"
}

# LDAP User's search
function ldapUserSearch
{
     # Set output file
     userOutFile="${outDir}/user.${sdnShort}.`date +"%m.%d.%y"`.ldif" # Set user output file
     # Set backup
     if [ "${opMode}" = "backup" ]
     then
           userOutFile+=.bak
     fi

     # Check for existing out put and rename it
     if [ -f ${userOutFile} ]
     then
          # Move old file to .old
          echo -e -n "\nLDAP User output file exists.\nMoving ${userOutFile} to ${userOutFile}.old.${rnum}"
          mv ${userOutFile} ${userOutFile}.old.${rnum}
          echo -e -n "\nCreating new LDAP data file: ${userOutFile}"
          touch ${userOutFile}
     else
          # Log
          echo -e -n "\nLDAP data file doesn't exist. Creating LDAP data file: ${userOutFile}"
          touch ${userOutFile}
     fi

     # Log
     echo -e -n "\n\nCollecting User data from source LDAP directory: ${srcDomain}\nPlease wait..."
     # LDAP search for user accounts
     ldapsearch -L -c -E pr=2000/noprompt -o ldif-wrap=no -x -s sub -h ${srcDomain} -b ${ldapSearchBase} -D ${ldapSearchUser} -w ${srcDomainPasswd} "(&(objectCategory=Person) (objectClass=user))" \
     name \
     dn \
     distinguishedName \
     description \
     userPrincipalName \
     givenname \
     cn \
     sn \
     mail \
     sAMAccountName \
     instanceType \
     objectCategory \
     objectClass \
     uid \
     msSFU30Name \
     msSFU30NisDomain \
     uidNumber \
     gidNumber \
     unixHomeDirectory \
     loginShell \
     >> ${userOutFile}

     # Wait for command to complete
     sleep 5
     # Log
     echo -e -n "\t...Done!\n"
}

# LDAP Member's search
function ldapGroupMbrSearch
{
     # Set output file
     groupMbrOutFile="${outDir}/member.${sdnShort}.`date +"%m.%d.%y"`.ldif" # Set memberOf output file
     # Set backup
     if [ "${opMode}" = "backup" ]
     then
           groupMbrOutFile+=.bak
     fi

     # Check for existing out put and rename it
     if [ -f ${groupMbrOutFile} ]
     then
          # Move old file to .old
          echo -e -n "\nLDAP Group Membership output file exists.\nMoving ${groupMbrOutFile} to ${groupMbrOutFile}.old.${rnum}"
          mv ${groupMbrOutFile} ${groupMbrOutFile}.old.${rnum}
          echo -e -n "\nCreating new LDAP data file: ${groupMbrOutFile}"
          touch ${groupMbrOutFile}
     else
          # Log
          echo -e -n "\nLDAP data file doesn't exist. Creating LDAP data file: ${groupMbrOutFile}"
          touch ${groupMbrOutFile}
     fi

     # Log
     echo -e -n "\n\nCollecting Membership data from source LDAP directory: ${srcDomain}\nPlease wait..."
     # LDAP search for user accounts
     ldapsearch -L -c -E pr=2000/noprompt -o ldif-wrap=no -x -s sub -h ${srcDomain} -b ${ldapSearchBase} -D ${ldapSearchUser} -w ${srcDomainPasswd} "(&(objectCategory=group) (member=*))" \
     dn \
     member \
     >> ${groupMbrOutFile}

     # Wait for command to complete
     sleep 5
     # Log
     echo -e -n "\t...Done!\n"
}

# LDAP Modify/Update User search
function ldapUserModSearch
{
     # Set output file
     userModOutFile="${outDir}/userMod.${sdnShort}.`date +"%m.%d.%y"`.ldif" # Set user output file
     # Set backup
     if [ "${opMode}" = "backup" ]
     then
           userModOutFile+=.bak
     fi

     # Check for existing out put and rename it
     if [ -f ${userModOutFile} ]
     then
          # Move old file to .old
          echo -e -n "\nLDAP User Modification output file exists.\nMoving ${userModOutFile} to ${userModOutFile}.old.${rnum}"
          mv ${userModOutFile} ${userModOutFile}.old.${rnum}
          echo -e -n "\nCreating new LDAP data file: ${userModOutFile}"
          touch ${userModOutFile}
     else
          # Log
          echo -e -n "\nLDAP data file doesn't exist. Creating LDAP data file: ${userModOutFile}"
          touch ${userModOutFile}
     fi

     # Log
     echo -e -n "\n\nCollecting data for user being modified from source LDAP directory: ${srcDomain}\nPlease wait..."
     # LDAP search for user accounts
     ldapsearch -L -c -E pr=10000/noprompt -o ldif-wrap=no -x -s sub -h ${srcDomain} -b ${ldapSearchBase} -D ${ldapSearchUser} -w ${srcDomainPasswd} "(&(objectCategory=Person) (objectClass=user))" \
     dn \
     >> ${userModOutFile}

     # Wait for command to complete
     sleep 5
     # Log
     echo -e -n "\t...Done!\n"
}

### OU's prep functions
# Seed
function ldapOuPrepSeed
{
     # Log
     echo -e -n "\n\n==================== Starting OU Data Collection and Prep ====================\n\n"
     # Collect OU date from src domain
     ldapOuSearch

     # Check for ldif file
     if [ -f ${ouOutFile} ]
     then
          # Log
          echo -e -n "\nStarting OU ldif seed prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${ouOutFile}" "${exclOUs[@]}"
          # Add ldif changetype - add
          addChangeType "dn: OU=" "add" "${ouOutFile}"
          # Update DN to new domain
          updateDN "${ouOutFile}"
          # Log
          echo -e -n "\nOU ldif seed prep complete!\n\n"
     else
          echo -e -n "\nOU ldif file not found. Skipping...\n\n"
          break
     fi
}

# Backup
function ldapOuPrepBackup
{
     # Log
     echo -e -n "\n\n==================== Starting OU Data Collection and Prep ====================\n\n"
     # Collect OU date from src domain
     ldapOuSearch

     # Check for ldif file
     if [ -f ${ouOutFile} ]
     then
          # Log
          echo -e -n "\nStarting OU ldif backup prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${ouOutFile}" "${exclOUs[@]}"
          # Add ldif changetype - add
          addChangeType "dn: OU=" "add" "${ouOutFile}"
          # Log
          echo -e -n "\nOU ldif backup prep complete!\n\n"
     else
          echo -e -n "\nOU ldif file not found. Skipping...\n\n"
          break
     fi
}

### Group's prep functions
# Seed
function ldapGroupPrepSeed
{
     # Log
     echo -e -n "\n\n==================== Starting Group Data Collection and Prep ====================\n\n"

     # Collect Group date from src domain
     ldapGroupSearch

     # Check for ldif file
     if [ -f ${groupOutFile} ]
     then
          # Log
          echo -e -n "\nStarting Group ldif seed prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${groupOutFile}" "${exclGroups[@]}"
          # Add ldif changetype - add
          addChangeType "dn: CN" "add" "${groupOutFile}"
          # Update DN to new domain
          updateDN "${groupOutFile}" "msSFU30"
          # Log
          echo -e -n "\nGroup ldif seed prep complete!\n\n"
     else
          echo -e -n "\nGroup ldif file not found. Skipping...\n\n"
          break
     fi
}

# Backup
function ldapGroupPrepBackup
{
     # Log
     echo -e -n "\n\n==================== Starting Group Data Collection and Prep ====================\n\n"

     # Collect Group date from src domain
     ldapGroupSearch

     # Check for ldif file
     if [ -f ${groupOutFile} ]
     then
          # Log
          echo -e -n "\nStarting Group ldif backup prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${groupOutFile}" "${exclGroups[@]}"
          # Add ldif changetype - add
          addChangeType "dn: CN" "add" "${groupOutFile}"
          # Log
          echo -e -n "\nGroup ldif backup prep complete!\n\n"
     else
          echo -e -n "\nGroup ldif file not found. Skipping...\n\n"
          break
     fi
}

### User's prep functions
# Seed
function ldapUserPrepSeed
{
     # Log
     echo -e -n "\n\n==================== Starting User Data Collection and Prep ====================\n\n"

     # Collect User date from src domain - Only DN
     ldapUserSearch

     # Check for ldif file
     if [ -f ${userOutFile} ]
     then
          # Log
          echo -e -n "\nStarting User ldif seed prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${userOutFile}" "${exclUsers[@]}"
          # Add ldif changetype - add
          addChangeType "dn: CN=" "add" "${userOutFile}"
          # Update DN to new domain
          updateDN "${userOutFile}" "msSFU30"
          # Log
          echo -e -n "\nUser ldif seed prep complete!\n\n"
     else
          echo -e -n "\nUser ldif file not found. Skipping...\n\n"
          break
     fi
}

# Backup
function ldapUserPrepBackup
{
     # Log
     echo -e -n "\n\n==================== Starting User Data Collection and Prep ====================\n\n"

     # Collect User date from src domain
     ldapUserSearch

     # Check for ldif file
     if [ -f ${userOutFile} ]
     then
          # Log
          echo -e -n "\nStarting User ldif backup prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${userOutFile}" "${exclUsers[@]}"
          # Add ldif changetype - add
          addChangeType "dn: CN=" "add" "${userOutFile}"
          # Update DN to new domain
          # updateDN "${userOutFile}" "msSFU30"
          # Log
          echo -e -n "\nUser ldif backup prep complete!\n\n"
     else
          echo -e -n "\nUser ldif file not found. Skipping...\n\n"
          break
     fi
}

### Member's prep functions
# Seed
function ldapGroupMbrPrepSeed
{
     # Log
     echo -e -n "\n\n==================== Starting Group Membership Data Collection and Prep ====================\n\n"

     # Collect MemberOf date from src domain
     ldapGroupMbrSearch

     # Check for ldif file
     if [ -f ${groupMbrOutFile} ]
     then
          # Log
          echo -e -n "\nStarting MemberOf ldif seed prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${groupMbrOutFile}" "${exclGroups[@]}"
          # Add ldif changetype - modify
          addChangeType "dn: CN=" "modify" "${groupMbrOutFile}" "add: member"
          # Update DN to new domain
          updateDN "${groupMbrOutFile}"
          # Remove all the LDAP control data
          for misText in "${exclLdap[@]}"
          do
               sed --in-place -re "/^${misText}.*/d" ${groupMbrOutFile}
          done
          sed --in-place -re "/^#/i \
          -\n" ${groupMbrOutFile}
          sed --in-place -re '1,2d' ${groupMbrOutFile}
          # Log
          echo -e -n "\nMemberOf ldif seed prep complete!\n\n"
     else
          echo -e -n "\nMemberof ldif file not found. Skipping...\n\n"
          break
     fi
}

# Backup
function ldapGroupMbrPrepBackup
{
     # Log
     echo -e -n "\n\n==================== Starting Group Membership Data Collection and Prep ====================\n\n"

     # Collect MemberOf date from src domain
     ldapGroupMbrSearch

     # Check for ldif file
     if [ -f ${groupMbrOutFile} ]
     then
          # Log
          echo -e -n "\nStarting MemberOf ldif backup prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${groupMbrOutFile}" "${exclGroups[@]}"
          # Add ldif changetype - modify
          addChangeType "dn: CN=" "modify" "${groupMbrOutFile}" "add: member"
          # Update DN to new domain
          # updateDN "${groupMbrOutFile}"
          # Remove all the LDAP control data
          for misText in "${exclLdap[@]}"
          do
               sed --in-place -re "/^${misText}.*/d" ${groupMbrOutFile}
          done
          sed --in-place -re "/^#/i \
          -\n" ${groupMbrOutFile}
          sed --in-place -re '1,2d' ${groupMbrOutFile}
          # Log
          echo -e -n "\nMemberOf ldif backup prep complete!\n\n"
     else
          echo -e -n "\nMemberof ldif file not found. Skipping...\n\n"
          break
     fi
}

### User Maintenance
# Seed
function ldapUserModPrepSeed
{
     # Log
     echo -e -n "\n\n==================== Starting User Modification Data Collection and Prep ====================\n\n"

     # Collect User date from src domain
     ldapUserModSearch

     # Check for ldif file
     if [ -f ${userModOutFile} ]
     then
          # Log
          echo -e -n "\nStarting User modification ldif seed prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${userModOutFile}" "${exclUsers[@]}"
          # Add ldif changetype - add
          # addChangeType "dn: CN=" "modify" "${userModOutFile}" "replace: unicodePwd"
          # Update DN to new domain
          updateDN "${userModOutFile}"
          # Remove accounts in 'disabled OU's'
          sed --in-place -re "/.*End-Of-Contract.*/,+2d" ${userModOutFile}
          sed --in-place -re "/.*Disabled Users.*/,+2d" ${userModOutFile}
          sed --in-place -re "/.*Temp Admin Accounts.*/,+2d" ${userModOutFile}
          # Remove all the LDAP control data
          for misText in "${exclLdap[@]}"
          do
               sed --in-place -re "/^${misText}.*/d" ${userModOutFile}
          done
          sed --in-place -re "/^#/i \
          -\n" ${userModOutFile}
          sed --in-place -re '1,2d' ${userModOutFile}
          # Add 'modify' section to the end of each object
          sed --in-place -re "/^dn: CN=/a changetype: modify\nreplace: unicodePwd\nunicodePwd::IgBQAGEAJAAkAHcAMAByAGQAKQApACIA\n-\nreplace: msSFU30NisDomain\nmsSFU30NisDomain: ${ddnShort}\n-\nreplace: userAccountControl\nuserAccountControl: 66048" ${userModOutFile}
          # Log
          echo -e -n "\nUser modificatoin ldif seed prep complete!\n\n"
     else
          echo -e -n "\nUser modificatoin ldif file not found. Skipping...\n\n"
          break
     fi
}

# Backup
function ldapUserModPrepBack
{
     # Log
     echo -e -n "\n\n==================== Starting User Modification Data Collection and Prep ====================\n\n"

     # Collect User date from src domain
     ldapUserModSearch

     # Check for ldif file
     if [ -f ${userModOutFile} ]
     then
          # Log
          echo -e -n "\nStarting User modification ldif backup prep.\n"
          # Remove standard/default OU's
          stdObjectClean "${userModOutFile}" "${exclUsers[@]}"
          # Add ldif changetype - add
          # addChangeType "dn: CN=" "modify" "${userModOutFile}" "replace: unicodePwd"
          # Update DN to new domain
          # updateDN "${userModOutFile}"
          # Remove accounts in 'disabled OU's'
          sed --in-place -re "/.*End-Of-Contract.*/,+2d" ${userModOutFile}
          sed --in-place -re "/.*Disabled Users.*/,+2d" ${userModOutFile}
          sed --in-place -re "/.*Temp Admin Accounts.*/,+2d" ${userModOutFile}
          # Remove all the LDAP control data
          for misText in "${exclLdap[@]}"
          do
               sed --in-place -re "/^${misText}.*/d" ${userModOutFile}
          done
          sed --in-place -re "/^#/i \
          -\n" ${userModOutFile}
          sed --in-place -re '1,2d' ${userModOutFile}
          # Add 'modify' section to the end of each object
          sed --in-place -re "/^dn: CN=/a changetype: modify\nreplace: unicodePwd\nunicodePwd::IgBQAGEAJAAkAHcAMAByAGQAKQApACIA\n-\nreplace: msSFU30NisDomain\nmsSFU30NisDomain: ${sdnShort}\n-\nreplace: userAccountControl\nuserAccountControl: 66048" ${userModOutFile}
          # Log
          echo -e -n "\nUser modificatoin ldif backup prep complete!\n\n"
     else
          echo -e -n "\nUser modificatoin ldif file not found. Skipping...\n\n"
          break
     fi
}

# Main
function main
{
     # Set Variables
     sdnShort=`echo ${srcDomain} | cut -d"." -f 1` # Short name for the source domain
     ddnShort=`echo ${dstDomain} | cut -d"." -f 1` # Short name for the destination domain
	ldapSearchBase=`echo "dc=${srcDomain}" | sed 's/\./,dc=/g'`

     # Verify user imput
     if [[ -z ${opMode} ]]
     then
          echo -e -n "\n\tNo operation mode selected. Please review usage.\n\n"
     	show_help
     	echo -e -n "Exiting!\n\n"
     	exit 1
     else
          # Log
          echo -e -n "\nThe following LDAP tasks will be run in operational mode: ${opMode}: \n"
          for tasks in "${opSelect[@]}"
          do
               echo -e -n "\n${tasks}\n"
          done
          # Get users password
          echo -e -n "\nTo read all properties, you must be a domain admin in the source domain.\n\n"
          read -p "Enter Source LDAP Directory Password: " -s srcDomainPasswd
          # Create output directory - domain short name + `date +"%m.%d.%y"`
          if [ ! -d ${outDir} ]
          then
               mkdir ${outDir}
          fi
          # Start task loop
          # Get Start Time
		Start=$(date +%s)
          for task in "${opTasks[@]}"
          do
               $task
          done
          # Get end time
		End=$(date +%s)
          # Log
          echo -e -n "\n#################### All tasks complete! ####################\n\n"
     fi
}

# Collect command line options
while getopts "SBAOGUMEs:d:u:o:" opt;
do
     case $opt in
          S)
               # Seed operations
               opMode="seed"
               ;;
          B)
               # Backup operaitions
               opMode="backup"
               ;;
          A)
               # Prep all files
               opSelect+="All LDAP directory objects will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks=(ldapOuPrepSeed ldapGroupPrepSeed ldapUserPrepSeed ldapUserModPrepSeed ldapGroupMbrPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks=(ldapOuPrepBackup ldapGroupPrepBackup ldapUserPrepBackup ldapUserModPrepBack ldapGroupMbrPrepBackup)
               fi
               ;;
          O)
               # Prep OU file
               opSelect+="LDAP OU's from source domain will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks+=(ldapOuPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks+=(ldapOuPrepBackup)
               fi
               ;;
          G)
               # Prep group file
               opSelect+="LDAP group's from source domain will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks+=(ldapGroupPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks+=(ldapGroupPrepBackup)
               fi
               ;;
          U)
               # Prep user file
               opSelect+="LDAP user's from source domain will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks+=(ldapUserPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks+=(ldapUserPrepBackup)
               fi
               ;;
          M)
               # Prep memberOf file
               opSelect+="LDAP group member's from source domain will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks+=(ldapGroupMbrPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks+=(ldapGroupMbrPrepBackup)
               fi
               ;;
          E)
               # Prep user mod file
               opSelect+="LDAP users modification data from source domain will be prepped for $opMode.\n"
               if [ "${opMode}" = "seed" ]
               then
                    opTasks+=(ldapUserModPrepSeed)
               elif [ "${opMode}" = "backup" ]
               then
                    opTasks+=(ldapUserModPrepBack)
               fi
               ;;
          s)
               # Get srcDomain
               srcDomain=$OPTARG
               ;;
          d)
               # Get dstDomain
               dstDomain=$OPTARG
               ;;
          u)
               # Get username
               ldapSearchUser=$OPTARG
               ;;
          o)
               # Output file location
               outDir=$OPTARG
               ;;
          '?')
               show_help >&2
               exit 1
               ;;
     esac
done

# Main
main
