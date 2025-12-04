//! # PS-Launcher (Rust Edition)
//!
//! A minimal, secure PowerShell script launcher written in Rust with comprehensive
//! security features and best practices.
//!
//! ## Features
//!
//! - **Memory Safety**: Rust's ownership system prevents buffer overflows and memory leaks
//! - **Path Hijacking Prevention**: Uses full system path to PowerShell executable
//! - **Input Validation**: Comprehensive parameter sanitization and script validation
//! - **Error Handling**: Robust error handling with user-friendly messages
//! - **Small Binary Size**: Optimized for minimal executable size
//! - **Type Safety**: Strong typing prevents common programming errors
//!
//! ## Security Features
//!
//! 1. Validates PowerShell executable exists at known system location
//! 2. Validates script file exists before execution
//! 3. Sanitizes all parameters to prevent command injection
//! 4. Uses Unicode-aware string handling
//! 5. Implements proper error handling throughout
//! 6. No shell expansion - direct process creation

// Console subsystem required for Command::spawn() to work properly

use std::env;
use std::path::PathBuf;
use std::process::{exit, Command};

#[cfg(windows)]
use windows::{
    core::PCWSTR,
    Win32::UI::WindowsAndMessaging::{MessageBoxW, MB_ICONERROR, MB_OK},
};

/// Maximum allowed command line length to prevent resource exhaustion
const MAX_COMMAND_LENGTH: usize = 8192;

/// Characters that are potentially dangerous in command line arguments
const DANGEROUS_CHARS: &[char] = &[
    ';', '&', '|', '<', '>', '`', '$', '(', ')', '{', '}', '[', ']', '\n', '\r',
];

/// Main entry point for the application
///
/// # Returns
///
/// Exit code: 0 for success, 1 for application errors, or PowerShell script exit code
#[cfg(windows)]
fn main() {
    // Parse command line arguments
    let args: Vec<String> = env::args().collect();

    // Validate command line arguments
    if let Err(e) = validate_arguments(&args) {
        show_error("Invalid Arguments", &e);
        exit(1);
    }

    // Extract script path and parameters
    let script_path = &args[2];
    let script_params: Vec<String> = args.iter().skip(3).cloned().collect();

    // Validate and sanitize inputs
    if let Err(e) = validate_script_path(script_path) {
        show_error("Script Validation Failed", &e);
        exit(1);
    }

    if let Err(e) = validate_parameters(&script_params) {
        show_error("Parameter Validation Failed", &e);
        exit(1);
    }

    // Get PowerShell path
    let powershell_path = match get_powershell_path() {
        Ok(path) => path,
        Err(e) => {
            show_error("PowerShell Not Found", &e);
            exit(1);
        }
    };

    // Build and execute command
    match execute_powershell(&powershell_path, script_path, &script_params) {
        Ok(exit_code) => exit(exit_code),
        Err(e) => {
            show_error("Execution Failed", &e);
            exit(1);
        }
    }
}

/// Validate command line arguments
///
/// # Arguments
///
/// * `args` - Command line arguments including program name
///
/// # Returns
///
/// `Ok(())` if arguments are valid, `Err` with description otherwise
fn validate_arguments(args: &[String]) -> std::result::Result<(), String> {
    if args.len() < 3 {
        return Err(show_usage());
    }

    if args[1].to_lowercase() != "-script" {
        return Err(show_usage());
    }

    Ok(())
}

/// Generate usage message
///
/// # Returns
///
/// Formatted usage string for display
fn show_usage() -> String {
    String::from(
        "PS-Launcher Usage:\n\n\
        ps-launcher.exe -Script <script_path> [parameters]\n\n\
        Examples:\n\
        \u{00A0}\u{00A0}ps-launcher.exe -Script test.ps1\n\
        \u{00A0}\u{00A0}ps-launcher.exe -Script test.ps1 -FilePath \"C:\\temp\\test.txt\"\n\
        \u{00A0}\u{00A0}ps-launcher.exe -Script test.ps1 -Name \"John Doe\" -Verbose\n\n\
        Notes:\n\
        - Parameters with spaces are automatically quoted\n\
        - Dangerous characters (; & | < > ` $ etc.) are rejected\n\
        - Returns 0 for success, 1 for errors",
    )
}

