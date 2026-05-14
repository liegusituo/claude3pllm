#!/bin/bash
# Build script for DeepSeekProxy menu bar app
# Requires: Xcode Command Line Tools or Xcode (for Swift compiler)
# Target: macOS 14+, Apple Silicon (M1-M5) native

set -e

cd "$(dirname "$0")"

echo "🔨 Building DeepSeekProxy..."
echo "   Target: macOS 14+ (Apple Silicon native)"
echo ""

# Ensure resources are linked
if [ ! -f "Resources/deepseek_proxy.py" ]; then
    echo "❌ Resources/deepseek_proxy.py not found!"
    exit 1
fi

# Build with Swift Package Manager - release mode for Apple Silicon
swift build -c release --arch arm64

if [ $? -eq 0 ]; then
    # Find the built binary
    BINARY=".build/arm64-apple-macosx/release/DeepSeekProxy"
    if [ ! -f "$BINARY" ]; then
        # Try without arch suffix
        BINARY=".build/release/DeepSeekProxy"
    fi

    if [ -f "$BINARY" ]; then
        echo ""
        echo "✅ Build successful!"
        echo "   Binary: $BINARY"
        echo ""
        echo "📦 To create an .app bundle, run:"
        echo "   ./package.sh"
        echo ""
        echo "🚀 To run directly from terminal:"
        echo "   $BINARY"
        echo ""
        echo "💡 To add to Login Items, open System Settings → General → Login Items"
        echo "   and add: $(pwd)/$BINARY"
    else
        echo "❌ Binary not found at expected path."
        find .build -name "DeepSeekProxy" -type f 2>/dev/null
    fi
else
    echo "❌ Build failed."
    exit 1
fi
