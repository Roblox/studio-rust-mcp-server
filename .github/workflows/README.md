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

All security checks must pass before code can be merged into the main branch.
