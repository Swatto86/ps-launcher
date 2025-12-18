# PS-Launcher Source Code Explained

## Table of Contents
1. [What This Program Does](#what-this-program-does)
2. [Why It's Written This Way](#why-its-written-this-way)
3. [Understanding the Structure](#understanding-the-structure)
4. [Detailed Section Breakdown](#detailed-section-breakdown)
5. [Key Programming Concepts Used](#key-programming-concepts-used)

---

## What This Program Does

**In Simple Terms**: This program is like a "silent launcher" for PowerShell scripts. When you run a PowerShell script normally, a black console window pops up. This program runs those same scripts but keeps everything hidden in the background.

**Real-World Example**: Imagine you have a script that backs up your files every morning. Without PS-Launcher, you'd see a black window flash on your screen. With PS-Launcher, the backup happens silently while you work.

**How You Use It**:
```
ps-launcher.exe -Script MyScript.ps1 -Parameter1 "value" -Parameter2 "value"
```

---

## Why It's Written This Way

### Pure C Language
The code is written in **pure C** (not C++, not C#) for several important reasons:

1. **Tiny File Size**: The compiled program is only ~6KB (smaller than most images!)
2. **No Dependencies**: Doesn't need any extra files or libraries to run
3. **Fast**: Starts instantly with no overhead
4. **Educational**: Pure C is great for learning how computers really work

### No Standard C Library
Most programs use the "C Runtime Library" (CRT) which provides common functions. This program **doesn't use the CRT** to stay ultra-small. This means:
- We have to write our own versions of common functions like `memset`
- We use Windows API functions directly instead
- We're very careful about memory and buffer sizes

---

## Understanding the Structure

The source code is organized into these major sections:

```
┌─────────────────────────────────────┐
│ 1. Setup & Configuration           │  Lines 1-40
│    (What to include, settings)      │
├─────────────────────────────────────┤
│ 2. Custom Memory Functions          │  Lines 42-61
│    (Replacing standard functions)   │
├─────────────────────────────────────┤
│ 3. String Manipulation Functions    │  Lines 63-191
│    (Building text safely)           │
├─────────────────────────────────────┤
│ 4. Logging Functions                │  Lines 193-329
│    (Recording what happens)         │
├─────────────────────────────────────┤
│ 5. Main Program (WinMain)           │  Lines 331-701
│    (The actual work)                │
├─────────────────────────────────────┤
│ 6. Improvement Suggestions          │  Lines 703-748
│    (Ideas for future enhancements)  │
└─────────────────────────────────────┘
```

---

## Detailed Section Breakdown

### Section 1: Setup & Configuration (Lines 1-40)

#### What It Does
Sets up the programming environment and defines important settings.

#### Line-by-Line Explanation

**Lines 1-12: Header Comments**
```c
// C LANGUAGE FEATURES DEMONSTRATION
```
This is just documentation explaining what the code demonstrates. Think of it like a book's table of contents.

**Line 14: `#define WIN32_LEAN_AND_MEAN`**
```c
#define WIN32_LEAN_AND_MEAN
```
**Plain English**: "When including Windows code, only include the essential parts."
- Windows has thousands of functions we don't need
- This line tells the compiler to skip the extras
- Result: Faster compilation, smaller program

**Lines 15-17: Include Windows Headers**
```c
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
```
**Plain English**: "Give me access to Windows functions."
- `windows.h` = Basic Windows functions (like creating processes)
- `shellapi.h` = Command line parsing functions
- `shlobj.h` = File path functions (like finding AppData folder)

**Lines 19-22: Boolean Type Definitions**
```c
#define bool int
#define true 1
#define false 0
```
**Plain English**: "C doesn't have true/false built-in, so let's create them."
- C++ has `bool`, `true`, `false` built-in
- Pure C doesn't, so we define them ourselves
- `bool` becomes an integer (0 or 1)
- `true` = 1, `false` = 0

**Lines 25-27: Buffer Size Definitions**
```c
#define CMD_BUFFER_SIZE 1024
#define LOG_BUFFER_SIZE 1024
```
**Plain English**: "Set aside space for text we'll build."
- Command line can hold 1024 characters
- Log messages can hold 1024 characters
- Fixed sizes prevent memory issues
- Think of these as reserving specific-sized boxes for text

**Line 30: Enable Logging**
```c
#define ENABLE_LOGGING
```
**Plain English**: "Turn on detailed logging of what happens."
- When defined, the program writes a detailed log file
- Comment this out to disable logging (saves space)
- Log goes to: `C:\Users\YourName\AppData\Local\ps-launcher\ps-launcher.log`

**Lines 33-39: Error Dialog Configuration**
```c
#ifndef ENABLE_ERROR_DIALOGS
    #define ShowError(msg, title) ((void)0)
#else
    #define ShowError(msg, title) ShowError(msg, title)
#endif
```
**Plain English**: "Control whether to show error popup windows."
- By default, errors are silent (good for automated tasks)
- Uncomment `#define ENABLE_ERROR_DIALOGS` to see error popups
- `((void)0)` means "do nothing" - it's a no-op

---

### Section 2: Custom Memory Functions (Lines 42-61)

#### What It Does
Replaces the standard `memset` function that we can't use (because we excluded the CRT).

#### The `memset` Function Explained

**What `memset` Does**: Fills a chunk of memory with a specific value.

**Real-World Analogy**: Imagine you have 100 empty boxes and want to put a red ball in each box. `memset` is the worker who does this repetitive task.

```c
void* __cdecl memset(void* dest, int c, size_t count)
{
    unsigned char* p = (unsigned char*)dest;
    
    while (count--)
    {
        *p++ = (unsigned char)c;
    }
    return dest;
}
```

**Line-by-Line**:

1. `void* __cdecl memset(void* dest, int c, size_t count)`
   - **Function signature**: Takes 3 inputs
   - `dest` = where to write
   - `c` = what value to write
   - `count` = how many times
   - `__cdecl` = calling convention (how the computer passes parameters)

2. `unsigned char* p = (unsigned char*)dest;`
   - **Cast the pointer**: Convert generic pointer to byte pointer
   - We work with bytes because memory is byte-by-byte

3. `while (count--)`
   - **Loop**: Repeat `count` times
   - `count--` decrements after checking (post-decrement)

4. `*p++ = (unsigned char)c;`
   - **Write and advance**: 
     - `*p` = write to current location
     - `p++` = move to next location
     - All in one operation!

5. `return dest;`
   - **Return original pointer**: Allows function chaining

---

### Section 3: String Manipulation Functions (Lines 63-191)

#### Why This Section Exists
Building command lines safely is critical. We need to:
- Append text without overflowing buffers
- Handle special characters (like quotes)
- Prevent the compiler from generating unwanted function calls

---

#### Function: `AppendStr` (Lines 67-160)

**Purpose**: Safely add text to the end of a string.

**Real-World Analogy**: You're writing a letter and want to add a sentence to the end. But you need to:
1. Check if there's enough room on the paper
2. Write character-by-character carefully
3. Make sure you don't write off the edge

```c
static inline bool AppendStr(WCHAR* dest, size_t destSize, const WCHAR* src, size_t* curLen)
```

**Parameters Explained**:
- `dest` = The string we're adding to (the paper)
- `destSize` = Maximum size (paper size)
- `src` = The text we want to add (new sentence)
- `curLen` = Current length (how much we've written already)

**The Critical Pointer Arithmetic Section**:

The comments explain why we use `*destPtr++ = *srcPtr++` instead of array indexing.

**The Problem**:
```c
// BAD - causes memcpy call:
dest[*curLen + i] = src[i];
```

The compiler sees this pattern and thinks: "Oh, they're copying a block of memory. I'll optimize this by calling `memcpy()`!" But we don't have `memcpy` available!

**The Solution**:
```c
// GOOD - no memcpy call:
*destPtr++ = *srcPtr++;
```

The compiler sees individual pointer operations and generates simple assembly code instead.

**Understanding `*destPtr++ = *srcPtr++;`**

This is compact but does several things:

**Right Side** (`*srcPtr++`):
1. Read the value at `srcPtr` address
2. Use that value
3. Then move `srcPtr` forward by one character

**Left Side** (`*destPtr++`):
1. Write the value to `destPtr` address
2. Then move `destPtr` forward by one character

**Visual Example**:
```
Before:
  srcPtr  →  'H' 'e' 'l' 'l' 'o'
  destPtr →  '?' '?' '?' '?' '?'

After first iteration:
  srcPtr  →  'H' 'e' 'l' 'l' 'o'
                 ↑
  destPtr →  'H' '?' '?' '?' '?'
                 ↑
```

---

#### Function: `AppendEscaped` (Lines 167-188)

**Purpose**: Add text but escape special characters (specifically quotes).

**Why It's Needed**: PowerShell treats quotes specially. If a parameter contains a quote, we need to "escape" it by adding a backslash before it.

**Example**:
- Input: `Say "Hello"`
- Output: `Say \"Hello\"`

```c
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
```

**How It Works**:
1. Loop through each character
2. If it's a quote, add `\"`
3. Otherwise, add the character normally
4. Stop if we run out of space

---

### Section 4: Logging Functions (Lines 193-329)

#### What This Section Does
Creates a detailed log file that records everything the program does. Extremely useful for troubleshooting!

**Log File Location**: `C:\Users\YourName\AppData\Local\ps-launcher\ps-launcher.log`

---

#### Function: `GetLogFilePath` (Lines 201-225)

**Purpose**: Figure out where to save the log file.

```c
static bool GetLogFilePath(WCHAR* logPath, size_t logPathSize)
{
    WCHAR appDataPath[MAX_PATH];
    
    // Get user's AppData\Local directory
    if (SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, appDataPath) != S_OK)
        return false;
    
    // Build path: AppData\Local\ps-launcher\ps-launcher.log
    size_t pos = 0;
    if (!AppendStr(logPath, logPathSize, appDataPath, &pos))
        return false;
    if (!AppendStr(logPath, logPathSize, L"\\ps-launcher", &pos))
        return false;
    
    // Create directory if it doesn't exist
    CreateDirectoryW(logPath, NULL);
    
    if (!AppendStr(logPath, logPathSize, L"\\ps-launcher.log", &pos))
        return false;
    
    return true;
}
```

**Step-by-Step**:
1. Ask Windows: "Where is this user's AppData folder?"
2. Add `\ps-launcher` to that path
3. Create the `ps-launcher` folder if it doesn't exist
4. Add `\ps-launcher.log` to complete the path

---

#### Function: `InitLog` (Lines 228-238)

**Purpose**: Create/open the log file at the start of the program.

```c
static void InitLog()
{
    WCHAR logPath[MAX_PATH];
    if (!GetLogFilePath(logPath, MAX_PATH))
        return;
    
    // Create new log file (overwrite existing)
    g_hLogFile = CreateFileW(logPath, GENERIC_WRITE, FILE_SHARE_READ, NULL, 
                             CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
}
```

**What Happens**:
1. Get the log file path
2. Create a new file (overwrites old log)
3. Store the file handle in `g_hLogFile` (global variable)

**Note**: Each run creates a fresh log (old one is replaced).

---

#### Function: `LogWrite` (Lines 241-260)

**Purpose**: Write a message to the log file.

**The Challenge**: Log file wants UTF-8 text, but we have Unicode (wide characters). Need to convert!

```c
static void LogWrite(const WCHAR* message)
{
    if (g_hLogFile == INVALID_HANDLE_VALUE)
        return;
    
    // Convert wide string to UTF-8 for file
    char utf8Buffer[LOG_BUFFER_SIZE];
    int utf8Len = WideCharToMultiByte(CP_UTF8, 0, message, -1, utf8Buffer, 
                                      LOG_BUFFER_SIZE - 2, NULL, NULL);
    if (utf8Len > 0)
    {
        // Add newline
        utf8Buffer[utf8Len - 1] = '\r';
        utf8Buffer[utf8Len] = '\n';
        utf8Buffer[utf8Len + 1] = '\0';
        
        DWORD written;
        WriteFile(g_hLogFile, utf8Buffer, utf8Len + 1, &written, NULL);
    }
}
```

**Process**:
1. Check if log file is open
2. Convert Unicode message to UTF-8
3. Add Windows-style line ending (`\r\n`)
4. Write to file

**Important**: If logging fails, we continue anyway. Logging is helpful but not critical.

---

#### Function: `LogFormat` (Lines 263-288)

**Purpose**: Write formatted messages with variables (simple version of `printf`).

**Example**: `LogFormat(L"Script file: %s", scriptName);`

```c
static void LogFormat(const WCHAR* format, const WCHAR* arg)
{
    WCHAR buffer[LOG_BUFFER_SIZE];
    size_t pos = 0;
    
    // Simple format string processor - only handles one %s
    for (size_t i = 0; format[i] != L'\0' && pos < LOG_BUFFER_SIZE - 1; i++)
    {
        if (format[i] == L'%' && format[i + 1] == L's')
        {
            // Insert argument
            if (arg && !AppendStr(buffer, LOG_BUFFER_SIZE, arg, &pos))
                break;
            i++; // Skip the 's'
        }
        else
        {
            // Regular character
            buffer[pos++] = format[i];
            buffer[pos] = L'\0';
        }
    }
    
    LogWrite(buffer);
}
```

**How It Works**:
1. Loop through format string character by character
2. When you find `%s`, insert the argument instead
3. Otherwise, copy the character normally
4. Write the result to log

**Limitation**: Only handles one `%s` per call (keeps it simple).

---

### Section 5: Main Program - `WinMain` (Lines 331-701)

This is where the actual work happens! Let's break it into logical phases.

---

#### Phase 1: Initialization (Lines 331-361)

```c
int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow)
{
    UNREFERENCED_PARAMETER(hInst);
    UNREFERENCED_PARAMETER(hPrev);
    UNREFERENCED_PARAMETER(lpCmdLine);
    UNREFERENCED_PARAMETER(nCmdShow);

    InitLog();
    LogWrite(L"========================================");
    LogWrite(L"PS-Launcher Execution Log");
    LogWrite(L"========================================");
```

**What's Happening**:
1. `WinMain` is the entry point (like `main` in console programs)
2. We ignore the parameters we don't need
3. Start the log file
4. Write a nice header

---

#### Phase 2: Parse Command Line (Lines 363-385)

```c
    int argc = 0;
    LPWSTR* args = CommandLineToArgvW(GetCommandLineW(), &argc);
    
    if (!args)
    {
        LogWrite(L"ERROR: Failed to parse command line");
        CloseLog();
        ShowError(L"Failed to parse command line.", L"Error");
        return 1;
    }
    
    LogWrite(L"Command line parsed successfully");
```

**What's Happening**:
1. Get the full command line as text
2. Ask Windows to split it into separate arguments (like splitting a sentence into words)
3. `args` becomes an array of strings
4. `argc` tells us how many arguments we have

**Example**:
```
Command line: ps-launcher.exe -Script test.ps1 -Name "John"
Result:
  argc = 5
  args[0] = "ps-launcher.exe"
  args[1] = "-Script"
  args[2] = "test.ps1"
  args[3] = "-Name"
  args[4] = "John"
```

---

#### Phase 3: Validate Arguments (Lines 387-412)

```c
    if (argc < 3 || lstrcmpiW(args[1], L"-Script") != 0)
    {
        LogWrite(L"ERROR: Invalid arguments - must provide -Script parameter");
        CloseLog();
        MessageBoxW(NULL, L"PS-Launcher Usage:\n\n...", L"PS-Launcher Help", MB_OK);
        LocalFree(args);
        return 1;
    }
    
    LogFormat(L"Script file: %s", args[2]);
```

**What We're Checking**:
1. Do we have at least 3 arguments? (program name, "-Script", script path)
2. Is the second argument "-Script"?

**If Invalid**: Show help message and exit

**If Valid**: Log the script filename

---

#### Phase 4: Build PowerShell Path (Lines 414-452)

**Goal**: Find the full path to PowerShell.exe

**Why**: Security! We use the full path `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` to prevent attackers from tricking us into running a fake PowerShell.

```c
    WCHAR psPath[MAX_PATH] = { 0 };
    UINT len = GetSystemDirectoryW(psPath, MAX_PATH);
    
    if (len == 0 || len > MAX_PATH - 1)
    {
        LocalFree(args);
        ShowError(L"Failed to get system directory.", L"Error");
        return 1;
    }
    
    // Add backslash if needed
    if (psPath[len - 1] != L'\\')
    {
        if (len < MAX_PATH - 1)
        {
            psPath[len] = L'\\';
            psPath[len + 1] = L'\0';
        }
        else
        {
            LocalFree(args);
            ShowError(L"System directory path too long.", L"Error");
            return 1;
        }
    }
    
    const WCHAR* psRelative = L"WindowsPowerShell\\v1.0\\powershell.exe";
    
    if (lstrlenW(psPath) + lstrlenW(psRelative) >= MAX_PATH)
    {
        LocalFree(args);
        ShowError(L"PowerShell path too long.", L"Error");
        return 1;
    }
    
    lstrcatW(psPath, psRelative);
```

**Steps**:
1. Get Windows system directory (usually `C:\Windows\System32`)
2. Make sure it ends with backslash
3. Add the PowerShell path
4. Result: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`

---

#### Phase 5: Validate Files Exist (Lines 454-477)

```c
    LogFormat(L"PowerShell path: %s", psPath);
    
    if (GetFileAttributesW(psPath) == INVALID_FILE_ATTRIBUTES)
    {
        LogWrite(L"ERROR: PowerShell executable not found");
        LocalFree(args);
        CloseLog();
        ShowError(L"PowerShell executable not found.", L"Error");
        return 1;
    }

    if (GetFileAttributesW(args[2]) == INVALID_FILE_ATTRIBUTES)
    {
        LogWrite(L"ERROR: Script file not found");
        LocalFree(args);
        CloseLog();
        ShowError(L"Specified script file not found.", L"Error");
        return 1;
    }
```

**Checks**:
1. Does PowerShell.exe exist?
2. Does the script file exist?

**Why**: Better to fail early with a clear message than try to run non-existent files!

---

#### Phase 6: Build Command Line (Lines 479-534)

**Goal**: Create the command line that will launch PowerShell with our script.

**Target Format**:
```
"C:\Windows\System32\...\powershell.exe" -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\script.ps1"
```

```c
    WCHAR cmd[CMD_BUFFER_SIZE];
    size_t pos = 0;

    // Add opening quote
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
    }
    
    // Add PowerShell path
    if (!AppendStr(cmd, CMD_BUFFER_SIZE, psPath, &pos))
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }
    
    // Add closing quote
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
    }

    // Add PowerShell switches
    if (!AppendStr(cmd, CMD_BUFFER_SIZE,
            L" -NonInteractive -NoProfile -ExecutionPolicy Bypass -File ", &pos))
    {
        LocalFree(args);
        ShowError(L"Buffer overflow error.", L"Error");
        return 1;
    }

    // Add quoted script path
    if (pos < CMD_BUFFER_SIZE - 1)
    {
        cmd[pos++] = L'\"';
        cmd[pos] = L'\0';
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
```

**PowerShell Switches Explained**:
- `-NonInteractive`: Don't ask for user input
- `-NoProfile`: Don't load user profile (faster startup)
- `-ExecutionPolicy Bypass`: Ignore script execution policy
- `-File`: The next parameter is a script file

---

#### Phase 7: Add Script Parameters (Lines 536-617)

**Goal**: Add any parameters that should be passed to the PowerShell script.

**Example**:
```
User runs: ps-launcher.exe -Script test.ps1 -Name "John Doe" -Age 25
We need to add: -Name "John Doe" -Age 25
```

```c
    LogWrite(L"Processing script parameters...");
    
    for (int i = 3; i < argc; i++)
    {
        // SECURITY CHECK: Prevent command injection
        for (size_t j = 0; j < lstrlenW(args[i]); j++)
        {
            if (args[i][j] == L';')
            {
                LogWrite(L"ERROR: Semicolon detected in parameter (security block)");
                LocalFree(args);
                CloseLog();
                return 1;
            }
        }

        // ADD SPACE SEPARATOR
        if (!AppendStr(cmd, CMD_BUFFER_SIZE, L" ", &pos))
        {
            LogWrite(L"ERROR: Buffer overflow while adding parameter separator");
            LocalFree(args);
            CloseLog();
            return 1;
        }
        
        // Check if parameter is already quoted
        size_t argLen = lstrlenW(args[i]);
        bool alreadyQuoted = (argLen >= 2 && args[i][0] == L'\"' && args[i][argLen - 1] == L'\"');
        
        if (alreadyQuoted)
        {
            // Use parameter as-is
            if (!AppendStr(cmd, CMD_BUFFER_SIZE, args[i], &pos))
            {
                LocalFree(args);
                ShowError(L"Buffer overflow error.", L"Error");
                return 1;
            }
        }
        else
        {
            // Add quotes and escape internal quotes if needed
            if (!AppendStr(cmd, CMD_BUFFER_SIZE, L"\"", &pos))
            {
                LocalFree(args);
                ShowError(L"Buffer overflow error.", L"Error");
                return 1;
            }
            
            // Check for internal quotes
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

    LocalFree(args);
```

**Key Points**:

1. **Security Check**: Reject parameters containing semicolons (prevents command injection attacks)

2. **Smart Quoting**:
   - If parameter already has quotes, use as-is
   - Otherwise, add quotes around it
   - If it has internal quotes, escape them

3. **Buffer Overflow Protection**: Check available space before every append

---

#### Phase 8: Launch PowerShell (Lines 619-667)

**Goal**: Actually run PowerShell with the command line we built.

```c
    LogWrite(L"Final command line:");
    LogWrite(cmd);
    LogWrite(L"Creating PowerShell process...");

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    
    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
                          CREATE_NO_WINDOW, NULL, NULL, &si, &pi))
    {
        LogWrite(L"ERROR: Failed to create PowerShell process");
        DWORD err = GetLastError();
        
        WCHAR errMsg[256];
        FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                       NULL, err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                       errMsg, 256, NULL);

#ifdef _DEBUG
        WCHAR debugMsg[CMD_BUFFER_SIZE + 300];
        wsprintfW(debugMsg, L"Error: %s\n\nCommand: %s", errMsg, cmd);
        ShowError(debugMsg, L"Process Creation Failed");
#else
        ShowError(errMsg, L"Process Creation Failed");
#endif
        return err;
    }
```

**What's Happening**:

1. **Set Up Process Info Structures**:
   - `STARTUPINFOW si`: Tells Windows how to start the process
   - `PROCESS_INFORMATION pi`: Windows fills this with process details

2. **CreateProcessW Call**:
   - `NULL`: No specific application (use command line)
   - `cmd`: The command line we built
   - `CREATE_NO_WINDOW`: **This is the magic!** No console window!

3. **Error Handling**:
   - If it fails, get the Windows error message
   - In debug mode, show the full command line too
   - Return the error code

---

#### Phase 9: Wait and Get Exit Code (Lines 669-701)

**Goal**: Wait for PowerShell to finish and get its exit code.

```c
    LogWrite(L"Process created successfully");
    LogWrite(L"Waiting for script execution to complete...");
    
    WaitForSingleObject(pi.hProcess, INFINITE);
    
    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    
    // Log completion with exit code
    WCHAR exitMsg[100];
    wsprintfW(exitMsg, L"Script completed with exit code: %u", exitCode);
    LogWrite(exitMsg);
    LogWrite(L"========================================");
    LogWrite(L"Execution completed successfully");
    LogWrite(L"========================================");
    
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    
    CloseLog();
    
    return exitCode;
}
```

**What's Happening**:

1. **Wait**: `WaitForSingleObject` blocks until PowerShell finishes
   - `INFINITE` = wait forever (no timeout)

2. **Get Exit Code**: PowerShell scripts can return exit codes (0 = success)

3. **Cleanup**:
   - Close process and thread handles
   - Close log file
   - Return PowerShell's exit code

**Important**: We pass through PowerShell's exit code. If the script failed, we fail too!

---

### Section 6: Improvement Suggestions (Lines 703-748)

This section contains commented ideas for future enhancements. It's like a "wishlist" of features that could be added:

1. **Enhanced Error Handling**: Structured exceptions, retry logic
2. **Security Enhancements**: Digital signature validation, better parameter sanitization
3. **Performance**: Caching, string builder patterns
4. **Robustness**: Timeout support, graceful shutdown
5. **Debugging**: Verbose mode, trace functionality
6. **Code Organization**: Split into modules, add unit tests
7. **Modern C**: Use C99/C11 features
8. **Cross-Platform**: Abstract Windows-specific code

---

## Key Programming Concepts Used

### 1. **Pointers and Pointer Arithmetic**

**What Are Pointers?**
A pointer is a variable that holds a memory address (like a house address).

```c
WCHAR* ptr;  // ptr can hold the address of a WCHAR
```

**Pointer Arithmetic**:
```c
ptr++;  // Move to next WCHAR (address increases by sizeof(WCHAR))
```

**Dereferencing**:
```c
*ptr = L'A';  // Write 'A' to the address ptr points to
```

---

### 2. **Stack vs Heap Memory**

**Stack** (automatic):
```c
WCHAR buffer[1024];  // Fixed size, on stack, automatic cleanup
```

**Heap** (manual):
```c
LPWSTR* args = CommandLineToArgvW(...);  // Allocated by Windows
LocalFree(args);  // MUST manually free!
```

---

### 3. **Buffer Overflow Prevention**

Always check if there's enough space before writing:

```c
if (pos + srcLen >= destSize)
    return false;  // STOP! No room!
```

This prevents writing past the end of arrays (security vulnerability!).

---

### 4. **Wide Characters (Unicode)**

**Why `WCHAR`?**
Windows uses Unicode (UTF-16) for international text support.

```c
WCHAR text[] = L"Hello 世界";  // L prefix = wide string
```

Each character is 2 bytes (can represent any language).

---

### 5. **Preprocessor Directives**

These are processed before compilation:

```c
#define BUFFER_SIZE 1024  // Text replacement
#ifdef ENABLE_LOGGING     // Conditional compilation
    // This code only exists if ENABLE_LOGGING is defined
#endif
```

---

### 6. **Windows API Calling Convention**

**`WINAPI`** = `__stdcall`:
- How parameters are passed and cleaned up
- Standard for Windows functions
- Different from `__cdecl` (C calling convention)

---

### 7. **Error Handling Patterns**

**Check Every Operation**:
```c
if (!CreateProcessW(...))
{
    // Handle error
    return 1;
}
```

**Cleanup Before Error Return**:
```c
if (error)
{
    LocalFree(args);  // Clean up first!
    CloseLog();
    return 1;
}
```

---

## Common Questions

### Q: Why is it called a "launcher"?
**A**: It launches (starts) other programs. Like a rocket launcher launches rockets, this program launches PowerShell scripts.

### Q: Why not just use PowerShell directly?
**A**: PowerShell normally shows a console window. This program hides that window while still running the script.

### Q: What's the `L` in front of strings?
**A**: The `L` makes it a wide string (Unicode). Example: `L"Hello"` uses 2 bytes per character.

### Q: Why do we check buffer sizes so much?
**A**: To prevent buffer overflow attacks and crashes. If we write past the end of a buffer, we corrupt memory.

### Q: What happens if logging fails?
**A**: The program continues anyway. Logging is helpful for debugging but not essential for operation.

### Q: Can this run any PowerShell script?
**A**: Yes! It just launches PowerShell with your script. All PowerShell features work normally.

### Q: Why is the code so heavily commented?
**A**: This is a learning resource. The comments explain not just WHAT the code does, but WHY it's done that way.

---

## Summary

**What This Program Does**:
1. Takes a PowerShell script path and parameters
2. Validates everything exists and is safe
3. Builds a command line to launch PowerShell
4. Runs PowerShell completely hidden (no window)
5. Waits for it to finish
6. Returns the script's exit code

**Why It's Special**:
- Pure C (educational and minimal)
- No dependencies (just Windows)
- Tiny size (~6KB)
- Secure (validates input, uses full paths)
- Well-documented (learning resource)

**Key Techniques**:
- Manual memory management
- Buffer overflow prevention
- Pointer arithmetic
- Windows API usage
- Security-conscious design

This code serves as an excellent example of low-level Windows programming in pure C!
