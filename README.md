SafeSight 🛡️

SafeSight is a Flutter safety companion app combining OpenStreetMap location context with Firebase-powered community reports and emergency tools.

🚀 Key Features

Real-Time Safe Zone Mapping: Instantly locates nearby Police Stations, Hospitals, Pharmacies, Malls, and Cafes within a 2.5km radar radius using the OpenStreetMap Overpass API.

Smart Navigation: Offers an in-app route preview via public OSRM and an OpenStreetMap directions link.

Community Safety Feed: Authenticated users can report suspicious activity, fires, floods, road hazards, and emergencies. Reports appear in the feed and as map markers.

Persistent "Zomato-Style" UI: Custom caching and IndexedStack architecture ensure the map state, active routes, and selected cards survive tab switches with zero lag.

Emergency Dashboard: One-tap SOS button, quick actions (Fake Call, Share Location, Siren), and reverse-geocoded location tracking.

Secure Authentication: Firebase-powered authentication supporting both Email/Password (with strength validation) and Google Sign-In.

🛠️ Tech Stack

Framework: Flutter (SDK ^3.5.0)

State Management: Riverpod (flutter_riverpod)

Routing: GoRouter

Maps & Location: flutter_map, geolocator, latlong2

APIs: OpenStreetMap, Overpass, OSRM Public Routing, and Google News RSS (no API key)

Backend: Firebase Authentication and Cloud Firestore on the Spark plan

## Free-service limits and operating rules

This app has no paid API, subscription, or billing dependency:

- **Firebase Spark:** Use Authentication and Firestore within the no-cost quotas: Firestore documents 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day, 1 GiB stored data, and 10 GiB/month outbound transfer. Limits can change, so monitor the Firebase console and do not enable billing for this app.
- **OpenStreetMap standard tiles:** Free and keyless, but best-effort with no SLA. The app uses HTTPS, visible attribution, an identifying app name, and interactive viewport requests only. Do not add tile prefetch or offline downloads.
- **Overpass and OSRM:** Free public community services with no guaranteed SLA or commercial quota. Requests are bounded and time out with empty/error fallbacks. Production-scale deployments should switch endpoints or self-host.
- **Google News RSS:** Keyless recent headlines with no contractual SLA or published permanent quota. News is optional context and the app continues when it is unavailable.

Respect each provider's acceptable-use policy. Free public endpoints are not an uptime guarantee.

## Configuration and privacy

Firebase platform configuration is generated locally by FlutterFire and should be supplied as deployment configuration, not hand-written into application logic. Do not add API keys, service-account files, or private tokens to Dart code or source control. Protect Firebase data with Firestore rules.

🏁 Getting Started

This project is a starting point for a Flutter application. A few resources to get you started if this is your first Flutter project:

Lab: Write your first Flutter app

Cookbook: Useful Flutter samples

For help getting started with Flutter development, view the online documentation, which offers tutorials, samples, guidance on mobile development, and a full API reference.

Prerequisites

Flutter SDK

Dart SDK

Firebase CLI (npm install -g firebase-tools)

FlutterFire CLI (dart pub global activate flutterfire_cli)

Installation

Clone the repository and navigate to the project directory.

Install the necessary dependencies:

flutter pub get


🔥 Firebase Setup

This project uses Firebase for authentication and other services. To set up Firebase locally:

Create a Firebase project at the Firebase Console.

Enable Authentication and activate the providers you need (Email/Password & Google Sign-In).

Run the following command in the project root to link your app and generate lib/firebase_options.dart and android/app/google-services.json:

flutterfire configure


For iOS, also configure the iOS app if needed.

⚠️ Note: Firebase configuration files (lib/firebase_options.dart, android/app/google-services.json, ios/Runner/GoogleService-Info.plist) are ignored by git for security reasons. You must generate them locally on your machine.

🗺️ Maps & API Configuration

The app utilizes OpenStreetMap tiles and Overpass APIs for location data.

No API key is required out of the box.

Background isolates (compute) are used heavily for parsing massive map data to ensure 60FPS UI performance.

Please respect the rate limits of the public OSRM and Overpass servers during heavy testing.