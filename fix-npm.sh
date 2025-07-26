#!/bin/bash

# Fix npm cache issues and install Firebase CLI

echo "🔧 Fixing npm cache and installing Firebase CLI..."

# Clear npm cache
echo "🧹 Clearing npm cache..."
npm cache clean --force 2>/dev/null || true
rm -rf ~/.npm/_cacache 2>/dev/null || true

# Check if Homebrew is available (recommended method)
if command -v brew &> /dev/null; then
    echo "📦 Installing Firebase CLI via Homebrew (cleanest method)..."
    brew install firebase-cli
    
    if command -v firebase &> /dev/null; then
        echo "✅ Firebase CLI installed successfully via Homebrew!"
        firebase --version
        exit 0
    fi
fi

# If Homebrew fails or isn't available, try curl method
echo "📥 Installing Firebase CLI via standalone installer..."
curl -sL https://firebase.tools | bash

# Add to PATH for current session
export PATH="$PATH:$HOME/.local/bin"

if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI installed successfully via curl!"
    firebase --version
    exit 0
fi

# Last resort: npm with sudo
echo "📦 Installing Firebase CLI via npm with sudo..."
sudo npm install -g firebase-tools --unsafe-perm=true --allow-root

if command -v firebase &> /dev/null; then
    echo "✅ Firebase CLI installed successfully via npm!"
    firebase --version
    exit 0
fi

echo "❌ All installation methods failed. Please install manually:"
echo ""
echo "🔧 Manual installation options:"
echo "1. Homebrew: brew install firebase-cli"
echo "2. Direct download: curl -sL https://firebase.tools | bash"
echo "3. npm (with permissions): sudo npm install -g firebase-tools"
echo ""
exit 1