# Contact Management Feature

## Overview
The Contact Management feature allows users to save contact information for new participants who aren't yet registered with SplitSmart, making it easier to add them to future bills.

## User Flow

### Adding a New Contact
1. **Trigger**: User tries to add a participant with an email that's not registered with SplitSmart
2. **Modal Display**: "Add New Contact" modal appears with:
   - Pre-filled email (read-only)
   - Full Name field (required)
   - Phone Number field (optional)
3. **Validation**: Real-time validation for all fields
4. **Save Process**: 
   - Contact saved to Firestore user's contacts collection
   - Contact also saved to device contacts (if permission granted)
   - Success message displayed

### Contact Storage

#### Firestore Schema
```
users/{userId}/contacts/{contactId}
{
  id: string (UUID)
  fullName: string (required, 2-100 chars)
  email: string (required, valid email format)
  phoneNumber: string? (optional, validated format)
  createdAt: timestamp
  updatedAt: timestamp
}
```

#### Device Contacts
- Saved to device contacts app (with user permission)
- Name parsed into givenName/familyName
- Email and phone added as contact fields

## Security Features

### Firestore Security Rules
- Users can only read/write their own contacts
- Comprehensive data validation:
  - Email format validation
  - Full name length requirements
  - Phone number format validation
  - Required field enforcement

### Input Validation
- **Full Name**: Required, 2-100 characters
- **Email**: Valid email format, not already in contacts
- **Phone Number**: Optional, valid phone format if provided
- **XSS Protection**: All inputs sanitized via AuthViewModel validation

## Technical Implementation

### Key Components

#### `ContactsManager` (DataModels.swift:3221)
- Handles all Firestore contact operations
- Real-time contact loading via Firestore listeners
- Search functionality by name/email
- Input validation and duplicate checking

#### `NewContactModal` (UIComponents.swift:121)
- SwiftUI modal with form validation
- Device contacts integration
- Error handling and loading states
- Success/failure messaging

#### `UIAssignScreen` Integration (UIComponents.swift:536)
- Updated participant addition flow
- Contact modal triggering logic
- Success message handling

### Database Operations
- **Create**: Save new contact to Firestore + device
- **Read**: Real-time contact list via Firestore listener
- **Update**: Edit existing contact information
- **Delete**: Remove contact from Firestore
- **Search**: Filter contacts by name or email

## Error Handling

### Network Errors
- Firestore connection failures
- Timeout handling
- Retry mechanisms

### Validation Errors
- Duplicate email detection
- Invalid input format
- Required field enforcement

### Permission Errors
- Device contacts access denied
- Graceful degradation

## Future Enhancements

### Planned Features
1. **Contact Management Screen**: Full CRUD interface
2. **Contact Import**: Bulk import from device contacts
3. **Contact Sharing**: Share contacts between trusted users
4. **Contact Groups**: Organize contacts into groups
5. **Contact History**: Track which bills contacts were added to

### Technical Improvements
1. **Offline Support**: Cache contacts for offline access
2. **Sync Optimization**: More efficient real-time updates
3. **Advanced Search**: Search by multiple criteria
4. **Contact Validation**: Real-time email validation

## Testing

### Manual Test Scenarios
1. Add participant with unregistered email → Contact modal appears
2. Save contact with valid data → Success message, contact saved
3. Try duplicate email → Error message displayed
4. Save with device permission → Contact appears in device contacts
5. Save without device permission → Still saves to Firestore
6. Invalid email format → Validation error
7. Empty required fields → Form validation prevents save

### Integration Points
- Participant addition flow
- Device contacts permission handling
- Firestore authentication
- Real-time UI updates