# SafeSight 🛡️

SafeSight is an ultra-reliable, privacy-first personal safety companion app operating strictly on open-source, zero-cost technologies.

🚀 **Next-Gen Key Features**

- **Post-Quantum Encrypted Live Sessions**: End-to-End Encryption (using Libsodium / X25519 or Kyber) ensures live location coordinates written to Firestore/Supabase remain opaque ciphertexts decryptable only by paired guardians.
- **Edge Neural Audio**: On-device TFLite audio classifier service monitoring high-confidence scream and distress frequencies offline; suppresses microphone upload entirely.
- **Offline Mesh Relay**: Flutter BLE beacon fallback service broadcasting SOS payloads locally when network connectivity drops.
- **Deterministic AI Risk Scoring**: Interfaces with Gemini 1.5 Flash to synthesize nearby verified safety infrastructure (police/hospitals via Overpass) with recent incidents to generate real-time risk scores.
- **Walk With Me Mode**: Tactical routing with hardware shake detection, duress PIN verification, and snatch verification timeouts.
- **Zomato-Style UI Architecture**: Custom caching and IndexedStack architecture to keep map states active with zero lag.

🛠️ **Tech Stack**

- **Framework**: Flutter (SDK ^3.5.0)
- **State Management**: Riverpod (`flutter_riverpod`)
- **Routing**: GoRouter
- **Maps**: `flutter_map`, OpenStreetMap, Overpass, OSRM
- **Cryptography**: `libsodium` / `crypto`
- **Backend**: Firebase / Firestore

## Installation & Deployment

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Parth-Aish/SafeSight.git
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the App:**
   ```bash
   flutter run
   ```

To build a release APK:
```bash
flutter build apk --release
```

## Security & Privacy Note

SafeSight places user privacy at the core of its architecture.
- All location tracking during emergencies is purely end-to-end encrypted. Firebase and our servers only see ciphertexts.
- Audio and motion heuristics are analyzed on-device using Edge AI. 
- Infrastructure routing via Overpass and OpenFreeMap does not log user telemetry.

*Stay Safe. Stay Secure.*