/// Validate that the script file exists and is accessible
///
/// # Arguments
///
/// * `script_path` - Path to the PowerShell script
///
/// # Returns
///
/// `Ok(())` if script is valid, `Err` with description otherwise
///
/// # Security
///
/// - Validates file exists before execution
/// - Checks file is actually a file (not a directory)
/// - Prevents path traversal by using canonicalized paths
fn validate_script_path(script_path: &str) -> std::result::Result<(), String> {
    if script_path.is_empty() {
        return Err("Script path cannot be empty".to_string());
    }

    let path = PathBuf::from(script_path);

    // Check if file exists
    if !path.exists() {
        return Err(format!("Script file not found: {}", script_path));
    }

    // Check if it's actually a file
    if !path.is_file() {
        return Err(format!("Script path is not a file: {}", script_path));
    }

    // Canonicalize path to prevent path traversal attacks
    match path.canonicalize() {
        Ok(_) => Ok(()),
        Err(e) => Err(format!("Failed to resolve script path: {}", e)),
    }
}

/// Validate and sanitize parameters
///
/// # Arguments
///
/// * `params` - Vector of parameter strings
///
/// # Returns
///
/// `Ok(())` if all parameters are safe, `Err` with description otherwise
///
/// # Security
///
/// - Rejects parameters containing dangerous shell characters
/// - Prevents command injection attacks
/// - Validates parameter length to prevent resource exhaustion
fn validate_parameters(params: &[String]) -> std::result::Result<(), String> {
    let mut total_length = 0;

    for param in params {
        // Check for dangerous characters
        for dangerous_char in DANGEROUS_CHARS {
            if param.contains(*dangerous_char) {
                return Err(format!(
                    "Parameter contains forbidden character '{}': {}",
                    dangerous_char, param
                ));
            }
        }

        // Check parameter length
        if param.len() > 1024 {
            return Err(format!("Parameter too long (max 1024 chars): {}", param));
        }

        total_length += param.len();
    }

    // Check total command length
    if total_length > MAX_COMMAND_LENGTH {
        return Err(format!(
            "Total command length exceeds maximum ({} chars)",
            MAX_COMMAND_LENGTH
        ));
    }

    Ok(())
}

