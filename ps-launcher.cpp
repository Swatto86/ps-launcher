//--------------------------------------------------------------------------
// C/C++ LANGUAGE FEATURES DEMONSTRATION
//--------------------------------------------------------------------------
// This code demonstrates several important C/C++ concepts:
// - Manual memory management without CRT
// - Function pointers and Windows API usage
// - String manipulation in wide character format
// - Preprocessor directives and conditional compilation
// - Static inline functions for performance
// - Error handling patterns
// - Buffer overflow prevention techniques

#define WIN32_LEAN_AND_MEAN  // PREPROCESSOR: Reduces Windows header size
#include <windows.h>         // HEADERS: Core Windows API types and functions
#include <shellapi.h>        // HEADERS: Shell API for command line parsing

// Buffer size for command line - kept small to avoid stack overflow without CRT
// This is sufficient for most PowerShell scripts with reasonable parameters
#define CMD_BUFFER_SIZE 1024

// Silent mode - disable MessageBox popups for automated execution
// Uncomment the line below to enable error message popups for debugging
// #define ENABLE_ERROR_DIALOGS
#ifndef ENABLE_ERROR_DIALOGS
    #define ShowError(msg, title) ((void)0)  // No-op macro - silent mode
#else
    #define ShowError(msg, title) ShowError(msg, title)
#endif

//--------------------------------------------------------------------------
// MANUAL CRT REPLACEMENT - Low-level memory operations
//--------------------------------------------------------------------------
// FUNCTION LINKAGE: extern "C" prevents C++ name mangling, __cdecl specifies calling convention
// POINTER ARITHMETIC: Direct memory manipulation using unsigned char pointers
// MEMORY SAFETY: Manual bounds checking to prevent buffer overflows
extern "C" void* __cdecl memset(void* dest, int c, size_t count)
{
    // CAST: void* to unsigned char* for byte-level access
    unsigned char* p = (unsigned char*)dest;
    
    // LOOP: Post-decrement operator with short-circuit evaluation
    while (count--)
    {
        // POINTER DEREFERENCING: *p++ is equivalent to *(p++) 
        // CAST: Ensure value fits in unsigned char range
        *p++ = (unsigned char)c;
    }
    return dest;  // RETURN: Original pointer for function chaining
}

