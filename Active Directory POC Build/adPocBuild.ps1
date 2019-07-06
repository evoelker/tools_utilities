#########################################################################################
# adPocSeed.ps1
# Eryk Voelker 10/2018
# evoelker81@yahoo.com
#
# This script will prep and seed Windows Active Directory Domains.
#
# v0.1 : First write and test
# v0.2 : Add sdtout logging
# v0.3 : Add script description and comments
# v0.4 : Script testing, cleanup and finalized for release
## #v0.xx : Add delegated permissions (users & groups)
## #v0.xx : Add GPO objects and link locations
##########################################################################################

# Script Description

<#
.SYNOPSIS
This script will prep and seed Windows Active Directory Domains with provided datasets.

.DESCRIPTION
This script will the following:
  1. Configure and prep the POC Windows Domain Controller:
     a: Configure Windows Time Service
     b: Disable IPv6 tunnels
     c: Install Directory Services for Unix
  2. Create the POC Domain
     a: Promote the domain controller
     b: Create the POC forest zone
     c: Configure the directory restore password
  3. Seed POC domain with source directory data
     a: Import OU's
     b: Import Group's
     c: Import User's
     d: Import MemberOf's
     e: Import User Configuration Data

.PARAMETER B
Sets the script to 'Build' mode.

.PARAMETER S
Sets the script to 'Seed' mode.

.PARAMETER P
Used with [-B] to promote the local host to a POC domain controller.

.PARAMETER A
Used with [-S] to seed the POC domain with all datasets: OU's, Group's, User's, Membership and User Modification Data.

.PARAMETER O
Used with [-S] to seed POC domain with OU dataset.

.PARAMETER G
Used with [-S] to seed POC domain with Group dataset.

.PARAMETER U
Used with [-S] to seed POC domain with User dataset.

.PARAMETER M
Used with [-S] to seed POC domain with Membership dataset.

.PARAMETER E
Used with [-S] to seed POC domain with user modification dataset.

.PARAMETER d
Used with the [B] and [-S] to set the destination FQDN POC domain name.

.PARAMETER f
Used with [-S] to set the source file location.

.PARAMETER AdminPass
Used with [-S] to set the 'Administrators' password to something other than the default.

.PARAMETER Continue
Used with [-S] to set the date import prompt responses.

.NOTES

.EXAMPLE

.\adPocSeed.ps1 -B -d <FQDN domain name> -f <seed file location>
Prepare host to be a POC domain controller.

.\adPocSeed.ps1 -B -d poc05.local.net -f C:\Users\Administrator\Desktop\SeedData\POC05

.EXAMPLE

.\adPocSeed.ps1 -B -P -d <FQDN domain name> -f <seed file location>
Promote host to POC domain controller.

.\adPocSeed.ps1 -B -P -d poc05.local.net -f C:\Users\Administrator\Desktop\SeedData\POC05

.EXAMPLE

.\adPocSeed.ps1 -S -A -d <FQDN domain name> -f <seed file location> -Continue yes
Import all seed data sets without prompting for confirmation.

.\adPocSeed.ps1 -S -A -d poc05.local.net -f C:\Users\Administrator\Desktop\SeedData\POC05 -Continue yes

#>

# Set Parameters

