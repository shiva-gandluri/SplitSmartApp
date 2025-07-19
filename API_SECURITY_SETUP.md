# 🔐 API Security Setup Guide

## ⚠️ IMPORTANT: Never commit API keys to your repository!

This guide explains how to securely store your Gemini API key without exposing it in your codebase.

## 🎯 Recommended Approach: APIKeys.plist (Local Development)

### Step 1: Get Your Gemini API Key
1. Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the key (starts with `AIza...`)

### Step 2: Configure APIKeys.plist
1. Copy `APIKeys-Example.plist` to `APIKeys.plist`:
   ```bash
   cp SplitSmart/APIKeys-Example.plist SplitSmart/APIKeys.plist
   ```

2. Open `APIKeys.plist` and replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key:
   ```xml
   <key>GEMINI_API_KEY</key>
   <string>AIzaSyC_your_actual_api_key_here</string>
   ```

3. **IMPORTANT**: `APIKeys.plist` is already in `.gitignore` and will NOT be committed to git.

### Step 3: Remove API Key from Info.plist
If you previously added the key to Info.plist:
1. Open `Info.plist`
2. Remove the `GEMINI_API_KEY` entry
3. Save the file

## 🚀 Alternative: Environment Variables (CI/CD)

For production or CI/CD environments:

### macOS/Linux:
```bash
export GEMINI_API_KEY="AIzaSyC_your_actual_api_key_here"
```

### Xcode Scheme:
1. Edit Scheme → Run → Arguments → Environment Variables
2. Add: `GEMINI_API_KEY` = `your_api_key`

## 🔍 Security Priority Order

The app checks for API keys in this order:

1. **Environment Variable** (most secure for CI/CD)
2. **APIKeys.plist** (recommended for local development) 
3. **Info.plist** (fallback - shows warning)

## ✅ Verify Security

Run this command to ensure your API key won't be committed:
```bash
git status
```

You should NOT see `APIKeys.plist` in the list of files to be committed.

## 🔄 Team Setup

When sharing this project:

1. **Share**: `APIKeys-Example.plist` (template)
2. **Don't share**: `APIKeys.plist` (contains real keys)
3. **Each developer** creates their own `APIKeys.plist` from the example

## 💰 Cost Monitoring

- Monitor usage at [Google AI Studio](https://makersuite.google.com/app/apikey)
- Gemini 2.0 Flash is currently FREE during experimental phase
- Set up billing alerts when it becomes paid

## 🆘 If API Key Gets Compromised

1. **Immediately** revoke the key at Google AI Studio
2. Generate a new API key
3. Update your local `APIKeys.plist`
4. Check git history to ensure the key was never committed

## 📁 File Structure

```
SplitSmart/
├── APIKeys-Example.plist     ✅ Safe to commit (template)
├── APIKeys.plist            ❌ Never commit (real keys)
└── Info.plist               ⚠️ Avoid storing keys here
```

## 🛡️ Additional Security Tips

1. **Never hardcode** API keys in source code
2. **Use different keys** for development/production
3. **Regularly rotate** API keys
4. **Monitor API usage** for unexpected charges
5. **Review `.gitignore`** before committing

---

**Remember**: If you accidentally commit an API key, it's compromised and should be revoked immediately, even if you delete it in a later commit!