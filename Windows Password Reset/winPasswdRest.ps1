#########################################################################################
# winPasswdRest.ps1
# Eryk Voelker 2/2019
# evoelker81@yahoo.com
#
# The script will reset the password and account for a supplied user the
# email the new password to the email address assigned to the account.
#
# If the user account being reset don't have a listed email address, the script exits
#
# v0.1 : First write and test
# v0.2 : Bug fixes and testing with multiple account resets.
# v0.3 : Fix logic when account lookup/reset fails
# v0.4 : Fix logging and verbiage
#
#########################################################################################

# Script Description

<#
.SYNOPSIS
This script will reset the password and account status for the provided SAM account name/s

.DESCRIPTION


.PARAMETER logFile
Specifie the full path to the log file. Default is in the same directory the script was called

.PARAMETER logLevel
Specifies the level of logging.
1 = All - Info, Warning's & Errors
2 = Warnings & Errors
3 = Errors

.PARAMETER File
Accept an input file with one account per line

.PARAMETER userAccName
Specifies the user SAM account name to be reset or the full path to a file that has the user SAM account names (one per line) to be reset.

.PARAMETER accDomain
Specifies the domain the user account resides in.

.PARAMETER scrFile
Specifies if the script will run in single user mode or file mode.

.NOTES
This script must be run from a domain join server/workstation

Users must be part of the following group specified in variable '$script:adminGroups'

https://www.epochconverter.com/ldap

.EXAMPLE
.\passwdReset.ps1 -d poc07.local -u some.user

Single user run.

.EXAMPLE
.\passwdReset.ps1 -File -d poc07.local -u .\itAdminTest.txt

Bulk run with '-File' parameter.

#>

# Set Parameters

param (
     [Parameter()]
     [string]$logFile = "passwdReset.log", # Set default log file and location

     [Parameter()]
     [ValidateSet('1','2','3')]
     [int]$logLevel = 1, # Default logging level

     [Parameter()]
     [alias("Scope")]
     [ValidateSet('Single', 'File')]
     [string]$script:runScope = 'Single', # Default run type = Single account

     [Parameter(Mandatory)]
     [alias("d")]
     [string]$script:accDomain = $null, # Destination POC Domain

     [Parameter(Mandatory)]
     [alias("u")]
     [string]$script:userAccName # Can be an individual SAM account or file with multiple SAM accounts
)

# Set execute location to script directory
$scriptPath = Split-Path $MyInvocation.MyCommand.Path
Push-Location -Path $scriptPath

# Variables
$script:winADCreds = $null # Set Windows creds to null
$script:winAdminCreds = $null # Set Windows admin creds to null
$script:adminGroups = ("<someAdGroup1>","<someAdGroup2>") # Security group user must be a member of to use script

# Email Settings
# Set SMTP server
$smtpServ = "<someSMTP.local>"
$smtpPort = 25
# Set email from address
$fromAddr = "<noReply.IT@local.net>"

# Set script date
$date = (Get-Date -Format "MM-dd-yyyy")
#Set Script time
$sTime = (Get-Date -Format "HH:mm:ss")
# Set file base
$fileBase = "passwdReset"
# Set log file location
$logFile = ".\$logFile"

# Set return values for functions results to null
$userVerifyResults = $null
$resetAccPasswdResults = $null
$resetAccSettingsResults = $null
$adAccountObject = $null
$secTempPasswd = $null

# Arrays

# Functions

