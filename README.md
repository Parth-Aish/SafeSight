# safesight

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Setup

This project uses Firebase for authentication and other services. To set up Firebase locally:

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Enable Authentication and any other services you need.
3. Run `flutterfire configure` in the project root to generate `lib/firebase_options.dart` and `android/app/google-services.json`.
4. For iOS, also configure the iOS app if needed.

**Note:** Firebase configuration files (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are ignored by git for security reasons. You must generate them locally.
