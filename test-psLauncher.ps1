<#
.SYNOPSIS
    Test harness for ps-launcher.exe.
.DESCRIPTION
    This script runs a series of tests against ps-launcher.exe by invoking it with
    testScript.ps1 (the script that logs its parameters). Each test case passes a different
    combination of parameters. The harness checks that:
      - ps-launcher.exe returns exit code 0, and
      - the log file (test.log) contains an expected substring.
.EXAMPLE
    .\Test-PSLauncher.ps1
.NOTES
    Ensure that ps-launcher.exe, testScript.ps1, and this script are all located in the
    same folder.
#>

# Define folder paths.
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$psLauncher  = Join-Path $scriptDir "ps-launcher.exe"
$testScript  = Join-Path $scriptDir "testScript.ps1"
$logFile     = Join-Path $scriptDir "test.log"

# Define test cases as an array of hashtables.
$testCases = @(
    @{
        Name     = "Basic Usage - Single Parameter"
        Args     = "-Script `"$testScript`" -FilePath `"C:\temp\test.txt`""
        Expected = "FilePath: C:\temp\test.txt"
    },
    @{
        Name     = "Multiple Parameters with Spaces"
        Args     = "-Script `"$testScript`" -FilePath `"C:\My Documents\test.txt`" -Name `"John Doe`""
        Expected = "Name: John Doe"
    },
    @{
        Name     = "Array Parameter"
        Args     = "-Script `"$testScript`" -FileList `"file1.txt,file2.txt,file3.txt`""
        Expected = "FileList: file1.txt, file2.txt, file3.txt"
    },
    @{
        Name     = "Switch Parameter"
        Args     = "-Script `"$testScript`" -Verbose"
        Expected = "Verbose: True"
    },
    @{
        Name     = "Multiple Parameters Combined"
        Args     = "-Script `"$testScript`" -FilePath `"C:\logs\test.txt`" -FileList `"a.txt,b.txt,c.txt`" -Name `"Jane Smith`" -Verbose"
        Expected = "Name: Jane Smith"
    }
)

# Function to run an individual test case.
function Run-TestCase($testCase) {
    Write-Host "Running test case: $($testCase.Name)" -ForegroundColor Cyan

    # Remove previous log file if it exists.
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    # Build and show the full command line.
    $cmdLine = "$psLauncher $($testCase.Args)"
    Write-Host "Executing: $cmdLine"

    # Launch ps-launcher.exe and wait for it to finish.
    $process = Start-Process -FilePath $psLauncher `
                               -ArgumentList $testCase.Args `
                               -NoNewWindow -Wait -PassThru
    $exitCode = $process.ExitCode

    # Verify exit code.
    if ($exitCode -ne 0) {
        Write-Host "Test Failed: Process returned exit code $exitCode" -ForegroundColor Red
        return $false
    }

    # Give the script a moment to write the log.
    Start-Sleep -Seconds 1

    if (-Not (Test-Path $logFile)) {
        Write-Host "Test Failed: Log file not found." -ForegroundColor Red
        return $false
    }

    $logContent = Get-Content $logFile -Raw

    # Check if the expected output appears in the log.
    if ($logContent -match [regex]::Escape($testCase.Expected)) {
        Write-Host "Test Passed: Expected output found." -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "Test Failed: Expected output not found." -ForegroundColor Red
        Write-Host "Expected to find: $($testCase.Expected)"
        Write-Host "Log Content:`n$logContent"
        return $false
    }
}

# Run each test case and collect results.
$results = foreach ($testCase in $testCases) {
    $result = Run-TestCase $testCase
    [PSCustomObject]@{
        TestCase = $testCase.Name
        Passed   = $result
    }
}

# Display a summary.
Write-Host "`nTest Summary:" -ForegroundColor Yellow
$results | Format-Table -AutoSize

# Exit with a nonzero code if any tests failed.
if ($results.Passed -contains $false) {
    Write-Host "Some tests failed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed." -ForegroundColor Green
    exit 0
}