# Function to write to the log file
function Write-Log
{
     <#
     .SYNOPSIS
     Function to write formatted information to the log file.

     .DESCRIPTION
     Function takes provided message and severity level (1,2,3), formats the message and writes it to the log file. The message parameter is required.
     If a severity level other than 1 is needed, specify it as the second parameter.
     Default logging output level can be defined at the script level using the $LogLevel variable. Options are:
     1: Info
     2: Warning (Default)
     3: Error

     .NOTES
     The following variable need to be set for this function to work correctly:

     $date = (Get-Date -Format "M-d-yyyy")
     $logFile = "<Full path to log file>"

     .EXAMPLE
     Write-Log -Message "<message>" -Severity "<severity level: 1,2,3>"

     Write-Log -Message "Hello World" -Severity 3

     #>

     param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('1','2','3')]
        [int]$Severity = 1 # Default to a low severity. Otherwise, override
     )

     # Functions
     function readableErrorLevel($Severity)
     {
          # Convert Severity level to human readable
          if ( $Severity -eq 1 )
          {
              return "Info"
          }
          elseif ( $Severity -eq 2 )
          {
              return "Warning"
          }
          elseif ( $Severity -eq 3 )
          {
              return "Error"
          }
     }

     # Check if log file exists. If no, create it
     if ( !(Test-Path -Path $logFile) )
     {
         # Create log file
         write-host "Creating log file: $scriptPath\$fileBase\$logFile`n"
         try
         {
              New-Item $logFile -type file > $null
         }
         catch
         {
              # Log
              write-host "Couldn't create logfile. Exiting!"
              exit
         }
     }

     # Set time for log entry
     $time = (Get-Date -Format "HH:mm:ss")

     if ( $LogLevel -eq 3 -and $Severity -eq 3 )
     {
          # Convert error level to human readable
          [string]$Severity = readableErrorLevel $Severity

          # Add formatted message to log file
          Add-Content -Path $logFile -Value "$date $time : $Severity : $Message"
     }
     elseif ( $LogLevel -eq 2 -and $Severity -ge 2 )
     {
          # Convert error level to human readable
          [string]$Severity = readableErrorLevel $Severity

          # Add formatted message to log file
          Add-Content -Path $logFile -Value "$date $time : $Severity : $Message"
     }
     elseif ( $LogLevel -eq 1 -and $Severity -ge 1 )
     {
          # Convert error level to human readable
          [string]$Severity = readableErrorLevel $Severity

          # Add formatted message to log file
          Add-Content -Path $logFile -Value "$date $time : $Severity : $Message"
     }
}

# Function to send email
function sendMail
{
     <#
     .SYNOPSIS
     Function to send email to supplied email address.

     .DESCRIPTION
     Function takes the provided email address, subject and message, formats an email and sends it to the configured SMTP server.
     The subject line is optional.
     The default subject string can be changed if you don't want to supply a subject parameter.

     .NOTES
     The following variable need to be set for this function to work correctly:

     $date = (Get-Date -Format "M-d-yyyy")
     $starTime = (Get-Date -Format "HH:mm:ss")
     $smtpServ = "<SMTP Server>"
     $fromAddr = "<From email address>"

     .EXAMPLE
     sendMail -EmailAddress "<To email address" -Subject "<Email subject line>" -Message "<Email message body>"

     sendMail -EmailAddress "evoelker81@yahoo.com" -Subject "Test email" -Message "Test Body: This is a test."

     #>

     param (
        [Parameter(Mandatory)]
        [string]$EmailAddress,

        [Parameter()]
        [string]$Subject = "IT Email Notice", # Default value if none is provided.

        [Parameter(Mandatory)]
        [string]$Message

     )

     # Send email with formated message
     Send-MailMessage -From $fromAddr -To $EmailAddress -Subject $Subject -Body $Message  -BodyAsHtml -SmtpServer $smtpServ -Port $smtpPort
}

# Get Windows Credentials
function getWinCreds
{
     # Log
     Write-Log -Message "Collecting user credentials for account reset."

     # Get Windows AD username
     $UserName = read-host "Enter Windows AD Username (domain.user) "

     # Get Windows AD Password
     $Password = read-host -AsSecureString "Enter Windows AD Password"

     # Create secure credentials
     if ( $UserName -and $Password )
     {
          $script:winADCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName , $Password
     }
}