param (
     [Parameter()]
     [alias("B")]
     [switch]$script:scrpModeB = $false, # Script mode - Build POC domain

     [Parameter()]
     [alias("S")]
     [switch]$script:scrpModeS = $false, # Script mode - Seed POC domain

     [Parameter()]
     [alias("P")]
     [switch]$script:scrpTasksP = $false, # Script mode - Promote domain controller

     [Parameter()]
     [alias("A")]
     [switch]$script:seedTasksA = $false, # Script mode - Seed POC domain with all datasets

     [Parameter()]
     [alias("O")]
     [switch]$script:seedTasksO = $false, # Script mode - Seed POC domain with OU datasets

     [Parameter()]
     [alias("G")]
     [switch]$script:seedTasksG = $false, # Script mode - Seed POC domain with group datasets

     [Parameter()]
     [alias("U")]
     [switch]$script:seedTasksU = $false, # Script mode - Seed POC domain with user datasets

     [Parameter()]
     [alias("M")]
     [switch]$script:seedTasksM = $false, # Script mode - Seed POC domain with member datasets

     [Parameter()]
     [alias("E")]
     [switch]$script:seedTasksE = $false, # Script mode - Seed POC domain with datasets needed to enable users

     [Parameter(Mandatory)]
     [alias("d")]
     [string]$script:dstDomain = $null, # Destination POC Domain

     [Parameter()]
     [alias("f")]
     [string]$script:srcDir = $null, # Directory with the source domain seed files

     [Parameter()]
     [alias("AdminPass")]
     [string]$script:adminPass = 'Pa$$w0rd))', # Default value

     [Parameter()]
     [ValidateSet("yes", "no")]
     [alias("Continue")]
     [string]$promptAction = "no" # Default value
)

# Set execute location to script directory
$scriptPath = Split-Path $MyInvocation.MyCommand.Path
Push-Location -Path $scriptPath

# Variables
# Set script date
$date = (Get-Date -Format "MM-dd-yyyy")
#Set Script time
$sTime = (Get-Date -Format "HH:mm:ss")
# Set file base
$fileBase = "adPocSeed.$(Get-Date -Format 'yyyy.MM.dd.fffff')"
# Set log file location
$logFile = ".\$fileBase\$logFile"

# Arrays
# LDAP Build Files
$pocBuildFiles = @()
$pocBuildFiles += "ou"
$pocBuildFiles += "group"
$pocBuildFiles += "user"
$pocBuildFiles += "member"
$pocBuildFiles += "userMod"
# NTP Server IP Address
$ntpIpAddr = ("")

# Functions

# Show help
function showHelp
{
     Get-Help .\adPocSeed.ps1 -Full
     return
}

function Sleep-Progress
{
     <#
     .SYNOPSIS
     Function to Start-Sleep with a progress bar

     .DESCRIPTION
     Runs the 'Start-Sleep' command using the with a progress bar. Time is passed to the function in seconds as an argument.

     .NOTES
     # Updated from original to include the 'Wait time' in minutes and seconds

     .EXAMPLE
     Sleep-Progress 300

     .LINK
     https://gist.github.com/evoelker/fcd8dc1563e15a6f8e5e11fdd93880cf
     https://gist.github.com/ctigeek/bd637eeaeeb71c5b17f4

     #>

     param (
        [Parameter(Mandatory)]
        [int]$Seconds

     )

     $doneDT = (Get-Date).AddSeconds($Seconds)
     while($doneDT -gt (Get-Date)) {
         $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
         $percent = ($Seconds - $secondsLeft) / $Seconds * 100
         Write-Progress -Activity "Waiting $($([timespan]::fromseconds($Seconds)).ToString("mm\:ss")) minutes ..." -Status "Waiting..." -SecondsRemaining $secondsLeft -PercentComplete $percent
         [System.Threading.Thread]::Sleep(500)
     }
     Write-Progress -Activity "Waiting $($([timespan]::fromseconds($Seconds)).ToString("mm\:ss")) minutes ..." -Status "Waiting..." -SecondsRemaining 0 -Completed
}

# Verify all source files
function verifyFiles
{
     # Set Variables
     $errorCode = 0

     # Check source directory for seed files
     foreach ( $sFile in $pocBuildFiles )
     {
          if ( !(Test-Path -Path $(Resolve-Path "$script:srcDir\$sFile.*.ldif")) )
          {
               # Set error code
               write-host "$sFile"
               $errorCode += 1
          }
     }

     # Return code
     if ( $errorCode -eq 0 )
     {
          return "True"
     }
     else
     {
          return "False"
     }
}

