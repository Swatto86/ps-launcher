# PS-Launcher

A minimal, secure PowerShell script launcher that produces executables under 15KB without requiring the C Runtime Library.

## Overview

PS-Launcher is a lightweight Windows executable that safely launches PowerShell scripts with parameters while implementing security best practices. It's designed for scenarios where you need a small, standalone executable to run PowerShell scripts without exposing command-line complexity to end users.

## Features

- **Ultra-small executable** (~8-15KB) using `/NODEFAULTLIB` optimization
- **Security-focused** design preventing PATH hijacking and command injection
- **Parameter passing** support with automatic quoting and validation
- **Comprehensive error handling** with user-friendly messages
- **No dependencies** - runs on any Windows system with PowerShell

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

- Visual Studio 2022 (Community edition or higher)
- Windows 10/11 or Windows Server 2016+

### Compilation

Use the provided batch script:

```cmd
compile.bat
```

Or manually:

```cmd
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
cl /c /GS- /O1 /Os /GR- ps-launcher.cpp
link /NODEFAULTLIB /ENTRY:WinMain /SUBSYSTEM:WINDOWS kernel32.lib user32.lib shell32.lib /OUT:ps-launcher.exe ps-launcher.obj
del *.obj
```

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
- Command line buffer: 520 characters (fixed size)
- Path buffers: `MAX_PATH` (260 characters)
- No dynamic allocation except for command line parsing

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

## Use Cases

- **Automated Deployment** - Wrap complex PowerShell scripts in simple executables
- **User-Friendly Tools** - Hide PowerShell complexity from end users
- **Embedded Systems** - Minimal footprint for resource-constrained environments
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

## Limitations

- **Windows Only** - Uses Windows-specific APIs
- **PowerShell 5.x** - Targets Windows PowerShell (not PowerShell Core)
- **Fixed Buffer Size** - Command line limited to 520 characters
- **Basic Parameter Sanitization** - Only checks for semicolons

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