//--------------------------------------------------------------------------
// INLINE FUNCTIONS - Performance optimization technique
//--------------------------------------------------------------------------
// STATIC INLINE: Function is inlined at call site, not exported from object file
// CONST CORRECTNESS: 'src' parameter marked const - function won't modify it
// PASS BY REFERENCE: 'curLen' passed as pointer to allow modification
// EARLY RETURN: Guard clause pattern for error handling
static inline bool AppendStr(WCHAR* dest, size_t destSize, const WCHAR* src, size_t* curLen)
{
    // WINDOWS API: lstrlenW returns length of wide character string
    size_t srcLen = lstrlenW(src);
    
    // BOUNDS CHECKING: Prevent buffer overflow before it happens
    if (*curLen + srcLen >= destSize)
        return false;  // EARLY RETURN: Fail fast on boundary condition
    
    //----------------------------------------------------------------------
    // CRITICAL DIFFERENCE: Array indexing vs Pointer arithmetic
    //----------------------------------------------------------------------
    // WHY THE CHANGE MATTERS:
    // 
    // ORIGINAL (caused memcpy generation):
    //   dest[*curLen + i] = src[i];
    // 
    // This pattern tells the compiler:
    // - "Copy a block of memory from src to dest+offset"
    // - Compiler thinks: "This looks like a bulk copy operation"
    // - Optimization: "I'll replace this with memcpy() for efficiency"
    // - Result: Linker error because memcpy is not available
    //
    // NEW APPROACH (prevents memcpy generation):
    //   *destPtr++ = *srcPtr++;
    //
    // This pattern tells the compiler:
    // - "Perform individual pointer operations in sequence"
    // - Compiler thinks: "These are discrete pointer manipulations"
    // - No optimization: "I'll generate the exact assembly requested"
    // - Result: Individual mov instructions, no function calls

    // POINTER SETUP: Calculate addresses once, then iterate
    WCHAR* destPtr = dest + *curLen;  // POINTER ARITHMETIC: dest + offset = target address
    const WCHAR* srcPtr = src;        // CONST POINTER: Read-only source iterator
    
    for (size_t i = 0; i < srcLen; i++)
    {
        // BREAKDOWN OF: *destPtr++ = *srcPtr++;
        //
        // RIGHT SIDE (*srcPtr++):
        // 1. *srcPtr      -> Dereference: Get the value at srcPtr address
        // 2. srcPtr++     -> Post-increment: Move srcPtr to next WCHAR (advances by sizeof(WCHAR) bytes)
        // 3. Order: Use current value, THEN increment pointer
        //
        // LEFT SIDE (*destPtr++):
        // 1. *destPtr     -> Dereference: Access the memory location at destPtr
        // 2. Assignment   -> Store the value from right side
        // 3. destPtr++    -> Post-increment: Move destPtr to next WCHAR position
        //
        // MEMORY LAYOUT EXAMPLE (WCHAR = 2 bytes):
        // Before: srcPtr points to address 0x1000, destPtr points to 0x2000
        // Action: Copy value at 0x1000 to 0x2000
        // After:  srcPtr points to 0x1002, destPtr points to 0x2002
        //
        // COMPILER PERSPECTIVE:
        // - Sees: Individual load instruction, individual store instruction, two increment operations
        // - Doesn't recognize this as a "block copy" pattern
        // - Generates: Discrete assembly instructions instead of function call
        
        *destPtr++ = *srcPtr++;  // ATOMIC OPERATION: Copy one character and advance both pointers
        
        // EQUIVALENT VERBOSE CODE (what the compiler generates):
        // WCHAR temp = *srcPtr;    // Load source value
        // *destPtr = temp;         // Store to destination  
        // srcPtr = srcPtr + 1;     // Advance source pointer (by sizeof(WCHAR))
        // destPtr = destPtr + 1;   // Advance dest pointer (by sizeof(WCHAR))
    }
    
    //----------------------------------------------------------------------
    // WHY THIS MATTERS IN MINIMAL EXECUTABLE CONTEXT:
    //----------------------------------------------------------------------
    // 1. DEPENDENCY CONTROL: We decide exactly which functions we need
    // 2. SIZE OPTIMIZATION: No unexpected function calls = smaller binary
    // 3. PREDICTABLE BEHAVIOR: Assembly output matches our expectations
    // 4. SECURITY: No hidden dependencies that could be attack vectors
    // 5. DEBUGGING: Easier to trace execution without library function calls
    //
    // PERFORMANCE NOTE: 
    // - This is actually SLOWER than memcpy in most cases
    // - But for small strings in this context, the difference is negligible
    // - The predictability and size benefits outweigh the minor performance cost
    
    // POINTER DEREFERENCING: Modify caller's variable through pointer
    *curLen += srcLen;
    dest[*curLen] = L'\0';  // WIDE STRING: L prefix for wide character literal
    return true;  // SUCCESS RETURN: Boolean return for error checking
}

//--------------------------------------------------------------------------
// HELPER FUNCTIONS - String processing utilities
//--------------------------------------------------------------------------
// Check if a string contains spaces, quotes, or special characters that need quoting
static inline bool NeedsQuoting(const WCHAR* str)
{
    if (!str || str[0] == L'\0') return true;  // Empty strings always need quotes
    
    for (size_t i = 0; str[i] != L'\0'; i++)
    {
        if (str[i] == L' ' || str[i] == L'\t' || str[i] == L'"')
            return true;
    }
    return false;
}

// Escape internal quotes in a string by doubling them for PowerShell
// Returns false if buffer overflow would occur
static inline bool AppendEscaped(WCHAR* dest, size_t destSize, const WCHAR* src, size_t* curLen)
{
    for (size_t i = 0; src[i] != L'\0'; i++)
    {
        if (src[i] == L'"')
        {
            // Escape quote by doubling it
            if (!AppendStr(dest, destSize, L"\\\"", curLen))
                return false;
        }
        else
        {
            // Regular character - append it
            WCHAR temp[2] = { src[i], L'\0' };
            if (!AppendStr(dest, destSize, temp, curLen))
                return false;
        }
    }
    return true;
}

