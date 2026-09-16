<div align="center">

# SafeSight

**Beautifully Designed. Uncompromisingly Secure.**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)](https://firebase.google.com/)
[![Security](https://img.shields.io/badge/Post--Quantum-Secured-black?style=for-the-badge&logo=shield)](https://github.com/jedisct1/libsodium)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

*At SafeSight, we believe privacy is a fundamental human right. Personal safety shouldn't require trading away your personal data. That’s why we’ve completely reimagined what a safety companion can be—harnessing the power of on-device machine learning and post-quantum encryption.*

</div>

---

## 🛡️ Privacy by Design, Not by Chance.

SafeSight represents a paradigm shift in personal safety architecture. Traditional applications upload sensitive ambient audio and live location data to central servers. We designed a system that processes the world around you **directly on your device**, without ever sending raw data to the cloud.

When a crisis occurs, your location is transmitted using End-to-End Encryption (E2EE), mathematically ensuring that nobody—not us, not third parties, not even compromised networks—can decipher your coordinates. Only your designated Guardians hold the keys.

---

## ✨ Features That Set a New Standard

### 🧠 Edge Intelligence
Rethink what your device can do. SafeSight leverages an advanced **TFLite On-Device Neural Audio Classifier** that continuously monitors ambient frequencies for high-confidence distress signals (like screams). Because the model runs entirely on the edge, the microphone stream is never uploaded. It’s intelligence that respects your privacy.

### 🔒 Post-Quantum Security
Future-proof protection. Utilizing **Libsodium (X25519)**, SafeSight wraps every live location broadcast and payload in cryptographic armor. Even as quantum computing evolves, your live sessions remain profoundly opaque to anyone without your precise decryption keys.

### 📡 Offline Mesh Network
Safety shouldn't rely on cell towers. When cellular and Wi-Fi networks drop, SafeSight seamlessly falls back to a **Bluetooth Low Energy (BLE) Mesh Relay**. It broadcasts encrypted SOS payloads locally to nearby devices, turning proximity into a lifeline.

### 🚶 Walk With Me
A companion that’s always paying attention. Activate tactical routing that continuously verifies your state through hardware shake detection and snatch-verification timeouts. 
- **Duress PIN:** Coerced into disabling the alarm? A silent duress PIN appears to disable the system locally while simultaneously broadcasting an emergency payload to your Guardians.

### 🗺️ Fluid, Uninterrupted Navigation
Crafted for performance. Inspired by world-class, fluid user interfaces, SafeSight employs a highly optimized caching layer and IndexedStack architecture to ensure map states remain active, rendering complex safety routing with absolute zero lag.

---

## ⚙️ Architecture & Technologies

Built on a foundation of open-source, zero-cost technologies, meticulously engineered for scale and speed:

- **Core Engine:** Flutter (SDK ^3.5.0) for a native, 120Hz-capable user experience.
- **State Architecture:** Riverpod (`flutter_riverpod`) for robust, predictable state management.
- **Cryptography:** `libsodium` / `crypto` for uncompromising E2EE operations.
- **Machine Learning:** `tensorflow_lite` edge deployment.
- **Backend & Transport:** Firebase & Firestore (purely as a blinded relay).
- **Cartography:** `flutter_map`, OSRM, and Overpass API for telemetry-free routing.

---

## 🚀 Getting Started

Experience the future of personal safety today.

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.5.0 or higher)
- Android Studio or Xcode (for iOS deployment)

### Build Instructions

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Parth-Aish/SafeSight.git
   cd SafeSight
   ```

2. **Acquire Dependencies**
   ```bash
   flutter pub get
   ```

3. **Deploy to Device**
   ```bash
   flutter run
   ```

4. **Compile Production Release**
   ```bash
   flutter build apk --release
   ```
   *The optimized Android package will be generated at `build/app/outputs/flutter-apk/app-release.apk`.*

---

<div align="center">
  <p><b>SafeSight</b></p>
  <p><i>Empowering your safety. Protecting your privacy.</i></p>
</div>