# Verify POC domain is functional
function verifyDomain
{
     # Set Variables
     $errorCode = 0

     # Load AD PowerShell Module
     if (!(Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue))
     {
          try { Import-Module ActiveDirectory -ErrorAction SilentlyContinue }
          catch { Write-Host "Unable to load ActiveDirectory PowerShell modlue, exiting!" -ForegroundColor Red; exit }
     }

     # Connect to the POC domain and search for 'Administrator'
     try { Get-ADUser -Server $script:dstDomain -Identity Administrator | Out-Null }
     catch { $errorCode += 1 }

     # Return code
     if ( $errorCode -eq 0 )
     {
          return "True"
     }
     else
     {
          return "False"
     }
}

### Build POC Domain
# Set time servers
function setWinTime
{
     # Set Variables
     $errorCode = 0

     # Stop W32Time Services
     if ( (Get-Service -Name W32Time).Status -eq "Running" )
     {
          net stop W32Time
     }

     # Wait for time services to stop
     Start-Sleep 5

     # Configure time services
     try { w32tm /config /syncfromflags:manual /manualpeerlist:"172.30.19.1 172.30.17.1 172.30.18.1" | Out-Null }
     catch { $errorCode += 1 }

     # Start W32Time Services
     try { net start W32Time | Out-Null }
     catch { $errorCode += 1 }

     # Wait for time services to start
     Start-Sleep 5

     # Update W32Time Configurations
     try { w32tm /config /update | Out-Null }
     catch { $errorCode += 1 }

     # Sync Time
     try { w32tm /resync /nowait | Out-Null }
     catch { $errorCode += 1 }

     # Return code
     if ( $errorCode -eq 0 )
     {
          return "True"
     }
     else
     {
          return "False"
     }
}

# Disable IPv6 Tunnels
function ipTunnelDis
{
     # Set Variables
     $errorCode = 0

     # Disable 6to4 Tunnels
     try { Set-Net6to4Configuration -State Disabled | Out-Null }
     catch { $errorCode += 1 }

     # Disable Teredo Tunnels
     try { Set-NetTeredoConfiguration -Type Disabled | Out-Null }
     catch { $errorCode += 1 }

     # Disable ISATAP Tunnels
     try { Set-NetIsatapConfiguration -State Default | Out-Null }
     catch { $errorCode += 1 }

     # Return code
     if ( $errorCode -eq 0 )
     {
          return "True"
     }
     else
     {
          return "False"
     }
}

# Install Domain Services for Unix
function instUnixSrv
{
     # Set Variables
     $errorCode = 0

     # Enable AD Unix Services: adminui
     if ( $errorCode -eq 0 )
     {
          try { dism.exe /Online /Quiet /NoRestart /enable-feature /featurename:adminui /all | Out-Null }
          catch { $errorCode += 1 }
     }
     # Enable AD Unix Services: nis
     if ( $errorCode -eq 0 )
     {
          try { dism.exe /Online /Quiet /NoRestart /enable-feature /featurename:nis /all | Out-Null }
          catch { $errorCode += 1 }
     }
     # Enable AD Unix Services: psync
     if ( $errorCode -eq 0 )
     {
          try { dism.exe /Online /Quiet /NoRestart /enable-feature /featurename:psync /all | Out-Null }
          catch { $errorCode += 1 }
     }

     # Return code
     if ( $errorCode -eq 0 )
     {
          return "True"
     }
     else
     {
          return "False"
     }
}

