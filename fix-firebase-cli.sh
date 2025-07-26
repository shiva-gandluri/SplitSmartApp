#!/bin/bash

# Comprehensive Firebase CLI fix script

echo "🔧 Comprehensive Firebase CLI Installation Fix"
echo "=============================================="

# Step 1: Fix npm permissions
echo "1️⃣ Fixing npm permissions..."
if [ -d "$HOME/.npm" ]; then
    echo "🔧 Fixing npm cache ownership..."
    sudo chown -R $(id -u):$(id -g) "$HOME/.npm"
    echo "✅ npm permissions fixed"
else
    echo "ℹ️ npm cache directory doesn't exist, skipping"
fi

# Step 2: Clean existing Firebase installations
echo ""
echo "2️⃣ Cleaning existing Firebase CLI installations..."

# Remove npm global installation
if command -v npm &> /dev/null; then
    echo "🧹 Removing npm Firebase CLI..."
    sudo npm uninstall -g firebase-tools 2>/dev/null || true
fi

# Remove Homebrew installation
if command -v brew &> /dev/null; then
    echo "🧹 Removing Homebrew Firebase CLI..."
    brew uninstall firebase-cli 2>/dev/null || true
fi

# Remove standalone binary
if [ -f "$HOME/.local/bin/firebase" ]; then
    echo "🧹 Removing standalone Firebase CLI..."
    rm -f "$HOME/.local/bin/firebase"
fi

# Remove any conflicting symlinks
if [ -L "/opt/homebrew/bin/firebase" ]; then
    echo "🧹 Removing conflicting Firebase symlink..."
    sudo rm -f "/opt/homebrew/bin/firebase"
fi

echo "✅ Cleanup complete"

# Step 3: Fresh installation via Homebrew (cleanest method)
echo ""
echo "3️⃣ Installing Firebase CLI via Homebrew..."
if command -v brew &> /dev/null; then
    brew install firebase-cli
    
    if command -v firebase &> /dev/null; then
        echo "✅ Firebase CLI installed successfully!"
        echo "📋 Version: $(firebase --version)"
        echo ""
        echo "🎉 Installation complete! You can now run:"
        echo "   ./deploy.sh"
        exit 0
    fi
fi

# Step 4: Fallback to curl method
echo ""
echo "4️⃣ Fallback: Installing via curl..."
curl -sL https://firebase.tools | bash
export PATH="$PATH:$HOME/.local/bin"

if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI installed successfully via curl!"
    echo "📋 Version: $(firebase --version)"
    echo ""
    echo "🎉 Installation complete! You can now run:"
    echo "   ./deploy.sh"
    exit 0
fi

# Step 5: Last resort with npm (clean install)
echo ""
echo "5️⃣ Last resort: Clean npm installation..."
npm cache clean --force
sudo npm install -g firebase-tools --force

if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI installed successfully via npm!"
    echo "📋 Version: $(firebase --version)"
    echo ""
    echo "🎉 Installation complete! You can now run:"
    echo "   ./deploy.sh"
    exit 0
fi

echo ""
echo "❌ All installation methods failed."
echo "🔧 Manual steps required:"
echo ""
echo "1. Download Firebase CLI manually:"
echo "   https://firebase.google.com/docs/cli#install_the_firebase_cli"
echo ""
echo "2. Or try these commands manually:"
echo "   brew install firebase-cli"
echo "   # OR"
echo "   curl -sL https://firebase.tools | bash"
echo ""
exit 1