<#
.SYNOPSIS
    Script executed by ps-launcher.exe to log its invocation.
.DESCRIPTION
    This script logs the date/time, its full path, working directory, and all
    bound parameters to a log file (test.log). It is not meant to be executed
    directly.
.EXAMPLE
    This script is run indirectly by ps-launcher.exe.
#>

param(
    [string]$FilePath,
    [string]$FileList,
    [string]$Name,
    [switch]$Verbose
)

try {
    # Determine the folder where this script resides.
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $logPath = Join-Path $scriptDir "test.log"
    
    # If a comma-separated file list was provided, split it into an array.
    $fileArray = @()
    if ($FileList) {
        $fileArray = $FileList.Split(',')
    }
    
    # Prepare a log message with the invocation details.
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $message = @"
Script executed at: $date
Script path: $($MyInvocation.MyCommand.Path)
Working directory: $PWD

Parameters received:
    FilePath: $FilePath
    FileList: $($fileArray -join ', ')
    Name: $Name
    Verbose: $Verbose
"@
    
    # Append the log message.
    $message | Out-File -FilePath $logPath -Append -Encoding UTF8
    
    exit 0
} catch {
    $errorPath = Join-Path ([System.IO.Path]::GetTempPath()) "ps-launcher-error.log"
    "Error at $(Get-Date): $($_.Exception.Message)" | Out-File -FilePath $errorPath -Encoding UTF8
    exit 1
}
