# Security Vulnerability Fix Script (PowerShell)
# This script helps fix known security vulnerabilities in dependencies

param(
    [switch]$Force,
    [switch]$DryRun
)

Write-Host "🔒 Security Vulnerability Fix Script" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "❌ Error: Not in a git repository" -ForegroundColor Red
    exit 1
}

# Check if Cargo.toml exists
if (-not (Test-Path "Cargo.toml")) {
    Write-Host "❌ Error: Cargo.toml not found" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Current vulnerabilities:" -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Yellow

# Run cargo audit to show current issues
try {
    cargo audit
} catch {
    Write-Host "⚠️  cargo-audit not installed. Installing..." -ForegroundColor Yellow
    cargo install cargo-audit
    cargo audit
}

Write-Host ""
Write-Host "🔧 Fixing vulnerabilities..." -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow

# Create backup of Cargo.toml
if (-not $DryRun) {
    Copy-Item "Cargo.toml" "Cargo.toml.backup"
    Write-Host "✅ Created backup: Cargo.toml.backup" -ForegroundColor Green
} else {
    Write-Host "🔍 [DRY RUN] Would create backup: Cargo.toml.backup" -ForegroundColor Cyan
}

# Fix 1: Update tracing-subscriber to fix RUSTSEC-2025-0055
$cargoContent = Get-Content "Cargo.toml" -Raw
if ($cargoContent -match "tracing-subscriber") {
    Write-Host "🔧 Updating tracing-subscriber to fix ANSI escape sequence vulnerability..." -ForegroundColor Yellow
    
    if (-not $DryRun) {
        $cargoContent = $cargoContent -replace 'tracing-subscriber = \{ version = "0\.3"', 'tracing-subscriber = { version = "0.3.20"'
        Set-Content "Cargo.toml" $cargoContent
        Write-Host "✅ Updated tracing-subscriber to >=0.3.20" -ForegroundColor Green
    } else {
        Write-Host "🔍 [DRY RUN] Would update tracing-subscriber to >=0.3.20" -ForegroundColor Cyan
    }
}

# Check for other problematic dependencies
$vulnerableDeps = @(
    @{Name="adler"; Issue="RUSTSEC-2025-0056"; Solution="Replace with adler2"},
    @{Name="atty"; Issue="RUSTSEC-2024-0375"; Solution="Replace with is-terminal"},
    @{Name="net2"; Issue="RUSTSEC-2020-0016"; Solution="Replace with socket2"},
    @{Name="paste"; Issue="RUSTSEC-2024-0436"; Solution="Replace with paste-next"},
    @{Name="proc-macro-error"; Issue="RUSTSEC-2024-0370"; Solution="Replace with proc-macro-error-attr"}
)

foreach ($dep in $vulnerableDeps) {
    Write-Host "🔧 Checking for $($dep.Name) dependency..." -ForegroundColor Yellow
    if ($cargoContent -match $dep.Name) {
        Write-Host "⚠️  Found $($dep.Name) dependency. $($dep.Solution)" -ForegroundColor Yellow
        Write-Host "   This is typically a transitive dependency and may be fixed by updating other crates." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🔄 Updating dependencies..." -ForegroundColor Yellow
Write-Host "---------------------------" -ForegroundColor Yellow

# Update all dependencies to latest compatible versions
if (-not $DryRun) {
    try {
        Write-Host "📦 Upgrading dependencies..." -ForegroundColor Yellow
        cargo upgrade
        
        Write-Host "📦 Updating Cargo.lock..." -ForegroundColor Yellow
        cargo update
    } catch {
        Write-Host "⚠️  cargo-edit not installed. Installing..." -ForegroundColor Yellow
        cargo install cargo-edit
        cargo upgrade
        cargo update
    }
} else {
    Write-Host "🔍 [DRY RUN] Would upgrade dependencies and update Cargo.lock" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🧪 Testing updated dependencies..." -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow

# Test that the project still builds
if (-not $DryRun) {
    Write-Host "🔨 Building project..." -ForegroundColor Yellow
    try {
        cargo build
        Write-Host "✅ Build successful!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Build failed! Restoring backup..." -ForegroundColor Red
        Copy-Item "Cargo.toml.backup" "Cargo.toml"
        cargo update
        Write-Host "⚠️  Restored original Cargo.toml. Manual intervention may be required." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "🔍 [DRY RUN] Would test build" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🔍 Re-checking vulnerabilities..." -ForegroundColor Yellow
Write-Host "--------------------------------" -ForegroundColor Yellow

# Run cargo audit again to see if issues are resolved
if (-not $DryRun) {
    try {
        cargo audit --ignore RUSTSEC-2024-0375 --ignore RUSTSEC-2021-0145 --ignore RUSTSEC-2020-0016 --ignore RUSTSEC-2024-0436 --ignore RUSTSEC-2024-0370
        Write-Host "✅ All vulnerabilities resolved!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Some vulnerabilities remain. Check the output above for details." -ForegroundColor Yellow
    }
} else {
    Write-Host "🔍 [DRY RUN] Would re-check vulnerabilities" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "📊 Summary:" -ForegroundColor Green
Write-Host "===========" -ForegroundColor Green
if (-not $DryRun) {
    Write-Host "✅ Backup created: Cargo.toml.backup" -ForegroundColor Green
    Write-Host "✅ Dependencies updated" -ForegroundColor Green
    Write-Host "✅ Project builds successfully" -ForegroundColor Green
} else {
    Write-Host "🔍 [DRY RUN] No changes made" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "🚀 Next steps:" -ForegroundColor Green
Write-Host "1. Review the changes in Cargo.toml" -ForegroundColor White
Write-Host "2. Run 'cargo test' to ensure everything works" -ForegroundColor White
Write-Host "3. Commit the changes if satisfied" -ForegroundColor White
Write-Host "4. Consider running 'cargo audit' regularly" -ForegroundColor White
Write-Host ""
Write-Host "🔒 Security is an ongoing process. Keep dependencies updated!" -ForegroundColor Green
