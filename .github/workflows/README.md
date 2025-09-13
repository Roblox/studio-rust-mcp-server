# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the Roblox Studio MCP Server project.

## Workflows

### Security Scan (`security-scan.yml`)

Performs comprehensive security scanning on every push and pull request:

- **CodeQL Analysis**: Static Application Security Testing (SAST) for Rust code
- **Dependency Review**: Scans dependencies for known vulnerabilities (PRs only)
- **Secrets Scan**: Detects accidentally committed secrets using Gitleaks
- **Cargo Audit**: Checks Rust dependencies for security vulnerabilities

### Code Quality Checks (`checks.yml`)

Ensures code quality and formatting standards:

- **Clippy**: Rust linter for catching common mistakes
- **Format Check**: Ensures code follows consistent formatting
- **Selene**: Luau linter for the plugin code
- **StyLua**: Luau code formatter

### Build (`build.yml`)

Cross-platform builds and releases:

- **macOS Build**: Universal binary for both Intel and Apple Silicon
- **Windows Build**: Native Windows executable
- **Code Signing**: Signs binaries for both platforms
- **Release**: Creates GitHub releases with signed artifacts

### Linux Build (`build-linux.yml`)

Specialized Linux binary build process.

## Required Secrets

The following secrets need to be configured in your repository settings:

### Security Workflow

- `GITLEAKS_KEY` (optional): License key for Gitleaks if you have one

### Build Workflow

- `APPLE_API_KEY_ID`: Apple Developer API Key ID
- `APPLE_API_ISSUER`: Apple Developer API Issuer
- `APPLE_API_KEY_CONTENT`: Apple Developer API Key content
- `APPLE_CERT_PASSWORD`: Certificate password for macOS signing
- `AZURE_TENANT_ID`: Azure tenant ID for Windows signing
- `AZURE_CLIENT_ID`: Azure client ID for Windows signing
- `AZURE_CLIENT_SECRET`: Azure client secret for Windows signing
- `SIGNING_ACCOUNT`: Signing account identifier

## Security Features

The security workflow implements multiple layers of protection:

1. **Static Analysis**: CodeQL analyzes the Rust source code for potential security issues
2. **Dependency Scanning**: Automatically checks for vulnerable dependencies
3. **Secret Detection**: Prevents accidental exposure of API keys, passwords, and tokens
4. **Rust-Specific Security**: Cargo audit checks for known vulnerabilities in Rust crates
5. **Weekly Security Scans**: Automated vulnerability detection runs every Monday
6. **Security Reporting**: Detailed security reports with vulnerability summaries
7. **Dependency Updates**: Automated checking for outdated dependencies

All security checks must pass before code can be merged into the main branch.

### Enhanced Security Workflows

#### Security Scan (`security-scan.yml`)
- **CodeQL Analysis**: Static Application Security Testing (SAST)
- **Dependency Review**: Scans dependencies for known vulnerabilities (PRs only)
- **Secrets Scan**: Detects accidentally committed secrets using Gitleaks
- **Cargo Audit**: Checks Rust dependencies for security vulnerabilities
- **Dependency Check**: Identifies outdated dependencies
- **Security Summary**: Comprehensive security status report

#### Dependency Update (`dependency-update.yml`)
- **Weekly Updates**: Automated dependency update checking
- **Security Alerts**: Creates issues for security vulnerabilities
- **Critical Fixes**: Automated fixing of critical vulnerabilities
- **Update Reports**: Detailed reports on outdated dependencies

### Security Tools

The project includes several security tools and scripts:

- **`scripts/fix-vulnerabilities.sh`**: Bash script to fix known vulnerabilities
- **`scripts/fix-vulnerabilities.ps1`**: PowerShell script for Windows users
- **`SECURITY.md`**: Comprehensive security policy and vulnerability tracking
- **Issue Templates**: Structured reporting for security vulnerabilities

### Known Vulnerabilities

Current vulnerabilities being tracked:

1. **tracing-subscriber 0.3.19** → **Fixed** (upgraded to 0.3.20)
2. **adler 1.0.2** → **Planned** (replace with adler2)
3. **atty 0.2.14** → **Planned** (replace with is-terminal)
4. **net2 0.2.39** → **Planned** (replace with socket2)
5. **paste 1.0.15** → **Planned** (replace with paste-next)
6. **proc-macro-error 1.0.4** → **Planned** (replace with proc-macro-error-attr)

### Running Security Fixes

To fix vulnerabilities manually:

```bash
# On Unix/Linux/macOS
./scripts/fix-vulnerabilities.sh

# On Windows (PowerShell)
.\scripts\fix-vulnerabilities.ps1

# Dry run to see what would be changed
.\scripts\fix-vulnerabilities.ps1 -DryRun
```
