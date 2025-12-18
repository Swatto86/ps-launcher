# Demo script to show internal quote escaping
[CmdletBinding()]
param([string]$QuotedText, [string]$Message)

Write-Host "QuotedText parameter received: '$QuotedText'" -ForegroundColor Green
Write-Host "Message parameter received: '$Message'" -ForegroundColor Green

# Show the raw value
Write-Host "`nRaw values:" -ForegroundColor Cyan
Write-Host "  QuotedText length: $($QuotedText.Length) chars"
Write-Host "  Message length: $($Message.Length) chars"

# Test that quotes are preserved
if ($QuotedText -match [char]34) {  # ASCII 34 = double quote
    Write-Host "`n✓ PASS: Internal double quotes preserved!" -ForegroundColor Green
} else {
    Write-Host "`n✗ FAIL: Internal double quotes not preserved" -ForegroundColor Red
}

if ($Message -match [char]39) {  # ASCII 39 = apostrophe/single quote
    Write-Host "✓ PASS: Apostrophes preserved!" -ForegroundColor Green
} else {
    Write-Host "✗ FAIL: Apostrophes not preserved" -ForegroundColor Red
}

exit 0
