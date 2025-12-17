# PS-Launcher

A minimal, secure PowerShell script launcher (under 10KB) that runs PowerShell scripts silently without displaying a console window.

## Overview

PS-Launcher is a lightweight Windows executable designed to run PowerShell scripts **under the current user context** without showing a PowerShell console window. 

### Why PS-Launcher?

When running PowerShell scripts via Task Scheduler, shortcuts, or automation tools, a PowerShell console window typically appears and remains visible during execution. This is distracting for users and unprofessional for automated tasks.

**PS-Launcher solves this by:**
- Running PowerShell scripts completely hidden (no console window)
- Executing under the current user's security context (not SYSTEM)
- Supporting all script parameters and exit codes
- Maintaining full PowerShell functionality while being invisible to users

This is particularly useful for:
- Task Scheduler tasks that run while users are logged in
- Login scripts that map network drives
- Background automation that shouldn't interrupt users
- Professional deployments where UI visibility is undesirable

### Why Not VBScript?

The traditional approach to hiding PowerShell windows has been to use a VBScript wrapper:
```vbscript
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -File script.ps1", 0, True
```

**However, Microsoft announced in October 2023 that VBScript is deprecated and will be removed from Windows in the second half of 2027.** This means VBScript-based solutions will stop working on future Windows versions.

**PS-Launcher is the future-proof alternative:**
- ✅ Native C++ executable - no deprecated runtime dependencies
- ✅ Works on all current and future Windows versions
- ✅ Smaller than .NET alternatives (~6KB vs 100KB+)
- ✅ Zero external dependencies (VBScript required Windows Script Host)
- ✅ Better security controls and logging than VBScript wrappers
- ✅ Professional solution suitable for enterprise deployment

While `powershell.exe -WindowStyle Hidden` seems like it should work, it only hides the window *after* PowerShell starts, causing a brief console flash that defeats the purpose for user-facing automation.

## Features