//--------------------------------------------------------------------------
// WINDOWS ENTRY POINT - Application lifecycle management
//--------------------------------------------------------------------------
// CALLING CONVENTION: WINAPI expands to __stdcall on Windows
// PARAMETER HANDLING: Unused parameters marked to suppress compiler warnings
// RESOURCE MANAGEMENT: Manual cleanup of allocated memory
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow)
{
    // COMPILER PRAGMA: Suppress warnings about unused parameters
    UNREFERENCED_PARAMETER(hInst);
    UNREFERENCED_PARAMETER(hPrev);
    UNREFERENCED_PARAMETER(lpCmdLine);
    UNREFERENCED_PARAMETER(nCmdShow);

    //----------------------------------------------------------------------
    // COMMAND LINE PARSING - Dynamic memory allocation
    //----------------------------------------------------------------------
    // VARIABLE INITIALIZATION: Local variables on stack
    int argc = 0;
    
    // WINDOWS API: CommandLineToArgvW returns dynamically allocated array
    // POINTER TO POINTER: LPWSTR* is array of wide string pointers
    LPWSTR* args = CommandLineToArgvW(GetCommandLineW(), &argc);
    
    // ERROR HANDLING: Check for allocation failure
    if (!args)
    {
        // WINDOWS API: MessageBoxW for user feedback
        ShowError(L"Failed to parse command line.", L"Error");
        return 1;  // ERROR CODE: Non-zero indicates failure
    }

    //----------------------------------------------------------------------
    // INPUT VALIDATION - Defensive programming
    //----------------------------------------------------------------------
    // LOGICAL OPERATORS: Short-circuit evaluation with ||
    // STRING COMPARISON: Case-insensitive wide string comparison
    if (argc < 3 || lstrcmpiW(args[1], L"-Script") != 0)
    {
        // MULTI-LINE STRING LITERAL: Using L"" for wide strings
        MessageBoxW(NULL,
            L"PS-Launcher Usage:\n\n"
            L"ps-launcher.exe -Script <script_path> [parameters]\n\n"
            L"Examples:\n"
            L"  ps-launcher.exe -Script test.ps1\n"
            L"  ps-launcher.exe -Script test.ps1 -FilePath \"C:\\temp\\test.txt\"\n"
            L"  ps-launcher.exe -Script test.ps1 -FileList \"file1.txt,file2.txt\"\n"
            L"  ps-launcher.exe -Script test.ps1 -Name \"John Doe\" -Verbose\n\n"
            L"Notes:\n"
            L"- Parameters with spaces must be quoted\n"
            L"- Array parameters should be comma-separated within quotes\n"
            L"- Returns 0 for success, 1 for errors or if no script specified",
            L"PS-Launcher Help", MB_OK | MB_ICONINFORMATION);
        
        // RESOURCE CLEANUP: Always free allocated memory before return
        LocalFree(args);
        return 1;
    }

    //----------------------------------------------------------------------
    // PATH CONSTRUCTION - String manipulation and validation
    //----------------------------------------------------------------------
    // ARRAY INITIALIZATION: Zero-initialize with = {0} syntax
    WCHAR psPath[MAX_PATH] = { 0 };
    
    // WINDOWS API: Get system directory for security
    UINT len = GetSystemDirectoryW(psPath, MAX_PATH);
    
    // BOUNDARY CHECKING: Validate return values
    if (len == 0 || len > MAX_PATH - 1)
    {
        LocalFree(args);  // CLEANUP: Always free before error return
        ShowError(L"Failed to get system directory.", L"Error");
        return 1;
    }
    
    // STRING MANIPULATION: Ensure proper path separator
    if (psPath[len - 1] != L'\\')
    {
        // NESTED IF: Check space availability before modification
        if (len < MAX_PATH - 1)
        {
            psPath[len] = L'\\';        // ARRAY ACCESS: Direct character assignment
            psPath[len + 1] = L'\0';    // NULL TERMINATION: Explicit string ending
        }
        else
        {
            LocalFree(args);
            ShowError(L"System directory path too long.", L"Error");
            return 1;
        }
    }
    
    // CONST POINTER: String literal stored in read-only memory
    const WCHAR* psRelative = L"WindowsPowerShell\\v1.0\\powershell.exe";
    
    // STRING LENGTH: Check combined length before concatenation
    if (lstrlenW(psPath) + lstrlenW(psRelative) >= MAX_PATH)
    {
        LocalFree(args);
        ShowError(L"PowerShell path too long.", L"Error");
        return 1;
    }
    
    // STRING CONCATENATION: Windows API string append function
    lstrcatW(psPath, psRelative);

    //----------------------------------------------------------------------
    // FILE VALIDATION - File system operations
    //----------------------------------------------------------------------
    // WINDOWS API: Check if file exists (returns INVALID_FILE_ATTRIBUTES if not found)
    if (GetFileAttributesW(psPath) == INVALID_FILE_ATTRIBUTES)
    {
        LocalFree(args);
        ShowError(L"PowerShell executable not found.", L"Error");
        return 1;
    }

    // ARRAY INDEXING: args[2] is the script path parameter
    if (GetFileAttributesW(args[2]) == INVALID_FILE_ATTRIBUTES)
    {
        LocalFree(args);
        ShowError(L"Specified script file not found.", L"Error");
        return 1;
    }

    //----------------------------------------------------------------------
    // COMMAND LINE BUILDING - Fixed buffer string operations
    //----------------------------------------------------------------------
    // STACK ALLOCATION: Fixed-size array on stack (faster than heap allocation)
    WCHAR cmd[CMD_BUFFER_SIZE];
    size_t pos = 0;  // POSITION TRACKING: Index into buffer

    // MANUAL STRING BUILDING: Character-by-character construction
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';  // POST-INCREMENT: Use current value, then increment
        cmd[pos] = L'\0';    // ALWAYS NULL-TERMINATE: Maintain valid string state
    }
    else
    {
        // ERROR HANDLING: Buffer overflow prevention
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }
    
    // FUNCTION CALL: Using our custom string append function
    // PASS BY REFERENCE: &pos allows function to modify our local variable
    if (!AppendStr(cmd, CMD_BUFFER_SIZE, psPath, &pos))
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }
    
    // REPEAT PATTERN: Same overflow checking for each append operation
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
    }
    else
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }

    // LONG STRING LITERAL: PowerShell command line switches
    if (!AppendStr(cmd, CMD_BUFFER_SIZE,
            L" -NonInteractive -NoProfile -ExecutionPolicy Bypass -File ", &pos))
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }

    // SCRIPT PATH: Add quoted script filename
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
    }
    else
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }
    
    if (!AppendStr(cmd, CMD_BUFFER_SIZE, args[2], &pos))
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }
    
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
    }
    else
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }

    //----------------------------------------------------------------------
    // PARAMETER PROCESSING - Loop constructs and security filtering
    //----------------------------------------------------------------------
    // FOR LOOP: C-style loop with initialization, condition, increment
    for (int i = 3; i < argc; i++)
    {
        // NESTED LOOP: Character-by-character security scanning
        // INNER LOOP: Check each character in the argument
        for (size_t j = 0; j < lstrlenW(args[i]); j++)
        {
            // SECURITY CHECK: Prevent command injection
            if (args[i][j] == L';')
            {
                LocalFree(args);
                // Silent failure - return exit code 1 for semicolon injection attempts
                return 1;
            }
        }

        // ADD SPACE SEPARATOR
        if (!AppendStr(cmd, CMD_BUFFER_SIZE, L" ", &pos))
        {
            LocalFree(args);
            // Silent failure - buffer overflow
            return 1;
        }
        
        // ENHANCED PARAMETER HANDLING: Properly quote and escape parameters
        // Check if parameter is already quoted (starts and ends with quotes)
        size_t argLen = lstrlenW(args[i]);
        bool alreadyQuoted = (argLen >= 2 && args[i][0] == L'\"' && args[i][argLen - 1] == L'\"');
        
        if (alreadyQuoted)
        {
            // ALREADY QUOTED: Use parameter as-is
            if (!AppendStr(cmd, CMD_BUFFER_SIZE, args[i], &pos))
            {
                LocalFree(args);
                ShowError(L"Buffer overflow error.", L"Error");
                return 1;
            }
        }
        else
        {
            // UNQUOTED OR NEEDS QUOTING: Add quotes and escape internal quotes
            if (!AppendStr(cmd, CMD_BUFFER_SIZE, L"\"", &pos))
            {
                LocalFree(args);
                ShowError(L"Buffer overflow error.", L"Error");
                return 1;
            }
            
            // Check if parameter contains internal quotes that need escaping
            bool hasInternalQuotes = false;
            for (size_t j = 0; args[i][j] != L'\0'; j++)
            {
                if (args[i][j] == L'\"')
                {
                    hasInternalQuotes = true;
                    break;
                }
            }
            
            if (hasInternalQuotes)
            {
                // Escape internal quotes
                if (!AppendEscaped(cmd, CMD_BUFFER_SIZE, args[i], &pos))
                {
                    LocalFree(args);
                    ShowError(L"Buffer overflow error.", L"Error");
                    return 1;
                }
            }
            else
            {
                // No internal quotes, append normally
                if (!AppendStr(cmd, CMD_BUFFER_SIZE, args[i], &pos))
                {
                    LocalFree(args);
                    ShowError(L"Buffer overflow error.", L"Error");
                    return 1;
                }
            }
            
            if (!AppendStr(cmd, CMD_BUFFER_SIZE, L"\"", &pos))
            {
                LocalFree(args);
                ShowError(L"Buffer overflow error.", L"Error");
                return 1;
            }
        }
    }

    // MEMORY CLEANUP: Free dynamically allocated command line array
    LocalFree(args);

    //----------------------------------------------------------------------
    // PROCESS CREATION - Windows API structures and process management
    //----------------------------------------------------------------------
    // STRUCTURE INITIALIZATION: Stack-allocated Windows API structures
    STARTUPINFOW si;           // STARTUP INFO: How to start the process
    ZeroMemory(&si, sizeof(si)); // MEMORY ZEROING: Initialize all fields to 0
    si.cb = sizeof(si);        // STRUCTURE SIZE: Required by Windows API
    
    PROCESS_INFORMATION pi;    // PROCESS INFO: Receives process/thread handles
    ZeroMemory(&pi, sizeof(pi));

    // WINDOWS API: CreateProcessW launches new process
    // PARAMETER LIST: NULL for app name (use command line), cmd for command line
    // BOOLEAN FLAGS: FALSE for inherit handles, CREATE_NO_WINDOW for process creation flags
    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
                          CREATE_NO_WINDOW, NULL, NULL, &si, &pi))
    {
        // ERROR HANDLING: Get detailed error information
        DWORD err = GetLastError();  // WINDOWS ERROR CODE: System error number
        
        // ERROR MESSAGE FORMATTING: Convert error code to human-readable text
        WCHAR errMsg[256];  // FIXED BUFFER: For error message
        FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                       NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                       errMsg, 256, NULL);

        // CONDITIONAL COMPILATION: Different behavior for debug vs release builds
