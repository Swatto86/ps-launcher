# Edge Case Test Script for ps-launcher
[CmdletBinding()]
param(
    [string]$EmptyString = "",
    [string]$PathWithSpaces = "",
    [string]$QuotedValue = "",
    [int]$NegativeNumber = 0,
    [string]$ColonSyntax = "",
    [string]$VeryLongParameter = ""
)

$logPath = Join-Path $PSScriptRoot "edge-test.log"

$output = @"
=== Edge Case Test Results ===
EmptyString: '$EmptyString' (Length: $($EmptyString.Length))
PathWithSpaces: '$PathWithSpaces'
QuotedValue: '$QuotedValue'
NegativeNumber: $NegativeNumber
ColonSyntax: '$ColonSyntax'
VeryLongParameter: '$VeryLongParameter' (Length: $($VeryLongParameter.Length))
"@

$output | Out-File $logPath -Encoding UTF8 -Force
Write-Host $output
exit 0