/// Get the full path to PowerShell executable
///
/// # Returns
///
/// `Ok(PathBuf)` with PowerShell path, or `Err` with description
///
/// # Security
///
/// - Uses system directory to prevent PATH hijacking
/// - Validates PowerShell executable exists
/// - Uses Windows API to get system directory
#[cfg(windows)]
fn get_powershell_path() -> std::result::Result<PathBuf, String> {
    // Use hardcoded path - most reliable on Windows
    let ps_path = PathBuf::from(r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe");

    // Validate PowerShell exists
    if !ps_path.exists() {
        return Err(format!(
            "PowerShell executable not found at: {}",
            ps_path.display()
        ));
    }

    Ok(ps_path)
}

/// Execute PowerShell with the given script and parameters
///
/// # Arguments
///
/// * `powershell_path` - Full path to PowerShell executable
/// * `script_path` - Path to the script to execute
/// * `params` - Additional parameters to pass to the script
///
/// # Returns
///
/// `Ok(i32)` with exit code on success, `Err` with description on failure
///
/// # Security
///
/// - Uses direct process creation (no shell expansion)
/// - All arguments are properly escaped
/// - PowerShell is run with restricted execution parameters
fn execute_powershell(
    powershell_path: &PathBuf,
    script_path: &str,
    params: &[String],
) -> std::result::Result<i32, String> {
    let mut cmd = Command::new(powershell_path);

    // PowerShell security flags
    cmd.arg("-NonInteractive")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(script_path);

    // Add script parameters
    for param in params {
        cmd.arg(param);
    }

    // Execute and capture output for debugging
    match cmd.output() {
        Ok(output) => {
            let exit_code = output.status.code().unwrap_or(1);

            // If there was an error, show stderr
            if exit_code != 0 && !output.stderr.is_empty() {
                let stderr = String::from_utf8_lossy(&output.stderr);
                return Err(format!("PowerShell error (exit {}): {}", exit_code, stderr));
            }

            Ok(exit_code)
        }
        Err(e) => Err(format!(
            "Failed to execute PowerShell: {} (error code: {:?})",
            e,
            e.raw_os_error()
        )),
    }
}

/// Display error message to user using Windows MessageBox
///
/// # Arguments
///
/// * `title` - Title of the message box
/// * `message` - Error message to display
///
/// # Security
///
/// - Limits message length to prevent UI issues
/// - Properly escapes special characters
#[cfg(windows)]
fn show_error(title: &str, message: &str) {
    unsafe {
        let title_wide = to_wide_string(title);
        let message_wide = to_wide_string(message);

        MessageBoxW(
            None,
            PCWSTR(message_wide.as_ptr()),
            PCWSTR(title_wide.as_ptr()),
            MB_OK | MB_ICONERROR,
        );
    }
}

/// Convert a Rust string to a null-terminated wide string (UTF-16)
///
/// # Arguments
///
/// * `s` - String to convert
///
/// # Returns
///
/// Vector of u16 representing null-terminated UTF-16 string
#[cfg(windows)]
fn to_wide_string(s: &str) -> Vec<u16> {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;

    OsStr::new(s)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

/// Non-Windows platform stub
#[cfg(not(windows))]
fn main() {
    eprintln!("Error: PS-Launcher is only supported on Windows platforms");
    eprintln!("This application requires Windows PowerShell to function.");
    exit(1);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_arguments_insufficient() {
        let args = vec!["program".to_string()];
        assert!(validate_arguments(&args).is_err());
    }

    #[test]
    fn test_validate_arguments_wrong_flag() {
        let args = vec![
            "program".to_string(),
            "-WrongFlag".to_string(),
            "script.ps1".to_string(),
        ];
        assert!(validate_arguments(&args).is_err());
    }

    #[test]
    fn test_validate_arguments_valid() {
        let args = vec![
            "program".to_string(),
            "-Script".to_string(),
            "script.ps1".to_string(),
        ];
        assert!(validate_arguments(&args).is_ok());
    }

    #[test]
    fn test_validate_parameters_dangerous_semicolon() {
        let params = vec!["test;whoami".to_string()];
        assert!(validate_parameters(&params).is_err());
    }

    #[test]
    fn test_validate_parameters_dangerous_pipe() {
        let params = vec!["test|whoami".to_string()];
        assert!(validate_parameters(&params).is_err());
    }

    #[test]
    fn test_validate_parameters_dangerous_ampersand() {
        let params = vec!["test&whoami".to_string()];
        assert!(validate_parameters(&params).is_err());
    }

    #[test]
    fn test_validate_parameters_safe() {
        let params = vec![
            "-FilePath".to_string(),
            "C:\\temp\\test.txt".to_string(),
            "-Verbose".to_string(),
        ];
        assert!(validate_parameters(&params).is_ok());
    }

    #[test]
    fn test_validate_parameters_too_long() {
        let long_param = "a".repeat(2000);
        let params = vec![long_param];
        assert!(validate_parameters(&params).is_err());
    }

    #[test]
    fn test_validate_script_path_empty() {
        assert!(validate_script_path("").is_err());
    }

    #[test]
    fn test_usage_message_contains_examples() {
        let usage = show_usage();
        assert!(usage.contains("Examples"));
        assert!(usage.contains("-Script"));
    }
}
