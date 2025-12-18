# PS-Launcher Development Guide

## Project Purpose
A minimal (~6KB) Windows C++ executable that launches PowerShell scripts silently (no console window) under the current user context. Built as a future-proof replacement for deprecated VBScript wrappers.

## Core Development Principles

### Build Integrity
- **All code MUST compile and run without errors or warnings** - run `compile.bat` after every change
- **System MUST remain functional after every modification** - test with `.\test.ps1` before committing
- **No partial implementations** - features are either complete and tested, or not present
- **Incremental changes** - make small, independently correct modifications that maintain working state

### Error Handling Requirements
- **All error cases MUST be handled explicitly** - see error handling patterns in [ps-launcher.cpp](../ps-launcher.cpp) lines 322-340
- **No silent failures** - return non-zero exit codes and log errors to `%LOCALAPPDATA%\ps-launcher\ps-launcher.log`
- **Always cleanup resources** - call `LocalFree(args)` before every return path from `WinMain()`
- **Buffer overflow prevention** - check bounds before every string append operation

### Security by Design
- **Treat all external input as untrusted** - validate script paths and scan parameters for injection attempts
- **Secure defaults enforced** - full PowerShell path prevents PATH hijacking
- **Input validation** - reject semicolons to block command injection ([ps-launcher.cpp](../ps-launcher.cpp) lines 544-556)
- **Parameter sanitization** - automatic quote escaping for special characters ([ps-launcher.cpp](../ps-launcher.cpp) lines 196-228)
- **Principle of least privilege** - runs under current user context, not SYSTEM

### Testing Discipline
- **Every public function MUST be tested** - see comprehensive test suite in [test.ps1](../test.ps1)
- **Test failure scenarios, not just happy paths** - includes tests for mandatory parameters, thrown errors, command injection
- **Every bug fix MUST include a regression test** - add to [test.ps1](../test.ps1) or [edge-case-tests.ps1](../edge-case-tests.ps1)
- **Test with real data** - tests create actual PowerShell scripts and execute them through ps-launcher.exe
- **Exit code validation** - verify PowerShell exit codes propagate correctly (tests cover 0, 1, 42, etc.)

### Documentation Standards
- **Document WHY, not just WHAT** - see extensive inline comments explaining pointer arithmetic rationale
- **Complex logic requires inline explanation** - `AppendStr()` includes 80+ lines explaining compiler behavior
- **Non-obvious decisions must have rationale** - e.g., why pointer arithmetic prevents memcpy generation
- **Update documentation immediately with behavior changes** - keep [README.md](../README.md), tests, and code synchronized
- **Unsafe operations documented with risk** - `/NODEFAULTLIB` risks explained in compile flags section

### Observability
- **All executions logged** - comprehensive logs to `%LOCALAPPDATA%\ps-launcher\ps-launcher.log`
- **Logs enable event reconstruction** - includes command line, script path, exit codes, errors
- **No sensitive data in logs** - parameters logged but never assume they contain secrets
- **Toggle logging via `#define ENABLE_LOGGING`** - can be disabled to reduce binary size

## Architecture Decisions

### Platform-Specific Isolation
Platform-specific behavior is isolated to Windows API calls. Core logic (string handling, parameter processing) uses platform boundaries:
- **String manipulation** - `AppendStr()`, `AppendEscaped()` functions are platform-agnostic patterns
- **Windows API boundaries** - `CreateProcessW`, `GetSystemDirectoryW`, `SHGetFolderPathW` isolated to main execution flow
- **Logging abstraction** - `#ifdef ENABLE_LOGGING` provides clean separation of cross-cutting concern

### Why No CRT (`/NODEFAULTLIB`)?
The executable excludes the C Runtime Library to achieve ultra-small binary size (~6KB vs 100KB+). This requires:
- **Custom implementations** of `memset()` in [ps-launcher.cpp](../ps-launcher.cpp) lines 38-51
- **Manual string operations** using Windows API (`lstrlenW`, `lstrcatW`, `lstrcmpiW`)
- **Static inline functions** for string manipulation (see `AppendStr()` at [ps-launcher.cpp](../ps-launcher.cpp) lines 59-141)
- **Fixed-size stack buffers** (`CMD_BUFFER_SIZE=1024`) - no dynamic allocation

### Pointer Arithmetic vs Array Indexing
The `AppendStr()` function uses **pointer arithmetic** (`*destPtr++ = *srcPtr++`) instead of array indexing to prevent the compiler from generating `memcpy()` calls. This is critical because memcpy doesn't exist without the CRT. See detailed explanation at [ps-launcher.cpp](../ps-launcher.cpp) lines 60-140.

