# Simple test script for ps-launcher verification
param(
    [string]$Name = "World",
    [string]$Path = "",
    [switch]$Verbose
)

Write-Host "============================================"
Write-Host "PS-Launcher Test Script" -ForegroundColor Cyan
Write-Host "============================================"
Write-Host ""
Write-Host "Parameters received:"
Write-Host "  Name: $Name"
Write-Host "  Path: $Path"
Write-Host "  Verbose: $Verbose"
Write-Host ""
Write-Host "Script executed successfully!" -ForegroundColor Green
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Execution time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

exit 0
