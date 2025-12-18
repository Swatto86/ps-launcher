<#
.SYNOPSIS
    Comprehensive test suite for ps-launcher.exe
.DESCRIPTION
    Tests all edge cases and functionality of ps-launcher.exe including:
    - Basic parameter passing
    - Scripts with [CmdletBinding()]
    - Scripts with [CmdletBinding(SupportsShouldProcess)]
    - Mandatory parameters (should fail gracefully in non-interactive mode)
    - Error handling
    - Exit codes
    - Parameter validation
.EXAMPLE
    .\test.ps1
.NOTES
    Requires ps-launcher.exe in the same directory
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$psLauncher = Join-Path $scriptDir "ps-launcher.exe"
$logFile = Join-Path $scriptDir "test.log"

# Colors for output
$Red = 'Red'
$Green = 'Green'
$Yellow = 'Yellow'

# Test statistics
$totalTests = 0
$passedTests = 0
$failedTests = 0

#region Helper Functions

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-TestCase {
    param([string]$Name)
    Write-Host "`n  TEST: $Name" -ForegroundColor Yellow
}

function Assert-ExitCode {
    param(
        [int]$Expected,
        [int]$Actual,
        [string]$TestName
    )
    $script:totalTests++
    if ($Expected -eq $Actual) {
        Write-Host "    ✓ PASS: Exit code $Actual (expected $Expected)" -ForegroundColor Green
        $script:passedTests++
        return $true
    } else {
        Write-Host "    ✗ FAIL: Exit code $Actual (expected $Expected)" -ForegroundColor Red
        $script:failedTests++
        return $false
    }
}

function Assert-LogContains {
    param(
        [string]$ExpectedContent,
        [string]$TestName
    )
    $script:totalTests++
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw
        if ($content -match [regex]::Escape($ExpectedContent)) {
            Write-Host "    ✓ PASS: Log contains expected content" -ForegroundColor Green
            $script:passedTests++
            return $true
        } else {
            Write-Host "    ✗ FAIL: Log does not contain: $ExpectedContent" -ForegroundColor Red
            $script:failedTests++
            return $false
        }
    } else {
        Write-Host "    ✗ FAIL: Log file not found" -ForegroundColor Red
        $script:failedTests++
        return $false
    }
}

function Invoke-PSLauncher {
    param([string]$Arguments)
    
    # Clean up previous log
    if (Test-Path $logFile) { Remove-Item $logFile -Force }
    
    # Execute ps-launcher using Start-Process for better control
    $process = Start-Process -FilePath $psLauncher -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    
    # Give script time to write log
    Start-Sleep -Milliseconds 500
    
    return @{
        ExitCode = $process.ExitCode
        Output = $null
    }
}

#endregion

#region Test Script Definitions

# Create inline test scripts
$testScripts = @{
    'basic' = @'
# Basic script with no [CmdletBinding()] - should NOT accept -Confirm parameter
param([string]$Name, [string]$Value)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
"Name: $Name, Value: $Value" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@

    'cmdletbinding' = @'
# Script with [CmdletBinding()]
[CmdletBinding()]
param([string]$Name, [string]$Value)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
"CmdletBinding: Name=$Name, Value=$Value, Verbose=$($PSBoundParameters.ContainsKey('Verbose'))" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@

    'shouldprocess' = @'
# Script with [CmdletBinding(SupportsShouldProcess)]
[CmdletBinding(SupportsShouldProcess)]
param([string]$Target)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
if ($PSCmdlet.ShouldProcess($Target, "Process")) {
    "ShouldProcess: Processed $Target" | Out-File $logPath -Encoding UTF8 -Force
    exit 0
}
"ShouldProcess: Skipped $Target" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@

    'mandatory' = @'
# Script with mandatory parameter (will fail in non-interactive mode)
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RequiredParam)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
"Mandatory: $RequiredParam" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@

    'errorhandling' = @'
# Script with intentional error
[CmdletBinding()]
param([switch]$ThrowError)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
if ($ThrowError) {
    "Throwing error" | Out-File $logPath -Encoding UTF8 -Force
    throw "Intentional error for testing"
}
"No error" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@

    'exitcodes' = @'
# Script that returns different exit codes
[CmdletBinding()]
param([int]$ExitCode = 0)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
"ExitCode: $ExitCode" | Out-File $logPath -Encoding UTF8 -Force
exit $ExitCode
'@

    'quoteescape' = @'
# Script that receives parameters with internal quotes
[CmdletBinding()]
param([string]$QuotedText, [string]$Message)
$logPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "test.log"
"QuotedText: $QuotedText, Message: $Message" | Out-File $logPath -Encoding UTF8 -Force
exit 0
'@
}

# Create test script files
foreach ($key in $testScripts.Keys) {
    $scriptPath = Join-Path $scriptDir "test-$key.ps1"
    $testScripts[$key] | Out-File $scriptPath -Encoding UTF8
}

#endregion

#region Run Tests

Write-TestHeader "PS-Launcher Comprehensive Test Suite"

# Test 1: Basic script execution
Write-TestCase "Basic script with parameters"
$result = Invoke-PSLauncher "-Script `"test-basic.ps1`" -Name `"TestUser`" -Value `"TestValue`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "Basic script"
Assert-LogContains -ExpectedContent "Name: TestUser" -TestName "Basic script log"