- **Silent Execution** - Runs PowerShell scripts without showing any console window or error dialogs
- **Current User Context** - Executes scripts with the logged-in user's permissions and environment
- **Ultra-small executable** (~6KB) using `/NODEFAULTLIB` optimization
- **Enhanced Parameter Support** - Handles complex parameters including:
  - Empty strings
  - Paths with spaces
  - Negative numbers
  - Long parameters (up to 1024 characters total command line)
  - Special characters (@, #, &, %, etc.)
  - Unicode characters
  - Internal quotes (automatically escaped)
- **Exit Code Propagation** - Returns the script's exit code for proper error handling
- **Security-focused** - Blocks semicolons to prevent command injection attacks
- **Comprehensive Logging** - Automatic troubleshooting logs in `%LOCALAPPDATA%\ps-launcher\ps-launcher.log`
- **No dependencies** - Runs on any Windows system with PowerShell 5.1+

## Logging

ps-launcher automatically creates a comprehensive log file for troubleshooting purposes:

**Log Location:** `%LOCALAPPDATA%\ps-launcher\ps-launcher.log`  
(e.g., `C:\Users\YourName\AppData\Local\ps-launcher\ps-launcher.log`)

**What's Logged:**
- Command line parsing results
- Script file path validation
- PowerShell executable location
- Complete command line being executed
- Parameter processing details
- Process creation status
- Script exit codes
- Any errors encountered

The log file is **overwritten on each run** (not appended), keeping it manageable and focused on the most recent execution.

### Viewing the Log

```powershell
# Quick view
Get-Content $env:LOCALAPPDATA\ps-launcher\ps-launcher.log

# Open in Notepad
notepad $env:LOCALAPPDATA\ps-launcher\ps-launcher.log

# Tail the log during execution
Get-Content $env:LOCALAPPDATA\ps-launcher\ps-launcher.log -Wait
```

### Disabling Logging

To disable logging (reduce binary size), edit `ps-launcher.cpp` and comment out:
```cpp
// #define ENABLE_LOGGING
```
Then recompile with `compile.bat`.

## Usage

```bash
ps-launcher.exe -Script <script_path> [parameters]
```

### Examples

```bash
# Basic script execution
ps-launcher.exe -Script myscript.ps1

# Script with parameters
ps-launcher.exe -Script backup.ps1 -Path "C:\Data" -Verbose

# Script with multiple parameters
ps-launcher.exe -Script deploy.ps1 -Environment "Production" -Force
```

## Building

### Requirements

- Visual Studio 2022 Build Tools (or any edition)
- Windows 10/11 or Windows Server 2016+

### Compilation

Use the provided batch script:

```cmd
compile.bat
```

Or manually:

```cmd
call "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
cl /c /GS- /O1 /Os /GR- ps-launcher.cpp
link /NODEFAULTLIB /ENTRY:WinMain /SUBSYSTEM:WINDOWS kernel32.lib user32.lib shell32.lib /OUT:ps-launcher.exe ps-launcher.obj
del *.obj
```

**Note:** Adjust the Visual Studio path based on your edition (BuildTools, Community, Professional, or Enterprise).

### Compiler Flags Explained

- `/GS-` - Disable buffer security checks (size optimization)
- `/O1` - Optimize for size
- `/Os` - Favor small code over speed
- `/GR-` - Disable RTTI (reduces size)
- `/NODEFAULTLIB` - Exclude C Runtime Library (major size reduction)
- `/ENTRY:WinMain` - Set entry point (required without CRT)

## Security Features

### PATH Hijacking Prevention
- Uses full system path to PowerShell: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- Validates PowerShell executable exists before execution

### Input Validation
- Verifies script file exists before launching
- Sanitizes parameters to prevent command injection
- Rejects parameters containing semicolons (`;`)

### Safe Parameter Handling
- Automatically quotes parameters containing spaces
- Preserves existing quotes in parameters
- Buffer overflow protection throughout

## Technical Details

### Why So Small?

The executable achieves its minimal size through several techniques:

1. **No C Runtime Library** - Implements only required CRT functions manually
2. **Minimal Windows Headers** - Uses `WIN32_LEAN_AND_MEAN`
3. **Fixed Buffer Allocation** - No dynamic memory allocation
4. **Aggressive Compiler Optimization** - Size-focused compilation flags

### Memory Management

The application uses stack-allocated buffers and minimal heap allocation:
- Command line buffer: 1024 characters (fixed size)
- Path buffers: `MAX_PATH` (260 characters)
- No dynamic allocation except for command line parsing

### Edge Cases Handled

ps-launcher correctly handles various parameter edge cases:

✅ **Empty strings** - Properly passed as empty parameters  
✅ **Paths with spaces** - Automatically quoted (e.g., `C:\Program Files\App`)  
✅ **Negative numbers** - Correctly passed as parameter values (e.g., `-42`)  
✅ **Long parameters** - Supports up to 1024 character total command line  
✅ **Special characters** - Handles `@`, `#`, `&`, `%`, etc.  
✅ **Unicode characters** - Full Unicode support (e.g., `Café`, `™️`)  
✅ **Internal quotes** - Automatically escaped for PowerShell  
⛔ **Semicolons** - Blocked for security (command injection prevention)

### PowerShell Execution

Scripts are launched with these security-focused parameters:
- `-NonInteractive` - Prevents hanging on prompts
- `-NoProfile` - Faster startup, avoids profile scripts
- `-ExecutionPolicy Bypass` - Allows script execution
- `-File` - Specifies script file execution mode

## Code Structure

The codebase demonstrates several important C programming concepts:

- **Manual CRT Implementation** - Custom `memset` and `memcpy` functions
- **Pointer Arithmetic** - Efficient string manipulation without array indexing
- **Windows API Usage** - Process creation, file validation, error handling
- **Buffer Management** - Safe string building with overflow protection
- **Resource Management** - Proper handle cleanup and memory management

## Testing

Run the comprehensive test suite to verify all functionality:

### Main Test Suite

```powershell
.\test.ps1
```

The test suite validates:
- Basic parameter passing
- Scripts with `[CmdletBinding()]`
- Scripts with `[CmdletBinding(SupportsShouldProcess)]`
- Mandatory parameters and error handling
- Exit code propagation
- Parameters with spaces and special characters
- `-Verbose`, `-WhatIf`, and other common parameters

### Edge Case Test Suite

```powershell
.\comprehensive-edge-test.ps1
```

Tests advanced edge cases:
- Empty string parameters
- Paths with spaces
- Negative numbers
- Very long parameters (200+ characters)
- Semicolon injection blocking
- Special characters (@, #, &, %, etc.)
- Unicode characters

## Use Cases

**Task Scheduler** - Run scheduled PowerShell scripts silently without console windows
- **Login Scripts** - Execute user environment setup (drive mapping, etc.) invisibly at logon
- **Background Automation** - Run periodic maintenance tasks without disrupting users
- **Desktop Shortcuts** - Provide users with clickable shortcuts that run scripts silently
- **Group Policy** - Deploy PowerShell scripts that execute without UI distraction
- **Professional Deployments** - Automated tasks that should run invisibly to end userents
- **Security Tools** - Controlled script execution with parameter validation
- **System Administration** - Package maintenance scripts as standalone tools

## Error Handling

The launcher provides detailed error messages for common issues:

- Invalid command line syntax → Usage help dialog
- Missing script file → "Script file not found" error
- Missing PowerShell → "PowerShell executable not found" error
- Invalid parameters → "Invalid character in argument" error
- Process creation failure → System error with details (debug builds include command line)

## Return Codes

- `0` - Success (PowerShell script completed successfully)
- `1` - Application error (invalid arguments, missing files, etc.)
- Other - PowerShell script exit code (passed through)

## Script Requirements for Task Scheduler

For scripts using `[CmdletBinding(SupportsShouldProcess)]` to work properly in non-interactive mode (Task Scheduler, services, etc.), they should set `$ConfirmPreference` internally:

```powershell
[CmdletBinding(SupportsShouldProcess=$true)]
param()

# Handle non-interactive execution
if ([Environment]::UserInteractive -eq $false) {
    $ConfirmPreference = 'None'
}
```

**Why?** When PowerShell runs with `-NonInteractive`, scripts with `$PSCmdlet.ShouldProcess()` calls will skip all confirmation prompts by default. Setting `$ConfirmPreference = 'None'` ensures these operations proceed normally.

**Best Practices:**
1. Scripts without `[CmdletBinding()]` work automatically with ps-launcher
2. Scripts with `[CmdletBinding()]` (no ShouldProcess) work automatically
3. Scripts with `[CmdletBinding(SupportsShouldProcess=$true)]` should set `$ConfirmPreference = 'None'` for non-interactive scenarios

## PowerShell Version Compatibility

PS-Launcher uses **Windows PowerShell 5.x** (`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`), not PowerShell 7+.

**Important:** Scripts must be compatible with PowerShell 5.x:
- Avoid PowerShell 7+ specific features (e.g., `-ProgressAction` common parameter)
- Test scripts with `powershell.exe` (not `pwsh.exe`) before deployment
- Use UTF-8 with BOM encoding for best compatibility
- PowerShell 5.x has stricter parsing - avoid complex string interpolation with pipe characters

## Limitations

- **Windows Only** - Uses Windows-specific APIs
- **PowerShell 5.x** - Targets Windows PowerShell (not PowerShell Core/7+)
- **Fixed Buffer Size** - Command line limited to 520 characters
- **Basic Parameter Sanitization** - Only checks for semicolons
- **Script Compatibility** - Scripts must be PowerShell 5.x compatible

## Contributing

Contributions are welcome! Areas for improvement:

- Enhanced parameter sanitization
- Support for PowerShell Core
- Configuration file support
- Timeout handling for long-running scripts
- Digital signature validation
- Enhanced logging capabilities

## License

This project is released under the MIT License. See `LICENSE` file for details.

## Security Considerations

While this launcher implements several security measures, always review and validate:

- The PowerShell scripts being executed
- Parameter validation requirements for your use case
- Network and file system access requirements
- Execution context and user privileges

## Educational Value

This project serves as an excellent example of:

- Minimal Windows executable creation
- C programming without the C Runtime Library
- Windows API usage patterns
- Security-conscious programming practices
- Compiler optimization techniques
- Memory management in constrained environments

## Troubleshooting

### Common Build Issues

**Linker Error LNK2019 (memcpy)**
- Ensure you're using the latest version with explicit pointer arithmetic in `AppendStr`
- Verify `/NODEFAULTLIB` flag is present

**Large Executable Size**
- Check that `/NODEFAULTLIB` is being used
- Verify optimization flags (`/O1 /Os`) are applied
- Ensure you're building in Release mode

**Runtime Errors**
- Verify PowerShell is installed and accessible
- Check script file paths and permissions
- Review parameter syntax and quoting

### Debug Mode

For troubleshooting, compile with `_DEBUG` defined to get detailed error messages including the constructed command line.
