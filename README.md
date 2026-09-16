<div align="center">
  <!-- You can replace this with your actual app icon if hosted, or leave it to show a sleek text header -->
  <h1>SafeSight</h1>
  <p><strong>The most advanced personal safety engine ever created.</strong></p>
</div>

---

At SafeSight, we believe that personal safety is not a luxury, and privacy is a fundamental human right. 

SafeSight is a paradigm shift in how we think about personal security. It's a beautifully designed, ultra-reliable safety companion that lives seamlessly on your device. We engineered it from the ground up to operate strictly on open-source, zero-cost technologies, ensuring that world-class protection is accessible to everyone. 

## Pro-Level Security. Uncompromising Privacy.

We challenged ourselves to build an architecture that protects you without ever compromising your data. The result is nothing short of magical.

### Post-Quantum Encrypted Live Sessions
We’ve implemented state-of-the-art End-to-End Encryption using Libsodium (X25519) and Kyber primitives. When you activate a live session, your location coordinates are transformed into opaque ciphertexts before they ever leave your device. Our servers see nothing. Only your trusted, paired guardians hold the keys to decrypt your location. It’s security that’s ready for the quantum future.

### Edge Neural Audio Intelligence
Why send your environment's audio to the cloud when your device is powerful enough to process it locally? Our on-device TFLite audio classifier service monitors for high-confidence scream and distress frequencies entirely offline. The microphone feed is processed in real-time on the edge, and the data is immediately discarded. Your voice never leaves your phone.

### Offline Mesh Relay
When network connectivity drops, SafeSight doesn't stop. Our custom Flutter BLE beacon fallback service automatically begins broadcasting encrypted SOS payloads locally. It creates an invisible, resilient mesh network to alert nearby devices when you need help most. 

### Deterministic AI Risk Scoring
SafeSight interfaces directly with Gemini 1.5 Flash to synthesize nearby verified safety infrastructure—like police stations and hospitals via Overpass—with recent incident data. It generates real-time, deterministic risk scores for your environment, empowering you with unparalleled situational awareness.

### Walk With Me Mode
A tactical routing engine designed for unpredictable situations. It features hardware-accelerated shake detection, discreet duress PIN verification, and snatch-verification timeouts. It’s like having a trusted guardian walking right beside you, every step of the way.

### Liquid Smooth UI Architecture
We built SafeSight using a custom caching and IndexedStack architecture. The map states remain active, delivering a zero-lag, liquid-smooth experience that feels incredibly responsive. It just works.

---

## 🛠️ The Technology Behind the Magic

SafeSight is built on a foundation of industry-leading, open-source technologies:

- **Framework**: Flutter (SDK ^3.5.0) for a beautiful, natively compiled experience.
- **State Management**: Riverpod (`flutter_riverpod`) for robust, scalable state.
- **Routing**: GoRouter for seamless navigation.
- **Maps**: `flutter_map`, OpenStreetMap, Overpass, and OSRM for dynamic, zero-cost routing.
- **Cryptography**: `libsodium` / `crypto` for uncompromising security.
- **Backend**: Firebase / Firestore (acting strictly as a blind relay).

---

## 🚀 Getting Started

Experience the future of personal safety today.

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

To build a highly optimized release APK:
```bash
flutter build apk --release
```

---

<div align="center">
  <p><em>Privacy is not an option. It's built in.</em></p>
  <p><strong>Stay Safe. Stay Secure.</strong></p>
</div>