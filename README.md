# Hope Line - Suicide Prevention App

Hope Line is a comprehensive mental health support application designed to provide immediate assistance to individuals in crisis.

## Features

### 1. Emergency Hotline (988)
- Direct call button to the National Suicide Prevention Lifeline (988)
- Prominent placement for quick access during crises

### 2. Emergency Contacts
- Add and manage personal emergency contacts
- Sends pre-recorded emergency messages to all contacts with a single tap
- Automatically initiates a call to the first emergency contact
- All contact data stored locally for privacy

### 3. AI Chat Assistant (DeepSeek API)
- AI-powered chat interface for emotional support
- Uses DeepSeek API for contextual, compassionate responses
- Recognizes crisis keywords and provides appropriate guidance
- Fallback responses when API is unavailable

### 4. Therapist Chat Connection
- TCP socket-based connection to mental health professionals
- Real-time chat with licensed therapists
- Secure and confidential communication
- Demo mode available for testing

### 5. Additional Resources
- Links to the Crisis Text Line and other support services
- Quick navigation to find a therapist

## Technical Implementation

- **Frontend**: Flutter with Material Design
- **Backend**: DeepSeek API integration
- **Communication**: TCP socket programming for therapist chat
- **Storage**: SharedPreferences for local data storage
- **Platform**: Android (with potential for iOS support)

## Installation

1. Download the APK from this link: https://drive.google.com/file/d/1kfsKtQ-n_ThDKPYZ0VlQdvlF6NvCJmdi/view?usp=drive_link
2. Enable installation from unknown sources in your device settings
3. Install the APK
4. Launch the Hope Line app

## Development Setup

1. Clone the repository
2. Install Flutter SDK and dependencies
3. Replace the placeholder DeepSeek API key in `lib/services/ai_service.dart`
4. Configure the server address for therapist chat in `lib/screens/therapist_chat_screen.dart`
5. Run `flutter pub get` to install dependencies
6. Run `flutter run` to launch in debug mode

## Privacy & Security

All sensitive user data is stored locally on the device. The app only requires internet access for the AI chat and therapist connection features.
