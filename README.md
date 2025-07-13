# SplitSmart iOS App

A native iOS app built with SwiftUI for splitting bills and tracking expenses with friends and family.

## Features

- **Home Dashboard**: View balances, see who owes you money and who you owe
- **Groups**: Create and manage expense groups with friends
- **Receipt Scanning**: Take photos of receipts or enter bills manually
- **History**: Track all your transactions and splits
- **Profile**: Manage your settings and preferences

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later

### Installation

1. Open `SplitSmart.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd + R` to build and run

### Project Structure

```
SplitSmart/
├── SplitSmartApp.swift          # App entry point
├── ContentView.swift            # Main tab view
├── UIComponents.swift           # UI components matching React design
├── GroupsView.swift            # Groups management
├── HistoryView.swift           # Transaction history
└── README.md                   # This file
```

## Usage

### Creating a New Split

1. Tap the "Create New Split" button on the home screen
2. Enter the split details (title, amount, friends)
3. Choose your split method (equal, by amount, by percentage)
4. Confirm and create the split

### Scanning Receipts

1. Go to the Scan tab
2. Take a photo of your receipt or choose from photos
3. Review and edit the extracted items
4. Assign items to different people
5. Create the split

### Managing Groups

1. Go to the Groups tab
2. Create new groups with friends
3. Add members by email
4. Track group expenses and balances

## Key Features

- **SwiftUI**: Modern, declarative UI framework
- **Native Performance**: Smooth, responsive iOS experience
- **Intuitive Design**: Clean, user-friendly interface
- **Local Data**: Sample data for demonstration

## Future Enhancements

- Firebase integration for real-time sync
- Receipt OCR scanning
- Push notifications
- Payment integration
- Dark mode support
- iPad optimization

## Development

This is a demonstration app showcasing modern iOS development practices with SwiftUI. The app uses sample data and is ready for backend integration.

### Architecture

- **MVVM Pattern**: Clear separation of views and data
- **SwiftUI**: Reactive UI framework
- **Observable Objects**: State management
- **Navigation**: iOS-native navigation patterns

### Sample Data

The app includes sample data in `UIComponents.swift` showing:
- Example debts and balances
- Sample groups and members
- Transaction history

## License

This project is for demonstration purposes.