# Test 2: CmdletBinding script
Write-TestCase "Script with [CmdletBinding()]"
$result = Invoke-PSLauncher "-Script `"test-cmdletbinding.ps1`" -Name `"User1`" -Value `"Value1`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "CmdletBinding script"
Assert-LogContains -ExpectedContent "CmdletBinding: Name=User1" -TestName "CmdletBinding log"

# Test 3: CmdletBinding with -Verbose
Write-TestCase "Script with [CmdletBinding()] and -Verbose"
$result = Invoke-PSLauncher "-Script `"test-cmdletbinding.ps1`" -Name `"User2`" -Value `"Value2`" -Verbose"
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "CmdletBinding with Verbose"
Assert-LogContains -ExpectedContent "Verbose=True" -TestName "CmdletBinding Verbose log"

# Test 4: SupportsShouldProcess script
Write-TestCase "Script with [CmdletBinding(SupportsShouldProcess)]"
$result = Invoke-PSLauncher "-Script `"test-shouldprocess.ps1`" -Target `"TestTarget`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "ShouldProcess script"
Assert-LogContains -ExpectedContent "Processed TestTarget" -TestName "ShouldProcess log"

# Test 5: SupportsShouldProcess with -WhatIf
Write-TestCase "Script with [CmdletBinding(SupportsShouldProcess)] and -WhatIf"
$result = Invoke-PSLauncher "-Script `"test-shouldprocess.ps1`" -Target `"TestTarget`" -WhatIf"
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "ShouldProcess with WhatIf"
# Note: -WhatIf prevents execution so no log file is written (expected behavior)

# Test 6: Mandatory parameter without value (should fail)
Write-TestCase "Script with mandatory parameter (no value provided - should fail)"
$result = Invoke-PSLauncher "-Script `"test-mandatory.ps1`""
Assert-ExitCode -Expected 1 -Actual $result.ExitCode -TestName "Mandatory parameter missing"

# Test 7: Mandatory parameter with value
Write-TestCase "Script with mandatory parameter (value provided)"
$result = Invoke-PSLauncher "-Script `"test-mandatory.ps1`" -RequiredParam `"ProvidedValue`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "Mandatory parameter provided"
Assert-LogContains -ExpectedContent "Mandatory: ProvidedValue" -TestName "Mandatory parameter log"

# Test 8: Error handling
Write-TestCase "Script with error handling"
$result = Invoke-PSLauncher "-Script `"test-errorhandling.ps1`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "No error"
Assert-LogContains -ExpectedContent "No error" -TestName "No error log"

# Test 9: Script that throws error
Write-TestCase "Script that throws error"
$result = Invoke-PSLauncher "-Script `"test-errorhandling.ps1`" -ThrowError"
Assert-ExitCode -Expected 1 -Actual $result.ExitCode -TestName "Script with error"

# Test 10: Exit code propagation
Write-TestCase "Exit code propagation (exit 0)"
$result = Invoke-PSLauncher "-Script `"test-exitcodes.ps1`" -ExitCode 0"
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "Exit code 0"

Write-TestCase "Exit code propagation (exit 42)"
$result = Invoke-PSLauncher "-Script `"test-exitcodes.ps1`" -ExitCode 42"
Assert-ExitCode -Expected 42 -Actual $result.ExitCode -TestName "Exit code 42"

# Test 11: Parameters with spaces
Write-TestCase "Parameters with spaces"
$result = Invoke-PSLauncher "-Script `"test-basic.ps1`" -Name `"John Doe`" -Value `"Multiple Words Here`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "Parameters with spaces"
Assert-LogContains -ExpectedContent "Name: John Doe" -TestName "Spaces in parameters"

# Test 12: Parameters with internal quotes (AppendEscaped function test)
Write-TestCase "Parameters with internal quotes (AppendEscaped)"
$result = Invoke-PSLauncher "-Script `"test-quoteescape.ps1`" -QuotedText `"He said \`"hello\`" there`" -Message `"It's working`""
Assert-ExitCode -Expected 0 -Actual $result.ExitCode -TestName "Internal quotes"
Assert-LogContains -ExpectedContent 'QuotedText: He said "hello" there' -TestName "Quote escaping in log"
Assert-LogContains -ExpectedContent "Message: It's working" -TestName "Apostrophe handling"

#endregion

#region Cleanup and Results

Write-TestHeader "Test Results Summary"
Write-Host "Total Tests:  $totalTests" -ForegroundColor White
Write-Host "Passed:       $passedTests" -ForegroundColor Green
Write-Host "Failed:       $failedTests" -ForegroundColor Red
$passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 2) } else { 0 }
Write-Host "Pass Rate:    $passRate%" -ForegroundColor $(if ($passRate -eq 100) { $Green } elseif ($passRate -ge 80) { $Yellow } else { $Red })

# Clean up test scripts
Write-Host "`nCleaning up test scripts..." -ForegroundColor Cyan
foreach ($key in $testScripts.Keys) {
    $scriptPath = Join-Path $scriptDir "test-$key.ps1"
    if (Test-Path $scriptPath) {
        Remove-Item $scriptPath -Force
    }
}

# Clean up log file
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

Write-Host "Test suite completed!`n" -ForegroundColor Cyan

#endregion

# Exit with appropriate code
exit $(if ($failedTests -eq 0) { 0 } else { 1 })
