# Comprehensive Edge Case Test Suite
Write-Host "=== Comprehensive Edge Case Tests ===" -ForegroundColor Cyan

$passed = 0
$failed = 0

# Test 1: Empty String
Write-Host "`nTest 1: Empty String" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -EmptyString '' | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "EmptyString: '' \(Length: 0\)") {
    Write-Host "  PASSED: Empty string handled correctly" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Empty string not handled" -ForegroundColor Red
    $failed++
}

# Test 2: Path with Spaces (using forward slashes)
Write-Host "`nTest 2: Path with Spaces" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -PathWithSpaces 'C:/Program Files/Test Path' | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "PathWithSpaces: 'C:.*Program Files.*Test Path'") {
    Write-Host "  PASSED: Path with spaces handled correctly" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Path with spaces not handled" -ForegroundColor Red
    $failed++
}

# Test 3: Negative Numbers
Write-Host "`nTest 3: Negative Numbers" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -NegativeNumber "-42" | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "NegativeNumber: -42") {
    Write-Host "  PASSED: Negative numbers handled correctly" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Negative numbers not handled" -ForegroundColor Red
    $failed++
}

# Test 4: Very Long Parameters (200 chars)
Write-Host "`nTest 4: Very Long Parameters (200 chars)" -ForegroundColor Yellow
$longString = 'a' * 200
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -VeryLongParameter $longString | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "VeryLongParameter:.*\(Length: 200\)") {
    Write-Host "  PASSED: Long parameters handled correctly" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Long parameters not handled" -ForegroundColor Red
    Write-Host "  Result: $result"
    $failed++
}

# Test 5: Semicolon Blocking (Security)
Write-Host "`nTest 5: Semicolon Blocking" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -PathWithSpaces 'test;malicious' 2>&1 | Out-Null
if ($LASTEXITCODE -eq 1) {
    Write-Host "  PASSED: Semicolons correctly blocked (security)" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Semicolons not blocked" -ForegroundColor Red
    $failed++
}

# Test 6: Special Characters
Write-Host "`nTest 6: Special Characters" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -PathWithSpaces 'test@file#name&value%test' | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "PathWithSpaces: 'test@file#name&value%test'") {
    Write-Host "  PASSED: Special characters handled correctly" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Special characters not handled" -ForegroundColor Red
    $failed++
}

# Test 7: Unicode Characters
Write-Host "`nTest 7: Unicode Characters" -ForegroundColor Yellow
.\ps-launcher.exe -Script 'edge-case-tests.ps1' -PathWithSpaces 'Test™️Café©' | Out-Null
$result = Get-Content 'edge-test.log' -Raw
if ($result -match "PathWithSpaces: 'Test.*Caf") {
    Write-Host "  PASSED: Unicode characters handled" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  FAILED: Unicode characters not handled" -ForegroundColor Red
    $failed++
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor Red
Write-Host "Total: $($passed + $failed)"

if ($failed -eq 0) {
    Write-Host "`nAll edge case tests PASSED! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests FAILED! ✗" -ForegroundColor Red
    exit 1
}
