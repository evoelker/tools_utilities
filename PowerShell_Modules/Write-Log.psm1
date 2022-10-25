<#
Write-Log.psm1
Eryk Voelker 04/2020
evoelker81@yahoo.com

v0.01 : First write and test
v0.02 : Update to get logFile location
v0.03 : Updated log level 4 to write to stdout
v0.04 : Current date wasn't being shown. Added 'date' variable.
v0.04 : Updated log level 4 to use 'Tee-Object' rather than stdout for containers

#>

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
4: Write all logs to stdout

.NOTES
The following variable need to be set for this function to work correctly:

$date = (Get-Date -Format "M-d-yyyy")
$logFile = "<Full path to log file>"

.EXAMPLE
Write-Log -Message "<message>" -Severity "<severity level: 1,2,3>"

Write-Log -Message "Hello World" -Severity 3

#>

function Write-Log
{
     param (
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('1','2','3')]
        [int]$Severity = 1 # Default to a low severity. Otherwise, override
     )

     # Variable
     $date = (Get-Date -Format "MM-dd-yyyy") # Set current date

     # Functions
     function readableErrorLevel($Severity)
     {
          # Convert Severity level to human readable
          if ( $Severity -eq 1 )
          {
              return "Information"
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
         # write-host "Creating log file: $scriptPath\$logFile`n"
         write-host "Creating log file: $logFile`n"
         New-Item $logFile -type file | Out-Null
     }

     # Set time for log entry
     $time = (Get-Date -Format "HH:mm:ss")

     if ( $LogLevel -eq 4 -and $Severity -ge 1 )
     {
          # Convert error level to human readable
          [string]$Severity = readableErrorLevel $Severity

          # Add formatted message to log file
          # "$date $time : $Severity : $Message" | Tee-Object -FilePath $logFile -Append
          Add-Content -Path $logFile -Value "$date $time : $Severity : $Message"
          Write-Host -Message "$date $time : $Severity : $Message"
     }
     elseif ( $LogLevel -eq 3 -and $Severity -eq 3 )
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

# Export module
Export-ModuleMember -Function Write-Log