# Create POC forest/domain and promote domain controller
function creatPocDomain
{
     # Create 'SecureString' for directory restore password
     $directoryRestorPsswd = convertto-securestring $script:adminPass -asplaintext -force

     # Load ADDSDeployment PowerShell Module
     if (!(Get-Module -Name ADDSDeployment -ErrorAction SilentlyContinue))
     {
          try { Import-Module ADDSDeployment -ErrorAction SilentlyContinue }
          catch { Write-Host "Unable to load ADDSDeployment PowerShell module, exiting!" -ForegroundColor Red; exit }
     }

     #Create domain and restart
     try
     { Install-ADDSForest `
          -CreateDnsDelegation:$false `
          -DatabasePath "C:\Windows\NTDS" `
          -DomainMode "Win2012R2" `
          -DomainName $($script:dstDomain) `
          -SafeModeAdministratorPassword $directoryRestorPsswd `
          -DomainNetbiosName $($script:dstDomain.ToUpper().split(".")[0]) `
          -ForestMode "Win2012R2" `
          -InstallDns:$true `
          -LogPath "C:\Windows\NTDS" `
          -NoRebootOnCompletion:$true `
          -SysvolPath "C:\Windows\SYSVOL" `
          -Force:$true
     }
     catch { $errorCode += 1 }

     # Return code
    if ( $errorCode -eq 0 )
    {
         return "True"
    }
    else
    {
         return "False"
    }
}

### Seed POC Domain
# Import OU's
function importOU
{
     # Set Variables
     $continue = $null
     $dataPath = $null
     $dataSet = "ou"

     # Verify user action
     if ( $promptAction -like "yes" )
     {
          $continue = "yes"
     }
     else
     {
          $continue = read-host "`n$(($dataSet).ToUpper()) datasets will be imported into $script:dstDomain. Would you like to continue? (Yes/No) "
     }


     # Import OU's
     if ( $continue -like "yes" )
     {
          # Build data file path
          $dataPath = Resolve-Path "$script:srcDir\$dataSet.*.ldif"

          # Import OU's
          write-host "`nStarting $dataSet data import.`nPlease wait..."  -NoNewline
          try { ldifde -i -k -h -s 127.0.0.1 -j $script:srcDir -b administrator $script:dstDomain $script:adminPass -f $dataPath }
          catch { $errorCode += 1 }
     }

     # Return code
    if ( $errorCode -eq 0 )
    {
         # Move log file
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         # Report
         write-host "`t...Done!"
         write-host "$($(Get-Content -Path $script:srcDir\$dataSet.ldif.log | Select-String entries)[1])"
         return "True"
    }
    else
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         Move-Item -Path $script:srcDir\ldif.err -Destination $script:srcDir\$dataSet.ldif.err -Force -Confirm:$false
         # Report
         write-host "`t...Import had issues. Check logs."
         write-host "Log Files:`n$script:srcDir\$dataSet.ldif.log`n$script:srcDir\dataSet.ldif.err"
         return "False"
    }
}

# Import Group's
function importGroup
{
     # Set Variables
     $continue = $null
     $dataPath = $null
     $dataSet = "group"

     # Verify user action
     if ( $promptAction -like "yes" )
     {
          $continue = "yes"
     }
     else
     {
          $continue = read-host "`n$((Get-Culture).TextInfo.ToTitleCase($dataSet)) datasets will be imported into $script:dstDomain. Would you like to continue? (Yes/No) "
     }

     # Import OU's
     if ( $continue -like "yes" )
     {
          # Build data file path
          $dataPath = Resolve-Path "$script:srcDir\$dataSet.*.ldif"

          # Import OU's
          write-host "`nStarting $dataSet data import.`nPlease wait..." -NoNewline
          try { ldifde -i -k -h -s 127.0.0.1 -j $script:srcDir -b administrator $script:dstDomain $script:adminPass -f $dataPath }
          catch { $errorCode += 1 }
     }

     # Return code
    if ( $errorCode -eq 0 )
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         # Report
         write-host "`t...Done!"
         write-host "$($(Get-Content -Path $script:srcDir\$dataSet.ldif.log | Select-String entries)[1])"
         return "True"
    }
    else
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         Move-Item -Path $script:srcDir\ldif.err -Destination $script:srcDir\$dataSet.ldif.err -Force -Confirm:$false
         # Report
         write-host "`t...Import had issues. Check logs."
         write-host "Log Files:`n$script:srcDir\$dataSet.ldif.log`n$script:srcDir\dataSet.ldif.err"
         return "False"
    }
}