# User verification
function userVerify
{
     # Variables
     $userIdentity = $null
     $errorCode = $null
     $members = $null

     # Log
     Write-Log -Message "User verification started."

     # Import AD moduoe
     Import-Module ActiveDirectory

     # Call user cred Functions
     # Windows AD and Administrator
     getWinCreds

     # Verify windows creds are part of 'DNS Admin' and 'Domain Join'
     if ( $script:winADCreds.UserName )
     {
          # Retrieve username is usable format
          $userIdentity = $($script:winADCreds.UserName).ToString()

          # Check group members for username
          foreach ( $group in $adminGroups )
          {
               # Get admin group members
               $members = $null
               $members = Get-ADGroupMember -Identity $group -Recursive | Select -ExpandProperty SamAccountName

               if ( $members -contains $userIdentity )
               {
                    # Log
                    Write-Log -Message "$userIdentity is part of $group."

                    $errorCode += 0
               }
               else
               {
                    # Log
                    Write-Log -Message "$userIdentity is not part of $group. Exiting!" -Severity 3
                    write-host "$userIdentity is not authorized to run this script."

                    $errorCode += 1
               }
          }
     }
     else
     {
          # Log
          Write-Log -Message "No Windows Active Directory credentials found." -Severity 3
          write-host "No Windows Active Directory credentials found."

          $errorCode += 1
     }

     # Return code
     if ( $errorCode -eq 0 )
     {
          # Log
          Write-Log -Message "User verification completed."

          return "True"
     }
     else
     {
          # Log
          Write-Log -Message "User verification exited with errors. Check logs." -Severity 3

          return "False"
     }
}

# Lookup SAM Account and write account info into variable
function accountLookup
{
     param (
          [Parameter()]
          [string]$userAccount =  $null # Default
     )

     # Log
     Write-Log -Message "Looking up user $userAccount in $script:accDomain AD domain."

     # Set variable
     $userAdAccount = $null

     # Lookup user account and retrive needed properties
     try
     {
          $userAdAccount = Get-AdUser -Server $script:accDomain -Credential $script:winADCreds -Identity $userAccount -Properties Name, SamAccountName, mail

          # Verify account attributes
          if ( $userAdAccount.mail )
          {
               # Log
               Write-Log -Message "User account has email address."

               # Return account info
               return $userAdAccount
          }
          else
          {
               # Log
               Write-Log -Message "User account doesn't have email address."
               write-host "User account doesn't have an email address set, reset account manually."
               return "False"
          }
     }
     catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
     {
          # Log
          Write-Log -Message "Can't locate $userAccount in $script:accDomain. Reset account manually." -Severity 3
          Write-Host "Can't locate $userAccount in $script:accDomain. Reset account manually."
          return "False"
     }
     catch
     {
          # Log
          Write-Log -Message "Unexpected error connecting to $script:accDomain. Reset account manually. Exiting!" -Severity 3
          write-host "Unexpected error connecting to $script:accDomain. Reset account manually. Exiting!"
          return "False"
     }
}

# Generate random password (16 Alfa/Num/Spec caricatures)
function genTempPasswd
{
     param (
          [Parameter()]
          [int]$passwdLenght = 10 # Default
     )
     # Set Variables
     $alphabet = $null
     $TempPasswd = $null

     #  Create source alphabet
     for ( $a=48; $a -le 126; $a++ )
     {
          $alphabet +=,[char][byte]$a
     }

     # For loop to generate secure password
     for ( $loop=1; $loop -le $passwdLenght; $loop++ )
     {
            $tempPasswd += ( $alphabet | Get-Random )
     }

     # Complexity loop
     for ( $loop=1; $loop -le 5; $loop++ )
     {
          $tempPasswd += ( $alphabet[0..16] | Get-Random )
     }

     # Convert tempPasswd to secure string
     $tempPasswdSec = ConvertTo-SecureString $tempPasswd -AsPlainText -Force
     # set tempPasswd to $null
     $tempPasswd = $null

     # Return secure password string
     return $tempPasswdSec
}

