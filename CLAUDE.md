# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SplitSmartApp is a native iOS app built with SwiftUI for splitting bills and tracking expenses. It uses Firebase for authentication and data persistence with Google Sign-In integration.

## Development Commands

### Build & Run
```bash
# Build the project
xcodebuild -project SplitSmart.xcodeproj -scheme SplitSmart -configuration Debug build

# Run in simulator (open Xcode and run)
open SplitSmart.xcodeproj
```

### Dependencies
Dependencies are managed via Swift Package Manager. The resolved packages are tracked in `SplitSmart.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Architecture

### Core Pattern
- **MVVM Architecture**: Clear separation with ViewModels managing state
- **SwiftUI**: Declarative UI with `@State`, `@StateObject`, `@EnvironmentObject`
- **Firebase Integration**: Authentication, Firestore, and error handling

### Key Components

#### Authentication (`AuthViewModel.swift`)
- Manages Google Sign-In flow and Firebase authentication
- Handles offline scenarios and API failures gracefully
- Uses async/await with timeout protection for Firestore operations
- **Important**: Firestore configuration happens in `SplitSmartApp.swift` app startup to avoid "settings already configured" errors

#### Navigation (`ContentView.swift`)
- Tab-based navigation with 5 main screens
- Conditional authentication flow (shows `AuthView` when not signed in)
- Environment object injection for shared state

#### UI Components (`UIComponents.swift`)
- Contains main screen implementations (Home, Scan, Profile)
- Mock data for development and testing
- Receipt scanning simulation flow

### Data Flow
1. App starts → Firebase configuration in `AppDelegate`
2. `AuthViewModel` checks authentication state
3. Shows `AuthView` or `ContentView` based on auth status
4. Main app uses tab navigation with shared `AuthViewModel`

## Firebase Setup

### Required Configuration
1. `GoogleService-Info.plist` must contain valid Firebase project credentials
2. Firestore API must be enabled in Firebase Console
3. Google Sign-In must be configured with proper OAuth client ID

### Error Handling Patterns
- Firestore operations are non-blocking to prevent UI freezing
- Timeout protection (10 seconds) for network operations
- Graceful degradation when Firestore API is disabled
- Specific error codes handling (offline, permission denied, etc.)

## Development Considerations

### State Management
- `@Published` properties in ViewModels for reactive updates
- Environment objects for dependency injection
- Local `@State` for component-specific data

### Async Patterns
- Use `async/await` for Firebase operations
- Wrap Firestore operations in `Task` blocks for non-blocking execution
- Implement timeouts using `withThrowingTaskGroup`

### Firebase Integration
- **Critical**: Configure Firestore settings only once in app startup
- Use `source: .default` for offline-capable document reads
- Handle `FirestoreErrorCode.permissionDenied` for disabled APIs

## Common Issues & Solutions

### Authentication Flow
- If sign-in hangs: Check Firestore API is enabled and network connectivity
- If crashes on sign-out/sign-in: Ensure `isInitialized` flag is reset in `signOut()`
- If "settings already configured" error: Move Firestore config to app startup only

### Build Issues
- Use `withThrowingTaskGroup` for concurrent operations with error handling
- Ensure proper async/await syntax in TaskGroup operations

## File Structure Priority

When making changes:
1. **`AuthViewModel.swift`**: Authentication logic and state management
2. **`SplitSmartApp.swift`**: App configuration and Firebase setup
3. **`ContentView.swift`**: Main navigation and view hierarchy
4. **`UIComponents.swift`**: Screen implementations and UI logic

## Testing Notes

The app currently uses mock data for development. When implementing features:
- Replace mock data in `UIComponents.swift` with real Firebase queries
- Test both online and offline scenarios
- Verify authentication state persistence across app restarts