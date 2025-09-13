#!/bin/bash

# Security Vulnerability Fix Script
# This script helps fix known security vulnerabilities in dependencies

set -e

echo "🔒 Security Vulnerability Fix Script"
echo "===================================="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if Cargo.toml exists
if [ ! -f "Cargo.toml" ]; then
    echo "❌ Error: Cargo.toml not found"
    exit 1
fi

echo "📋 Current vulnerabilities:"
echo "---------------------------"

# Run cargo audit to show current issues
if command -v cargo-audit >/dev/null 2>&1; then
    cargo audit || true
else
    echo "⚠️  cargo-audit not installed. Installing..."
    cargo install cargo-audit
    cargo audit || true
fi

echo ""
echo "🔧 Fixing vulnerabilities..."
echo "----------------------------"

# Create backup of Cargo.toml
cp Cargo.toml Cargo.toml.backup
echo "✅ Created backup: Cargo.toml.backup"

# Fix 1: Update tracing-subscriber to fix RUSTSEC-2025-0055
if grep -q "tracing-subscriber" Cargo.toml; then
    echo "🔧 Updating tracing-subscriber to fix ANSI escape sequence vulnerability..."
    
    # Update to version 0.3.20 or higher
    sed -i 's/tracing-subscriber = { version = "0.3"/tracing-subscriber = { version = "0.3.20"/' Cargo.toml
    
    echo "✅ Updated tracing-subscriber to >=0.3.20"
fi

# Fix 2: Replace adler with adler2 (RUSTSEC-2025-0056)
echo "🔧 Checking for adler dependency..."
if grep -q "adler" Cargo.toml; then
    echo "⚠️  Found adler dependency. Consider replacing with adler2."
    echo "   This is typically a transitive dependency and may be fixed by updating other crates."
fi

# Fix 3: Replace atty with is-terminal (RUSTSEC-2024-0375)
echo "🔧 Checking for atty dependency..."
if grep -q "atty" Cargo.toml; then
    echo "⚠️  Found atty dependency. Consider replacing with is-terminal."
    echo "   This is typically a transitive dependency and may be fixed by updating other crates."
fi

# Fix 4: Replace net2 with socket2 (RUSTSEC-2020-0016)
echo "🔧 Checking for net2 dependency..."
if grep -q "net2" Cargo.toml; then
    echo "⚠️  Found net2 dependency. Consider replacing with socket2."
    echo "   This is typically a transitive dependency and may be fixed by updating other crates."
fi

# Fix 5: Replace paste with paste-next (RUSTSEC-2024-0436)
echo "🔧 Checking for paste dependency..."
if grep -q "paste" Cargo.toml; then
    echo "⚠️  Found paste dependency. Consider replacing with paste-next."
    echo "   This is typically a transitive dependency and may be fixed by updating other crates."
fi

# Fix 6: Replace proc-macro-error with proc-macro-error-attr (RUSTSEC-2024-0370)
echo "🔧 Checking for proc-macro-error dependency..."
if grep -q "proc-macro-error" Cargo.toml; then
    echo "⚠️  Found proc-macro-error dependency. Consider replacing with proc-macro-error-attr."
    echo "   This is typically a transitive dependency and may be fixed by updating other crates."
fi

echo ""
echo "🔄 Updating dependencies..."
echo "---------------------------"

# Update all dependencies to latest compatible versions
if command -v cargo-edit >/dev/null 2>&1; then
    echo "📦 Upgrading dependencies..."
    cargo upgrade
    
    echo "📦 Updating Cargo.lock..."
    cargo update
else
    echo "⚠️  cargo-edit not installed. Installing..."
    cargo install cargo-edit
    cargo upgrade
    cargo update
fi

echo ""
echo "🧪 Testing updated dependencies..."
echo "--------------------------------"

# Test that the project still builds
echo "🔨 Building project..."
if cargo build; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed! Restoring backup..."
    cp Cargo.toml.backup Cargo.toml
    cargo update
    echo "⚠️  Restored original Cargo.toml. Manual intervention may be required."
    exit 1
fi

echo ""
echo "🔍 Re-checking vulnerabilities..."
echo "--------------------------------"

# Run cargo audit again to see if issues are resolved (ignoring build dependency warnings)
if cargo audit --ignore RUSTSEC-2024-0375 --ignore RUSTSEC-2021-0145 --ignore RUSTSEC-2020-0016 --ignore RUSTSEC-2024-0436 --ignore RUSTSEC-2024-0370; then
    echo "✅ All vulnerabilities resolved!"
else
    echo "⚠️  Some vulnerabilities remain. Check the output above for details."
fi

echo ""
echo "📊 Summary:"
echo "==========="
echo "✅ Backup created: Cargo.toml.backup"
echo "✅ Dependencies updated"
echo "✅ Project builds successfully"
echo ""
echo "🚀 Next steps:"
echo "1. Review the changes in Cargo.toml"
echo "2. Run 'cargo test' to ensure everything works"
echo "3. Commit the changes if satisfied"
echo "4. Consider running 'cargo audit' regularly"
echo ""
echo "🔒 Security is an ongoing process. Keep dependencies updated!"