# Import User's
function importUser
{
     # Set Variables
     $continue = $null
     $dataPath = $null
     $dataSet = "user"

     # Verify user action
     if ( $promptAction -like "yes" )
     {
          $continue = "yes"
     }
     else
     {
          $continue = read-host "`n$((Get-Culture).TextInfo.ToTitleCase($dataSet)) datasets will be imported into $script:dstDomain. Would you like to continue? (Yes/No) "
     }

     # Import OU's
     if ( $continue -like "yes" )
     {
          # Build data file path
          $dataPath = Resolve-Path "$script:srcDir\$dataSet.*.ldif"

          # Import OU's
          write-host "`nStarting $dataSet data import.`nPlease wait..." -NoNewline
          try { ldifde -i -k -h -s 127.0.0.1 -j $script:srcDir -b administrator $script:dstDomain $script:adminPass -f $dataPath }
          catch { $errorCode += 1 }
     }

     # Return code
    if ( $errorCode -eq 0 )
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         # Report
         write-host "`t...Done!"
         write-host "$($(Get-Content -Path $script:srcDir\$dataSet.ldif.log | Select-String entries)[1])"
         return "True"
    }
    else
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         Move-Item -Path $script:srcDir\ldif.err -Destination $script:srcDir\$dataSet.ldif.err -Force -Confirm:$false
         # Report
         write-host "`t...Import had issues. Check logs."
         write-host "Log Files:`n$script:srcDir\$dataSet.ldif.log`n$script:srcDir\dataSet.ldif.err"
         return "False"
    }
}

### Mode Functions
# Import MemberOf's
function modMemberOf
{
     # Set Variables
     $continue = $null
     $dataPath = $null
     $dataSet = "member"

     # Verify user action
     if ( $promptAction -like "yes" )
     {
          $continue = "yes"
     }
     else
     {
          $continue = read-host "`n$((Get-Culture).TextInfo.ToTitleCase($dataSet)) datasets will be imported into $script:dstDomain. Would you like to continue? (Yes/No) "
     }

     # Import OU's
     if ( $continue -like "yes" )
     {
          # Build data file path
          $dataPath = Resolve-Path "$script:srcDir\$dataSet.*.ldif"

          # Import OU's
          write-host "`nStarting $dataSet data import.`nPlease wait..." -NoNewline
          try { ldifde -i -k -h -s 127.0.0.1 -j $script:srcDir -b administrator $script:dstDomain $script:adminPass -f $dataPath }
          catch { $errorCode += 1 }
     }

     # Return code
    if ( $errorCode -eq 0 )
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         # Report
         write-host "`t...Done!"
         write-host "$($(Get-Content -Path $script:srcDir\$dataSet.ldif.log | Select-String entries)[1])"
         return "True"
    }
    else
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         Move-Item -Path $script:srcDir\ldif.err -Destination $script:srcDir\$dataSet.ldif.err -Force -Confirm:$false
         # Report
         write-host "`t...Import had issues. Check logs."
         write-host "Log Files:`n$script:srcDir\$dataSet.ldif.log`n$script:srcDir\dataSet.ldif.err"
         return "False"
    }
}

# Import User Modification's
function modUser
{
     # Set Variables
     $continue = $null
     $dataPath = $null
     $dataSet = "userMod"

     # Verify user action
     if ( $promptAction -like "yes" )
     {
          $continue = "yes"
     }
     else
     {
          $continue = read-host "`n$((Get-Culture).TextInfo.ToTitleCase($dataSet)) datasets will be imported into $script:dstDomain. Would you like to continue? (Yes/No) "
     }

     # Import OU's
     if ( $continue -like "yes" )
     {
          # Build data file path
          $dataPath = Resolve-Path "$script:srcDir\$dataSet.*.ldif"

          # Import OU's
          write-host "`nStarting $dataSet data import.`nPlease wait..." -NoNewline
          try { ldifde -i -k -h -s 127.0.0.1 -j $script:srcDir -b administrator $script:dstDomain $script:adminPass -f $dataPath }
          catch { $errorCode += 1 }
     }

     # Return code
    if ( $errorCode -eq 0 )
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         # Report
         write-host "`t...Done!"
         write-host "$($(Get-Content -Path $script:srcDir\$dataSet.ldif.log | Select-String entries)[1])"
         return "True"
    }
    else
    {
         # Move log and error files
         Move-Item -Path $script:srcDir\ldif.log -Destination $script:srcDir\$dataSet.ldif.log -Force -Confirm:$false
         Move-Item -Path $script:srcDir\ldif.err -Destination $script:srcDir\$dataSet.ldif.err -Force -Confirm:$false
         # Report
         write-host "`t...Import had issues. Check logs."
         write-host "Log Files:`n$script:srcDir\$dataSet.ldif.log`n$script:srcDir\dataSet.ldif.err"
         return "False"
    }
}