#ifdef _DEBUG
        // DEBUG BUILD: Show command line for troubleshooting
        WCHAR debugMsg[CMD_BUFFER_SIZE + 300];  // LARGER BUFFER: For combined message
        // WINDOWS API: Formatted string printing (like sprintf)
        wsprintfW(debugMsg, L"Error: %s\n\nCommand: %s", errMsg, cmd);
        ShowError(debugMsg, L"Process Creation Failed");
#else
        // RELEASE BUILD: Show only error message
        ShowError(errMsg, L"Process Creation Failed");
#endif
        return err;  // RETURN ERROR CODE: Pass through system error
    }

    //----------------------------------------------------------------------
    // PROCESS SYNCHRONIZATION - Wait for completion and get exit code
    //----------------------------------------------------------------------
    // WINDOWS API: Block until process completes
    WaitForSingleObject(pi.hProcess, INFINITE);
    
    // EXIT CODE RETRIEVAL: Get the return value from PowerShell process
    DWORD exitCode = 0;  // INITIALIZATION: Default to success
    GetExitCodeProcess(pi.hProcess, &exitCode);
    
    // HANDLE CLEANUP: Always close handles to prevent resource leaks
    CloseHandle(pi.hProcess);   // PROCESS HANDLE: Main process
    CloseHandle(pi.hThread);    // THREAD HANDLE: Primary thread
    
    // RETURN: Pass through PowerShell's exit code to caller
    return exitCode;
}

