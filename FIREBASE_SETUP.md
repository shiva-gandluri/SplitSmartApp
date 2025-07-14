# Firebase Setup for SplitSmart iOS

This document explains how to configure Firebase Authentication and Firestore for the SplitSmart iOS app.

## Prerequisites

1. **Firebase Project**: Create a project at [Firebase Console](https://console.firebase.google.com/)
2. **iOS App Registration**: Register your iOS app in the Firebase project
3. **Xcode 15.0+**: Required for SwiftUI and iOS 17+ support

## Step 1: Firebase Project Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Add an iOS app to your project:
   - **iOS bundle ID**: `com.splitsmart.app`
   - **App nickname**: SplitSmart iOS
   - **App Store ID**: (leave blank for development)

## Step 2: Download GoogleService-Info.plist

1. Download the `GoogleService-Info.plist` file from Firebase Console
2. Replace the placeholder file at `/SplitSmart/GoogleService-Info.plist` with your actual file
3. **Important**: The placeholder contains dummy values that need to be replaced

### Required Configuration Values

Your `GoogleService-Info.plist` should contain these actual values:

```xml
<key>CLIENT_ID</key>
<string>YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com</string>

<key>REVERSED_CLIENT_ID</key>
<string>com.googleusercontent.apps.YOUR_ACTUAL_REVERSED_CLIENT_ID</string>

<key>API_KEY</key>
<string>YOUR_ACTUAL_API_KEY</string>

<key>PROJECT_ID</key>
<string>your-actual-project-id</string>
```

## Step 3: Enable Authentication Methods

1. In Firebase Console, go to **Authentication** > **Sign-in method**
2. Enable **Google** as a sign-in provider
3. Configure the OAuth consent screen if prompted

## Step 4: Set Up Firestore

1. In Firebase Console, go to **Firestore Database**
2. Create a database (start in test mode for development)
3. Set up security rules (see below)

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read and write their own user document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Additional rules for groups, expenses, etc. can be added here
  }
}
```

## Step 5: Configure URL Scheme

The project is already configured with the URL scheme pattern, but you need to update it with your actual REVERSED_CLIENT_ID:

1. In `project.pbxproj`, find the line containing `YOUR_REVERSED_CLIENT_ID`
2. Replace it with your actual reversed client ID from the `GoogleService-Info.plist`

## Step 6: Build and Test

1. Open `SplitSmart.xcodeproj` in Xcode
2. Build and run the project
3. Test the Google Sign-In flow

## User Story Implementation

The implementation satisfies the acceptance criteria:

✅ **AC1**: App displays "Sign in with Google" button on initial screen  
✅ **AC2**: Tapping button initiates Google sign-in flow  
✅ **AC3**: Successful authentication creates user account in Firebase Auth  
✅ **AC4**: User navigates to home screen after authentication  
✅ **AC5**: Error messages displayed for failed sign-in attempts  
✅ **AC6**: User record (UID) created in Firestore for FCM token linking  

## Features Implemented

### Authentication Flow
- **AuthViewModel**: Manages authentication state using `@ObservableObject`
- **Google Sign-In Integration**: Uses GoogleSignIn SDK with SwiftUI
- **Automatic Navigation**: Conditional view rendering based on auth state
- **Error Handling**: User-friendly error messages for failed authentication

### User Interface
- **AuthView**: Clean sign-in screen with Google button
- **ProfileView**: Displays user info with sign-out functionality
- **Responsive Design**: Works on all iOS device sizes

### Data Management
- **Firestore Integration**: Creates user documents with UID, email, display name
- **Real-time Updates**: Uses Firebase listeners for auth state changes
- **Secure Configuration**: Proper Firebase initialization and security

## Troubleshooting

### Common Issues

1. **"Firebase configuration error"**
   - Ensure `GoogleService-Info.plist` contains actual values
   - Verify the file is added to the Xcode project

2. **"Unable to get root view controller"**
   - This is a rare iOS simulator issue; restart the simulator

3. **Google Sign-In button not working**
   - Check that the REVERSED_CLIENT_ID is correctly configured
   - Ensure Google authentication is enabled in Firebase Console

4. **Build errors about missing Firebase modules**
   - Make sure Swift Package Manager dependencies are resolved
   - In Xcode: File > Packages > Resolve Package Versions

### Development vs Production

For production deployment:
1. Update Firestore security rules for production use
2. Configure proper OAuth consent screen
3. Set up App Store Connect configuration
4. Update bundle identifier if needed

## Next Steps

After basic authentication is working:
1. Add user profile management
2. Implement expense sharing features
3. Add push notifications using FCM tokens
4. Set up proper error tracking and analytics