# Reset user password and account (incase of lockout)
function resetAccPasswd
{
     param (
          [Parameter(Mandatory)]
          $userAdAccount = $null, # Default - Empty

           [Parameter(Mandatory)]
           $newPasswd = $null # Default - Empty
     )

     # Log
     Write-Log -Message "Resetting $($userAdAccount.SamAccountName) password."

     # Reset account password
     try
     {
          Set-ADAccountPassword -Server $script:accDomain -Credential $script:winADCreds -Identity $userAdAccount.SamAccountName -Reset -NewPassword $newPasswd
          return "True"
     }
     catch
     {
          # Log
          Write-Log -Message "Error resetting $($userAdAccount.SamAccountName) password." -Severity 3
          write-host "Error resetting $($userAdAccount.SamAccountName) password, reset manually"

          return "False"
     }
}

# Reset user account settings
function resetAccSettings
{
     param (
          [Parameter(Mandatory)]
          $userAdAccount = $null # Default - Empty
     )

     # Log
     Write-Log -Message "Enabling account and resetting 'empty password flag'."

     # Enable account and reset empty password flag
     try
     {
         Set-ADUser -Server $script:accDomain -Credential $script:winADCreds -Identity $userAdAccount.SamAccountName -Enabled $true -PasswordNotRequired $false

         return "True"
     }
     catch
     {
         # Log
         Write-Log -Message "Error enabling and clearing the 'empty password flag' for $($userAdAccount.SamAccountName)." -Severity 3
         write-host "Error enabling and clearing the 'empty password flag' for $($userAdAccount.SamAccountName), set manually"

         return "False"
     }
}