# Main
function Main
{
     # Set Variables
     $errorCode = 0
     $ntpTime = $null
     $ipTunnels = $null
     $unixSrv = $null
     $pocDomain = $null
     $vFiles = $null
     $vDomain = $null
     $ouImport = $null
     $groupImport = $null
     $userImport = $null
     $memberImport = $null
     $userModImport = $null


     # Check switches and build tasks

     if ( $scrpModeB -eq $true )
     {
          if ( $errorCode -eq 0 )
          {
               # Set host time
               if ( $errorCode -eq 0 -and -not $script:scrpTasksP )
               {
                    write-host "`nConfiguring host NTP services to internal servers.`nPlease wait..." -NoNewline
                    $ntpTime = setWinTime

                    if ( $ntpTime -eq $true )
                    {
                         # Log
                         write-host "`t... Done!`n"
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         Write-host "`t... There were issues configuring the host time services.`nThis is a non-critical configuration, continuing.`n"
                    }
               }

               # Disable IPv6 Tunnels
               if ( $errorCode -eq 0 -and -not $script:scrpTasksP )
               {
                    # Log
                    write-host "`nDisabling IPv6 tunnels on host.`nPlease wait..." -NoNewline
                    $ipTunnels = ipTunnelDis

                    if ( $ipTunnels -eq $true )
                    {
                         # Log
                         write-host "`t`... Done!"
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         Write-host "`t... There were issues disabling the hosts IPv6 tunnels.`nThis is a non-critical configuration, continuing.`n"
                    }
               }

               # Install AD Services for Unix
               if ( $errorCode -eq 0 -and -not $script:scrpTasksP )
               {
                    # Log
                    write-host "`nInstalling and enabling AD Services for Unix.`nPlease wait..." -NoNewline
                    $unixSrv = instUnixSrv

                    if ( $unixSrv -eq $true )
                    {
                         # Log
                         write-host "`t... Done!"

                         $hostReboot = read-host "`nReboot is required to complete changes. Would you like to reboot now? (yes/no) "

                         if ( $hostReboot -like 'yes' )
                         {
                              # Start sleep to let all tasks complete
                              write-host "Rerun this script with the 'P' option to complete the domain build."
                              write-host "Waiting for all tasks to complete..."
                              Sleep-Progress 30
                              write-host "Rebooting now."
                              Restart-Computer -ComputerName "localhost" -Force -Confirm:$false -AsJob
                              exit
                         }
                         else
                         {
                              # Log
                              write-host "`nHost needs to be restarted before seed data can be imported. Please close all applications and restart. Exiting!`n"
                              $errorCode += 1
                              exit
                         }
                    }
                    else
                    {
                         # Log
                         Write-host "`t... There were issues installing Directory Services for Unix.`nThis is a critical component of the PoC build. Please review logs. Exiting!`n"
                         $errorCode += 1
                         exit
                    }
               }

               # Create PoC forest and promote first domain controller
               if ( $errorCode -eq 0 -and $script:scrpTasksP )
               {
                    # Log
                    write-host "`nCreating PoC forest and promoting first domain controller.`nPlease wait..." -NoNewline
                    $pocDomain = creatPocDomain

                    if ( $pocDomain -eq $true )
                    {
                         # Log
                         write-host "... Done!"

                         $hostReboot = read-host "`nReboot is required to complete changes. Would you like to reboot now? (yes/no) "

                         if ( $hostReboot -like 'yes' )
                         {
                              # Start sleep to let all tasks complete
                              write-host "Waiting for all tasks to complete..."
                              Sleep-Progress 30
                              write-host "Rebooting now."
                              Restart-Computer -ComputerName "localhost" -Force -Confirm:$false -AsJob
                              exit
                         }
                         else
                         {
                              # Log
                              write-host "`nHost needs to be restarted before seed data can be imported. Please close all applications and restart. Exiting!`n"
                              $errorCode += 1
                              exit
                         }
                    }
                    else
                    {
                         # Log
                         write-host "`t... There were issues creating the POC domain or promoting the domain controller.`nPlease review logs or attempt to manually promote POC domain and domain controller. Exiting!`n"
                         $errorCode += 1
                    }
               }
          }
          elseif ( $errorCode -gt 0 )
          {
               # Log
               write-host "`nError occurred. Exiting!"
               exit
          }
     }
     elseif ( $scrpModeS -eq $true )
     {
          # Check for errorCodes
          if ( $errorCode -eq 0 )
          {
               # Start Seed
               # Verify seed files are in place
               if ( $errorCode -eq 0 )
               {
                    # Log
                    write-host "`nVerifying seed files.`nPlease wait..." -NoNewline
                    $vFiles = verifyFiles

                    if ( $vFiles -eq $true )
                    {
                         write-host "`t... Done!"
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Verify POC domain is working
               if ( $errorCode -eq 0 )
               {
                    # Log
                    write-host "`nVerifying POC Domain.`nPlease wait..." -NoNewline
                    $vDomain = verifyDomain

                    if ( $vDomain -eq $true )
                    {
                         write-host "`t... Done!"
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Import OU data
               if ( $errorCode -eq 0 -and ($script:seedTasksA -or $script:seedTasksO) )
               {
                    # Log
                    write-host "`nSeeding OU data..."
                    $ouImport = importOU

                    if ( $ouImport -eq $true )
                    {
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Import Group data
               if ( $errorCode -eq 0 -and ($script:seedTasksA -or $script:seedTasksG) )
               {
                    # Log
                    write-host "`nSeeding Group data..."
                    $groupImport = importGroup

                    if ( $groupImport -eq $true )
                    {
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Import User data
               if ( $errorCode -eq 0 -and ($script:seedTasksA -or $script:seedTasksU) )
               {
                    # Log
                    write-host "`nSeeding User data..."
                    $userImport = importUser

                    if ( $userImport -eq $true )
                    {
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Import MemberOf data
               if ( $errorCode -eq 0 -and ($script:seedTasksA -or $script:seedTasksM) )
               {
                    # Log
                    write-host "`nSeeding MemberOf data..."
                    $memberImport = modMemberOf

                    if ( $memberImport -eq $true )
                    {
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }
               # Import User mode data
               if ( $errorCode -eq 0 -and ($script:seedTasksA -or $script:seedTasksE) )
               {
                    # Log
                    write-host "`nSeeding user modification data..."
                    $userModImport = modUser

                    if ( $userModImport -eq $true )
                    {
                         $errorCode += 0
                    }
                    else
                    {
                         # Log
                         write-host "Error occurred."
                         $errorCode += 1
                    }
               }
               elseif ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "Prerequisite task exited with an error. Skipping task!"
               }

               if ( $errorCode -gt 0 )
               {
                    # Log
                    write-host "`nEorror occurred. Please review output and logs. Exiting!"
                    exit
               }
          }
          elseif ( $errorCode -gt 0 )
          {
               # Log
               write-host "`nError occurred. Exiting!"
               exit
          }
     }
     else
     {
          # Log
         write-host "`nOperation mode not selected. Please review usage. Exiting!"
          showHelp
          exit
     }
}

# Call main
Main