//--------------------------------------------------------------------------
// RECOMMENDED IMPROVEMENTS
//--------------------------------------------------------------------------
/*
1. ENHANCED ERROR HANDLING:
   - Add structured exception handling (__try/__except)
   - Implement error logging to file or event log
   - Add retry logic for transient failures

2. SECURITY ENHANCEMENTS:
   - Validate script file signatures/hashes
   - Implement more comprehensive parameter sanitization
   - Add privilege checking before execution
   - Use CreateProcessAsUser for specific user context

3. PERFORMANCE OPTIMIZATIONS:
   - Use string builder pattern for command construction
   - Implement buffer pooling for repeated use
   - Add caching for PowerShell path lookup

4. ROBUSTNESS IMPROVEMENTS:
   - Add timeout support for process execution
   - Implement signal handling for graceful shutdown
   - Add configuration file support for default parameters

5. DEBUGGING FEATURES:
   - Add verbose logging mode
   - Implement trace functionality
   - Add memory usage monitoring

6. CODE ORGANIZATION:
   - Split into multiple functions for better maintainability
   - Add unit tests for string manipulation functions
   - Implement RAII pattern for resource management

7. MODERN C++ FEATURES (if C++ is acceptable):
   - Use std::wstring for string operations
   - Implement RAII with smart pointers
   - Add exception safety guarantees

8. CROSS-PLATFORM CONSIDERATIONS:
   - Abstract Windows-specific code behind interfaces
   - Add support for PowerShell Core (.NET)
   - Implement configuration for different PowerShell versions
*/