# Main
function Main
{
     # Set Variables
     $continue = $null

     # Set line in log
     Write-Log -Message "#################### $date $sTime ####################"

     # Get user credentials and verify permissions
     $userVerifyResults = userVerify

     if ( $userVerifyResults )
     {
          # Log
          Write-Log -Message "User account verified."

          $continue = "yes"
     }
     else
     {
          # Log
          Write-Log -Message "Unauthorized execution of this script, exiting!" -Severity 3
          write-host "Unauthorized execution of this script, exiting!" -f Red

          $continue = "no"
     }

     # Reset account passwords and update account settings
     if ( $continue -eq "yes" )
     {
          # Multiple accounts
          if ( $script:runScope -eq "File" )
          {
               # Verify file and read in value as an array
               try
               {
                    # Log
                    Write-Log -Message "Importing user account file."
                    $userAccounts = Get-Content -path $script:userAccName
               }
               catch [System.Management.Automation.ItemNotFoundException]
               {
                    # Log
                    Write-Log -Message "File not found. Exiting!" -Severity 3
                    write-host "File not found. Exiting!"
                    exit
               }
               catch
               {
                    # Log
                    Write-Log -Message "Unhandled error. Exiting" -Severity 3
                    write-host "Unhandled error. Exiting"
                    exit
               }

               # For loop for each user account in file
               foreach ( $account in $userAccounts )
               {
                    # Clear variables
                    $adAccountObject = $null
                    $secTempPasswd = $null
                    $resetAccPasswdResults = $null
                    $resetAccSettingsResults = $null

                    # Log
                    Write-Log -Message "Looking up $account."
                    write-host "`nLooking up $account..."

                    # Look account to be reset
                    $adAccountObject = accountLookup $account

                    # Verify account object
                    if ( $adAccountObject -ne $false )
                    {
                         # Log
                         Write-Log -Message "Account found, resetting password." -Severity 1
                         write-host "Account found, resetting password."

                         # Generate secure password string
                         $secTempPasswd = genTempPasswd

                         # Reset account password
                         $resetAccPasswdResults = resetAccPasswd $adAccountObject $secTempPasswd

                         # Verify account password reset
                         if ( $resetAccPasswdResults -ne $false )
                         {
                              # Log
                              Write-Log -Message "$($adAccountObject.Name) account password has been reset."
                              write-host "$($adAccountObject.Name) account password has been reset."

                              # Set password reset email body
                              $emailbody ="" # Create email body variable object
                              $emailbody += "<p>Hello $($adAccountObject.Name),</p>"
                              $emailbody += "<p><b>User Account:</b> <domainShortName>\$($adAccountObject.SamAccountName)<br></p>"
                              $emailbody += "<p><b>Temporary Password:</b> $((New-Object PSCredential "user",$secTempPasswd).GetNetworkCredential().Password)</p>"
                              $emailbody += '<p><strong>2. </strong>Follow the "<b>PLEASE RESET YOUR TEMPORARY PASSWORD AS SOON AS POSSIBLE</b>"</p>'

                              # Email user
                              sendMail -EmailAddress $adAccountObject.mail `
                                   -Subject "IT ALERT: Domain Password Reset" `
                                   -Message $emailbody

                              # Reset account settings
                              $resetAccSettingsResults = resetAccSettings $adAccountObject

                              # Verify account setting reset
                              if ( $resetAccSettingsResults -ne $false )
                              {
                                   # Log
                                   Write-Log -Message "$($adAccountObject.Name) account flags have been reset."
                                   write-host "$($adAccountObject.Name) account flags have been reset."
                              }
                              else
                              {
                                   # Log
                                   Write-Log -Message "$account AD account flag reset failed." -Severity 3
                                   Write-Host "$account AD account flag reset failed."
                                   continue
                              }
                         }
                         else
                         {
                              # Log
                              Write-Log -Message "$account AD account password reset failed." -Severity 3
                              Write-Host "$account AD account password reset failed."
                              continue
                         }
                    }
                    else
                    {
                         # Log
                         Write-Log -Message "$account AD account lookup failed." -Severity 3
                         Write-Host "$account AD account lookup failed."
                         continue
                    }
               }
          }
          elseif ( $script:runScope -eq "Single" ) # Single account
          {
               # Log
               Write-Log -Message "Looking up $script:userAccName."
               write-host "`nLooking up $script:userAccName..."

               # Look account to be reset
               $adAccountObject = accountLookup $script:userAccName

               # Verify account object
               if ( $adAccountObject -ne $false )
               {
                    # Log
                    Write-Log -Message "Account found, resetting password." -Severity 1
                    write-host "Account found, resetting password."

                    # Generate secure password string
                    $secTempPasswd = genTempPasswd

                    # Reset account password
                    $resetAccPasswdResults = resetAccPasswd $adAccountObject $secTempPasswd

                    # Verify account password reset
                    if ( $resetAccPasswdResults -ne $false )
                    {
                         # Log
                         Write-Log -Message "$($adAccountObject.Name) account password has been reset."
                         write-host "$($adAccountObject.Name) account password has been reset."

                         # Set password reset email body
                         $emailbody ="" # Create email body variable object
                         $emailbody += "<p>Hello $($adAccountObject.Name),</p>"
                         $emailbody += "<p><b>User Account:</b> <domainShortName>\$($adAccountObject.SamAccountName)<br></p>"
                         $emailbody += "<p><b>Temporary Password:</b> $((New-Object PSCredential "user",$secTempPasswd).GetNetworkCredential().Password)</p>"
                         $emailbody += '<p><strong>2. </strong>Follow the "<b>PLEASE RESET YOUR TEMPORARY PASSWORD AS SOON AS POSSIBLE</b>"</p>'

                         # Email user
                         sendMail -EmailAddress $adAccountObject.mail `
                              -Subject "IT ALERT: Domain Password Reset" `
                              -Message $emailbody

                         # Reset account settings
                         $resetAccSettingsResults = resetAccSettings $adAccountObject

                         # Verify account setting reset
                         if ( $resetAccSettingsResults -ne $false )
                         {
                              # Log
                              Write-Log -Message "$($adAccountObject.Name) account flags have been reset"
                              write-host "$($adAccountObject.Name) account flags have been reset"
                         }
                         else
                         {
                              # Log
                              Write-Log -Message "Exiting."
                              Write-Host "Exiting!`n"
                              exit
                         }
                    }
                    else
                    {
                         # Log
                         Write-Log -Message "Exiting."
                         Write-Host "Exiting!`n"
                         exit
                    }
               }
               else
               {
                    # Log
                    Write-Log -Message "Exiting."
                    Write-Host "Exiting!`n"
                    exit
               }
          }
     }
     # Log
     write-host "All accounts have been reset.`n"
}

# Call Main
Main
