#!/bin/bash

# Drive Studio - Quick Install Script
# Run this from Terminal to install the app on your iPhone
# Usage: ./install.sh
#
# Make sure your iPhone is plugged in via USB before running.

echo "🚗 Drive Studio - Installing to iPhone..."
echo ""

cd "$(dirname "$0")"

# Check flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Make sure Flutter is installed and in PATH."
    exit 1
fi

# Check device connected
DEVICE=$(flutter devices 2>/dev/null | grep -i "iphone\|ios" | head -1)
if [ -z "$DEVICE" ]; then
    echo "❌ No iPhone detected. Please connect your iPhone via USB and trust this Mac."
    exit 1
fi

echo "📱 Device found. Building release app..."
echo ""

# Build and install release version
flutter run --release -d iPhone

echo ""
echo "✅ Done! Drive Studio is installed and will run without your Mac."
