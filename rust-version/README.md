# PS-Launcher (Rust Edition)

A minimal, secure PowerShell script launcher written in Rust following security best practices.

## Features

- **Memory Safety**: Rust's ownership system prevents buffer overflows and memory leaks
- **Enhanced Security**: Blocks 15+ dangerous characters (`;`, `&`, `|`, `<`, `>`, `` ` ``, `$`, etc.)
- **Path Hijacking Prevention**: Uses hardcoded system path to PowerShell
- **Input Validation**: Comprehensive parameter sanitization and file validation
- **Small Binary**: ~228KB optimized release build
- **Unit Tests**: Built-in test coverage for security-critical functions

## Building

### Prerequisites
- Rust 1.70+ ([install from rustup.rs](https://rustup.rs))
- Windows 10/11 or Windows Server 2016+

### Quick Build
```cmd
cargo build --release
```

Output: `target\release\ps-launcher.exe`

### Using Build Script
```cmd
build.bat          # Build release version
build.bat test     # Run tests
build.bat clean    # Clean build artifacts
```

## Usage

```cmd
ps-launcher.exe -Script <script_path> [parameters]
```

### Examples

```cmd
# Basic execution
ps-launcher.exe -Script myscript.ps1

# With parameters
ps-launcher.exe -Script backup.ps1 -Path "C:\Data" -Verbose

# Multiple parameters
ps-launcher.exe -Script deploy.ps1 -Environment Production -Force
```

## Security Features

### Command Injection Prevention
Rejects parameters containing: `;` `&` `|` `<` `>` `` ` `` `$` `(` `)` `{` `}` `[` `]` `\n` `\r`

### Path Validation
- Verifies script file exists
- Ensures path is a file (not directory)
- Canonicalizes paths to prevent traversal attacks

### Resource Limits
- Max parameter length: 1024 characters
- Max total command length: 8192 characters

### PowerShell Execution
Scripts launched with security flags:
- `-NonInteractive` - Prevents hanging on prompts
- `-NoProfile` - Skips profile scripts
- `-ExecutionPolicy Bypass` - Explicit script execution
- `-File` - Safe file execution mode

## Testing

```cmd
# Run unit tests
cargo test

# Run comprehensive integration tests
powershell -File test-launcher.ps1
```

### Unit Test Coverage
- Argument validation (valid/invalid cases)
- Parameter sanitization (all dangerous characters)
- Path validation and edge cases
- Length limit enforcement

## Comparison with C++ Version

| Feature | C++ | Rust |
|---------|-----|------|
| Binary Size | ~8-15 KB | ~228 KB |
| Memory Safety | Manual | Guaranteed |
| Buffer Overflows | Possible | Impossible |
| Dangerous Char Blocking | 1 (`;`) | 15+ |
| Path Validation | Existence only | Full canonicalization |
| Unit Tests | None | Comprehensive |
| Build System | Manual | Cargo |

**Trade-off**: Larger binary size for guaranteed memory safety and enhanced security.

## Return Codes

- `0` - Success
- `1` - Application error (invalid arguments, validation failure)
- Other - PowerShell script exit code (passed through)

## Common Issues

### "The request is not supported" Error
**Fixed in current version**. Earlier versions had GUI subsystem conflict.

### Script Not Found
Use absolute paths or correct relative paths:
```cmd
ps-launcher.exe -Script .\test.ps1           # Relative
ps-launcher.exe -Script C:\Scripts\test.ps1  # Absolute
```

### Parameter Rejected
Remove dangerous characters or reconsider the parameter design:
```cmd
# Bad - contains semicolon
ps-launcher.exe -Script test.ps1 -Cmd "Get-Process; Stop-Service"

# Good - separate scripts
ps-launcher.exe -Script test.ps1 -Cmd "Get-Process"
```

## Development

```cmd
# Format code
cargo fmt

# Run linter
cargo clippy

# Check without building
cargo check

# Generate documentation
cargo doc --open
```

## Security Best Practices

1. **Validate Scripts**: Review all scripts before execution
2. **Use Least Privilege**: Don't run as Administrator unless required
3. **Enable Logging**: Turn on PowerShell script block logging
4. **Sign Scripts**: Use code signing in production environments
5. **Restrict Access**: Limit who can modify scripts

## License

MIT License - Same as original C++ version

## Acknowledgments

- Original PS-Launcher C++ implementation
- Rust community and documentation
- Windows-rs project for Windows API bindings