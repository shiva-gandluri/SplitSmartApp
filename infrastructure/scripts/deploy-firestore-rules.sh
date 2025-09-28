#!/bin/bash

# Deploy Firestore Security Rules
# This script fixes multiple permissions errors:
# 1. Bills collection - participants can now view bills created by others
# 2. TransactionContacts subcollection - users can access their contact data

echo "🔥 Deploying Firestore Security Rules..."
echo "📍 Project: splitsmartapp-bd116"
echo "📁 Working Directory: $(pwd)"

# Navigate to Firebase directory
cd /Users/shivagandluri/Documents/SplitSmartApp/infrastructure/firebase

echo "📋 Deploying rules from: $(pwd)"
echo "🔧 Rules file: firestore.rules"

echo "🔍 Fixes included:"
echo "   ✅ Bills collection: Check both participantIds (UIDs) and participantEmails"
echo "   ✅ TransactionContacts subcollection: Proper user access rules"

# Deploy only Firestore rules
firebase deploy --only firestore:rules --project splitsmartapp-bd116

if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully!"
    echo "🎯 Fixes applied:"
    echo "   📋 Participants can now view bills created by others"
    echo "   📞 Users can now load transaction contacts"
    echo "   🔍 Rules check both UIDs and emails for bill access"
else
    echo "❌ Deployment failed!"
    echo "🔧 Ensure you're authenticated: firebase login"
    echo "📋 Ensure project exists: firebase projects:list"
    echo "🚨 Check Firebase Console for detailed error messages"
fi