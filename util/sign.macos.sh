#!/bin/bash
set -ex

BUNDLE_DIR=target/aarch64-apple-darwin/release/bundle

if [ -n "$APPLE_API_KEY_CONTENT" ]
then
    KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
    function cleanup() {
        security delete-keychain "$KEYCHAIN_PATH" || true
    }
    trap cleanup EXIT
    KEYCHAIN_PASSWORD=$(head -1 /dev/random | md5)

    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    security import util/Certificates.p12 -P "$APPLE_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
    security set-key-partition-list -S apple-tool:,apple: -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security list-keychain -d user -s "$KEYCHAIN_PATH"

    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | cut -d' ' -f4 | tail -1)
    echo "$APPLE_API_KEY_CONTENT" > "$APPLE_API_KEY"

    
    codesign -s "$IDENTITY" -v -f -o runtime --deep -i com.rbx-mcp.server --timestamp --entitlements util/App.entitlements --generate-entitlement-der "$BUNDLE_DIR/osx/Roblox Studio MCP.app"
    ditto -c -k $BUNDLE_DIR/osx $BUNDLE_DIR/bund.zip
    xcrun notarytool submit -k "$APPLE_API_KEY" -d "$APPLE_API_KEY_ID" -i "$APPLE_API_ISSUER" --wait --progress $BUNDLE_DIR/bund.zip
    xcrun stapler staple "$BUNDLE_DIR/osx/Roblox Studio MCP.app"
fi

ditto -c -k $BUNDLE_DIR/osx output/macOS-rbx-studio-mcp.zip
