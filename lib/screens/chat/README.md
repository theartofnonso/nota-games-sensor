# Sendbird One-to-One Chat Implementation

This implementation provides one-to-one messaging between users and the platform admin/coach using Sendbird Chat SDK.

## Setup Instructions

### 1. Install Dependencies

Run the following command to install the Sendbird Chat SDK:

```bash
flutter pub get
```

### 2. Configure Sendbird

1. Sign up for a Sendbird account at https://dashboard.sendbird.com
2. Create a new application in the Sendbird Dashboard
3. Copy your Application ID from the dashboard
4. Update `lib/config/sendbird_config.dart`:
   - Replace `YOUR_SENDBIRD_APP_ID` with your actual Application ID
   - Replace `admin_user_id` with your admin/coach user ID

### 3. Backend Setup (Recommended)

For production, channel creation and permissions should be handled by your backend:

- Create a backend endpoint that creates channels when needed
- Implement proper authentication and authorization
- Handle channel permissions (who can read/write)
- The frontend will call this endpoint to get or create channels

### 4. Usage

#### Navigate to Chat Screen

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChatScreen(
      adminUserId: SendbirdConfig.adminUserId,
    ),
  ),
);
```

#### Initialize Sendbird (Optional - in app initialization)

You can initialize Sendbird in your app's main initialization:

```dart
// In main.dart or app initialization
await SendbirdChatService().initialize(
  appId: SendbirdConfig.appId,
);
```

## Features

- ✅ One-to-one messaging between user and admin/coach
- ✅ Persistent conversations (unique per user)
- ✅ Real-time message updates
- ✅ Message history loading
- ✅ Read receipts
- ✅ Auto-scroll to latest messages
- ✅ Connection status indicators
- ✅ Unread message count

## Architecture

- **SendbirdChatService**: Singleton service managing Sendbird connections and channels
- **ChatScreen**: UI screen for displaying and sending messages
- **SendbirdConfig**: Configuration file for App ID and admin user ID

## Channel Structure

Each user gets a unique channel with the format: `user_{userId}_admin`

This ensures:
- One persistent channel per user
- Easy identification of user channels
- Backend can easily query and manage channels

## Notes

- Channel creation is currently handled in the frontend as a fallback
- For production, move channel creation to your backend
- The admin/coach user must be created in Sendbird Dashboard or via backend
- Messages are stored in Sendbird and persist across app sessions
