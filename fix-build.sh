#!/bin/bash

# Fix Build Script for SplitSmart
# Cleans Xcode build cache to recognize new Assets.xcassets color sets

set -e

echo "🔧 SplitSmart Build Fix Script"
echo "================================"
echo ""

PROJECT_DIR="/Users/shivagandluri/Documents/Projects/SplitSmartApp"
PROJECT_FILE="$PROJECT_DIR/SplitSmart.xcodeproj"

# Check if project exists
if [ ! -d "$PROJECT_FILE" ]; then
    echo "❌ Error: Project not found at $PROJECT_FILE"
    exit 1
fi

echo "📂 Project: $PROJECT_FILE"
echo ""

# Step 1: Remove Derived Data
echo "🗑️  Step 1: Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/SplitSmart-* 2>/dev/null || true
echo "✅ Derived Data cleaned"
echo ""

# Step 2: Verify color assets exist
echo "🎨 Step 2: Verifying color assets..."
ASSETS_DIR="$PROJECT_DIR/SplitSmart/Assets.xcassets"
REQUIRED_COLORS=("Depth0" "Depth1" "Depth2" "Depth3" "TextPrimary" "TextSecondary" "TextTertiary")

for color in "${REQUIRED_COLORS[@]}"; do
    if [ -d "$ASSETS_DIR/${color}.colorset" ]; then
        echo "  ✅ ${color}.colorset found"
    else
        echo "  ❌ ${color}.colorset missing!"
        exit 1
    fi
done
echo ""

# Step 3: Instructions
echo "🏗️  Step 3: Next Steps"
echo "================================"
echo ""
echo "The build cache has been cleared. Now:"
echo ""
echo "Option A - Use Xcode (Recommended):"
echo "  1. Open Xcode"
echo "  2. Open: SplitSmart.xcodeproj"
echo "  3. Product → Clean Build Folder (Shift+Cmd+K)"
echo "  4. Product → Build (Cmd+B)"
echo ""
echo "Option B - Command Line Build:"
echo "  cd $PROJECT_DIR"
echo "  xcodebuild -project SplitSmart.xcodeproj -scheme SplitSmart clean build"
echo ""
echo "✨ After building, the color errors should be resolved!"
echo ""