### Security Hardening
- **PATH hijacking prevention**: Uses full path `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- **Command injection blocking**: Rejects any parameter containing semicolons (see [ps-launcher.cpp](../ps-launcher.cpp) lines 544-556)
- **Parameter escaping**: Automatically handles quotes and special characters ([ps-launcher.cpp](../ps-launcher.cpp) lines 196-228)

## Build Process

### Compile Command
```cmd
compile.bat
```
Internally runs: `cl /c /GS- /O1 /Os /GR- ps-launcher.cpp` then `link /NODEFAULTLIB /ENTRY:WinMain /SUBSYSTEM:WINDOWS kernel32.lib user32.lib shell32.lib`

**Critical flags:**
- `/NODEFAULTLIB` - No CRT (requires manual function implementations)
- `/ENTRY:WinMain` - Custom entry point without CRT initialization
- `/GS-` - No buffer security checks (size optimization)
- `/SUBSYSTEM:WINDOWS` - GUI subsystem (hides console)

### Debugging Build Issues
If you see linker errors about missing CRT functions (memcpy, memset, etc.), check that:
1. All string operations use pointer arithmetic, not array indexing
2. No inadvertent calls to CRT functions
3. `/NODEFAULTLIB` flag is present

## Testing Strategy

### Test Requirements
- **Tests use real data, not mocks** - [test.ps1](../test.ps1) creates actual PowerShell scripts and executes them
- **Failure scenarios mandatory** - tests MUST cover error cases, not just happy paths
- **Input validation testing** - [edge-case-tests.ps1](../edge-case-tests.ps1) validates boundary conditions
- **Regression tests required** - every fixed bug needs a test case to prevent recurrence
- **Exit code verification** - tests validate correct propagation of PowerShell exit codes (0, 1, 42, etc.)

### Test Files
- [test.ps1](../test.ps1) - Comprehensive automated tests (CmdletBinding, exit codes, error handling)
- [edge-case-tests.ps1](../edge-case-tests.ps1) - Parameter edge cases (empty strings, spaces, special chars)
- [comprehensive-edge-test.ps1](../comprehensive-edge-test.ps1) - Additional edge case validation

### Running Tests
```powershell
.\test.ps1
```
Tests create temporary scripts (`test-basic.ps1`, `test-cmdletbinding.ps1`, etc.) and validate:
- Exit code propagation (PowerShell exit codes must pass through)
- Parameter handling (spaces, quotes, Unicode, special characters)
- CmdletBinding features (-Verbose, -WhatIf, -Confirm)
- Error scenarios (mandatory parameters, thrown exceptions)
- Security boundaries (command injection attempts with semicolons)

### Test Coverage Requirements
When adding features, tests MUST include:
- **Success case** - feature works as expected with valid input
- **Failure cases** - invalid input, missing parameters, file not found
- **Boundary conditions** - empty strings, maximum buffer size, special characters
- **Corruption scenarios** - malformed input, injection attempts
- **Partial success** - what happens when intermediate steps fail

### Logs for Debugging
All executions write to `%LOCALAPPDATA%\ps-launcher\ps-launcher.log` (overwritten each run). View with:
```powershell
notepad $env:LOCALAPPDATA\ps-launcher\ps-launcher.log
```

## Code Conventions

### String Handling
- Use `WCHAR*` (wide strings) with `L""` literals
- Always check buffer sizes before appending (`if (!AppendStr(...)) return error;`)
- Prefer `AppendStr()` over manual concatenation to prevent memcpy generation
- Use `lstrcmpiW()` for case-insensitive comparison, `lstrlenW()` for length

### Error Handling Patterns
- **Non-zero exit codes indicate failure** - propagate PowerShell exit codes to caller
- **Silent mode by default** - `ENABLE_ERROR_DIALOGS` not defined to prevent UI popups in automation
- **Resource cleanup on all paths** - `LocalFree(args)` MUST be called before every return from `WinMain()`
- **Explicit error checking** - validate every Windows API return value before proceeding
- **Fail fast on misconfiguration** - invalid arguments return exit code 1 immediately

### Adding Features - Required Steps
When modifying code, follow this sequence:

1. **Clarify requirements** - surface ambiguity before implementation, present trade-offs
2. **Design with safety defaults** - favor safe behavior over convenience
3. **Maintain minimal size** - avoid introducing CRT dependencies or increasing binary past 10KB
4. **Check buffer boundaries** - add overflow prevention to any new string operations
5. **Add security validation** - validate and sanitize new inputs following existing patterns
6. **Test with compile.bat** - ensure code compiles without errors or warnings
7. **Write comprehensive tests** - add test cases to [test.ps1](../test.ps1) covering success, failure, and edge cases
8. **Test edge cases separately** - add parameter edge cases to [edge-case-tests.ps1](../edge-case-tests.ps1)
9. **Run full test suite** - execute `.\test.ps1` to verify no regressions
10. **Update documentation** - modify [README.md](../README.md) immediately, explaining why not just what
11. **Verify single source of truth** - ensure code, tests, and docs don't contradict each other

## Common Tasks

### Disable Logging (Reduce Size)
Comment out line 27 in [ps-launcher.cpp](../ps-launcher.cpp):
```cpp
// #define ENABLE_LOGGING
```

### Add Error Dialogs for Debugging
Uncomment line 30 in [ps-launcher.cpp](../ps-launcher.cpp):
```cpp
#define ENABLE_ERROR_DIALOGS
```

### Modify Buffer Size
Change `CMD_BUFFER_SIZE` at line 15 in [ps-launcher.cpp](../ps-launcher.cpp) but keep it reasonable to avoid stack overflow without CRT.

## Key Files
- [ps-launcher.cpp](../ps-launcher.cpp) - Main executable source (761 lines, extensively commented)
- [compile.bat](../compile.bat) - Build script
- [README.md](../README.md) - User-facing documentation
- [LICENSE](../LICENSE) - Project license
