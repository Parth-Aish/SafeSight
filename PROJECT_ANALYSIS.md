# SafeSight Project Analysis

## 1. Executive Summary

SafeSight is a Flutter personal-safety companion for people who want immediate awareness, emergency activation, and trusted-contact support while travelling or moving through unfamiliar areas.

The current application is a functional mobile-oriented MVP with these core ideas:

- Scan the user's surroundings using GPS and open geospatial data.
- Show nearby police stations, hospitals, pharmacies, and other potentially useful safe zones.
- Estimate a local safety status from news, physical infrastructure, and community incident reports.
- Let a user trigger an SOS after a deliberate press-and-hold gesture.
- Share a live tracking PIN with emergency contacts or SafeSight guardians.
- Provide defensive tools such as a fake call, siren, evidence recording, incident reporting, and background alerts.
- Use Firebase Authentication and Firestore for identity, incidents, alerts, contacts, and live sessions.

The product direction is strong: SafeSight is trying to combine prevention, rapid response, and social support in one app. The main gap is that the code currently puts a large amount of safety-critical behavior directly inside screens and client-side services. Before calling this production-grade, the system needs stronger backend authorization, more dependable emergency delivery, explicit failure states, platform validation, and substantially broader automated testing.

## 2. What We Are Building

### Product vision

SafeSight aims to be a calm, fast safety layer between a person and their environment. It should answer three questions quickly:

1. **What is around me?** Nearby services, reported incidents, and environmental signals.
2. **What should I do?** Navigate to a safer place, call for help, report an incident, or activate a deterrent.
3. **Who knows if something goes wrong?** Emergency contacts and trusted in-app guardians with a live location session.

### Primary users

- People travelling alone.
- Students and commuters returning home late.
- People who want a trusted-contact check-in workflow.
- Guardians or friends monitoring an active emergency session.
- Community members contributing reports about local hazards.

### Current product surface

The main authenticated experience has three persistent tabs:

| Tab | Purpose | Current implementation |
| --- | --- | --- |
| Home | Safety score, current area, safe-zone summary, SOS and quick actions | `DashboardTab` |
| Nearby | Map, safe-zone markers, route preview, external navigation | `MapScreen` |
| Profile | Account, contacts, guardians, saved places, incident forum, settings | `ProfileTab` |

The app also contains focused emergency experiences:

- Hold-to-activate SOS.
- Fake incoming call screen.
- Siren/alarm screen.
- Audio evidence recording.
- Live tracking by six-digit PIN.
- Background monitoring using motion, volume changes, voice phrases, location, and notifications.

## 3. Current Architecture

### Application bootstrap and navigation

`lib/main.dart` initializes Flutter, Firebase, the background engine, Riverpod, and a `GoRouter` instance. The route table currently contains:

- `/` -> splash screen
- `/login` -> email/Google login
- `/signup` -> account creation
- `/home` -> the main tab shell

The splash screen waits three seconds and then checks `FirebaseAuth.instance.currentUser` before redirecting. This is simple and visually polished, but it is not a reactive authentication guard. A later version should use an auth-state-driven router redirect so a signed-out user cannot reach protected screens through stale navigation state or a deep link.

### State management

Riverpod is installed and used for service providers such as `authServiceProvider` and `safetyServiceProvider`. Most screen state, however, is managed locally with `StatefulWidget`, timers, static fields, `SharedPreferences`, and a global cache.

Important current state locations:

- `GlobalMapCache.cachedZones` and `GlobalMapCache.userLocation` for shared map data.
- Static map fields in `MapScreen` for marker data and selected card persistence.
- `SharedPreferences` for emergency contacts, guardian emails, broadcast flags, user email, and settings.
- Firestore for incidents, users, live sessions, and active alerts.
- Local widget state for loading, timers, animation, GPS status, safety score, and broadcast status.

This approach makes tab switching feel fast, but it also spreads business state across several storage mechanisms. It increases the chance of stale data, race conditions, and inconsistent behavior after app restarts.

### Services and external systems

| System | Role | Current integration |
| --- | --- | --- |
| Firebase Auth | Email/password and Google sign-in | `AuthService` |
| Firestore | Users, incidents, active alerts, live sessions | Direct reads/writes from screens and services |
| Geolocator | Location permissions and current position | Dashboard, map, background engine |
| OpenStreetMap Nominatim | Reverse geocoding | Dashboard and safety service |
| OpenStreetMap Overpass | Safe-zone and infrastructure queries | Map and safety service |
| OSRM | Route geometry preview | Map screen |
| OpenStreetMap tiles | Map tiles | Map and live tracking screens |
| Local notifications | Foreground/background emergency alerts | Notification service |
| Background service | Android foreground monitoring and iOS foreground callback | Background service |
| SMS/deep links | Contact notification and external Google Maps navigation | `url_launcher` |
| Device sensors/audio | Shake, volume, voice, siren, fake call, recording | SOS and background services |

## 4. Main User Flows

### First launch and authentication

1. Firebase is initialized in `main.dart`.
2. The background notification engine is configured.
3. The splash animation displays for approximately three seconds.
4. A current Firebase user sends the person to `/home`; otherwise the person goes to `/login`.
5. Email/password login and Google sign-in are available.
6. New email users receive a verification email and the login screen checks verification status.

Current issue: the email login flow does not sign the user out when the email is unverified. The UI shows a verification dialog, but the Firebase session may remain active. If the app restarts, the splash screen can see that session and route the user to Home. Verification should be enforced in one place, ideally through an auth gate and an explicit `needsVerification` state.

### Safety scan

1. The dashboard requests location permission and obtains a position.
2. It reverse-geocodes the position into a display address and city.
3. `SafetyService.analyzeLocation` concurrently checks:
   - recent crime-related news search results,
   - street lamps, surveillance, and police infrastructure,
   - recent Firestore community incidents within 1.5 km.
4. A heuristic score is calculated from those counts.
5. A crowd report forces the status to `HIGH ALERT` and a low score.
6. The UI displays `SAFE ZONE`, `MODERATE RISK`, or `HIGH ALERT`.

The scan refreshes frequently, with dashboard work scheduled every 15 seconds. News and infrastructure calls use simple process-level caching to reduce load.

### Nearby safe zones and navigation

1. The map gets a last-known or fresh GPS position.
2. Overpass is queried for police stations, hospitals, pharmacies, and malls around the user.
3. Large response parsing is moved to a Flutter isolate with `compute`.
4. Results become map markers and a horizontal selection list.
5. An OSRM route can be previewed in the app.
6. Google Maps can be opened externally for navigation.
7. If the public API fails, approximate fallback markers are generated near the current position.

The fallback keeps the UI usable but is not safe enough to present as real emergency infrastructure. It must be clearly labelled as unavailable or estimated and must never imply that a fabricated marker is a verified police station, hospital, or pharmacy.

### Manual SOS

1. The user must hold the SOS control for roughly two seconds.
2. The app requires at least one local emergency contact or in-app guardian.
3. A high-accuracy location is requested.
4. A six-digit tracking PIN is generated.
5. A `live_sessions` document is created in Firestore.
6. An `active_alerts` document is created for guardian emails.
7. The app opens an SMS composer for local contacts with the tracking PIN.
8. The button resets its local visual state after a short delay.

The current implementation is an alert initiation flow, not a guaranteed emergency dispatch flow. It does not itself call emergency services, guarantee SMS delivery, retry failed writes, or keep the tracking session alive through a server-owned process.

### Background protection

When enabled from Profile, the app requests notification and always-on location permission and starts a foreground service. The background engine listens for:

- strong accelerometer spikes,
- repeated volume changes,
- selected distress phrases through speech recognition,
- location and nearby danger conditions in the remainder of the service.

On detection, it can create a live session, write an active alert, show a local notification, and open an SMS deep link. This is an ambitious differentiator, but it is also the highest-risk subsystem because operating-system restrictions, permission changes, battery policies, microphone access, audio routing, and platform lifecycle behavior vary heavily by device.

## 5. Data Model and Storage

The current implicit Firestore model includes:

### `users/{uid}`

Used for at least:

- `emergency_contacts`: serialized contact maps containing values such as name and phone.

The dashboard reads this document and copies contacts into local preferences.

### `incidents/{incidentId}`

Fields currently written or read:

- `lat`
- `lng`
- `type`
- `userId`
- `timestamp`

The forum streams the whole collection. The safety scan also reads the whole collection before doing distance filtering on the client.

### `live_sessions/{pin}`

Fields currently used:

- `lat`
- `lng`
- `timestamp`
- `status`
- `destinationName`

The live tracking screen listens to one document by PIN and supports an `ARRIVED` state.

### `active_alerts/{alertId}`

Fields currently used:

- `victimEmail`
- `guardianEmails`
- `lat`
- `lng`
- `timestamp`
- `pin`
- `type`
- `reason`

The architecture currently stores guardian identifiers and emergency data in client-controlled values. This needs server-side validation and access control before production use.

### Local preferences

`SharedPreferences` currently holds emergency contacts, guardian emails, background-alert settings, broadcast PINs, cooldown flags, and audio-volume suppression flags. It is appropriate for non-sensitive settings, but it is not a secure vault and should not be treated as authoritative for identity, permissions, or emergency delivery state.

## 6. What Is Working Well

- The product has a clear safety-focused purpose and a memorable core loop.
- The Home/Nearby/Profile structure is easy to understand.
- The SOS control uses a deliberate hold gesture, reducing accidental activation.
- Map parsing uses `compute`, which protects UI responsiveness for larger Overpass responses.
- Map state is intentionally preserved across tabs with `IndexedStack` and keep-alive behavior.
- The app has graceful handling for several permission, timeout, and API failure cases.
- Emergency features are layered: visual SOS, SMS contacts, guardian alerts, live location, fake call, siren, and evidence recording.
- Authentication errors are translated into user-facing messages instead of exposing only raw Firebase codes.
- The app uses explicit timeouts for many network and GPS operations.
- The UI has a consistent visual language built around dark surfaces, sky blue actions, green safe states, and red danger states.

## 7. Highest-Priority Improvements

### P0: Safety, security, and correctness

#### 1. Put authorization in Firestore Security Rules and backend code

The client currently writes directly to collections and the forum streams all incidents. Define and test rules so that:

- a user can read only the incident data needed for the product,
- users can create reports but cannot impersonate another user,
- users can update or stop only their own live sessions,
- guardians can read only sessions and alerts to which they are legitimately linked,
- email strings in a document are not treated as proof of guardian identity,
- sensitive fields such as exact coordinates and contact phone numbers are minimized.

For alert fan-out, use a trusted backend such as Firebase Cloud Functions or another server component. The server should validate the authenticated user, resolve guardian relationships, create notifications, and record delivery status.

#### 2. Replace full-collection incident scans with indexed geospatial queries

`SafetyService._checkCrowdReports` reads all incident documents and filters them on the device. This is expensive, slow, difficult to secure, and will become unusable as data grows. Store a geohash or use a geospatial query strategy, constrain by time in the query, add pagination, and return only the fields needed for the scan.

#### 3. Make SOS delivery reliable and observable

The current SOS depends on a Firestore write and opening an SMS composer. Add:

- an explicit emergency state machine (`arming`, `triggered`, `sending`, `sent`, `failed`, `cancelled`),
- retries with bounded backoff for network writes,
- a persistent outbox for offline activation,
- delivery status and timestamps,
- a clear confirmation screen,
- a way to stop or expire a live session,
- a server-generated session ID rather than a predictable short PIN as the sole access credential.

Do not claim that an SMS was sent merely because `launchUrl` succeeded; that only means the external composer was opened.

#### 4. Fix authentication gating

Use a single reactive auth controller or `GoRouter` redirect based on `authStateChanges`. Explicitly model:

- signed out,
- signed in but unverified,
- signed in and verified,
- loading,
- authentication error.

The current splash delay should not be the mechanism that controls access. Also add password reset, account deletion, provider-linking behavior, and a clear unverified-email route.

#### 5. Remove fabricated emergency locations from the user trust boundary

The map fallback currently creates plausible-looking police, hospital, and pharmacy markers by offsetting the current coordinate. That is acceptable as a development placeholder only. In production, show a clearly labelled offline state or cached verified results; never display invented locations as real services.

#### 6. Review background monitoring against platform policy and device behavior

Create a capability matrix for Android and iOS covering always-on location, microphone, speech recognition, foreground service types, notification permission, battery optimization, and app termination. Background monitoring must be opt-in, explain what is collected, show an active status, provide a reliable stop control, and degrade safely when a platform blocks a capability.

### P1: Reliability and maintainability

#### 7. Separate presentation, domain, and data layers

Several screens contain networking, Firestore writes, GPS permissions, timers, navigation, persistence, and UI rendering in one class. Introduce feature-level controllers/notifiers and repositories:

- `LocationRepository`
- `SafeZoneRepository`
- `IncidentRepository`
- `EmergencyRepository`
- `GuardianRepository`
- `AuthRepository`

Expose immutable state objects through Riverpod. Keep widgets focused on rendering and user interaction.

#### 8. Replace global mutable caches with typed state

Convert `List<dynamic>` and static cache fields into typed models such as `SafeZone`, `Incident`, `SafetyAssessment`, and `LiveSession`. Give cache entries timestamps, source, accuracy, and freshness. Centralize invalidation and avoid having both a static map cache and a separate global cache represent the same data.

#### 9. Define a consistent error and loading model

Most failures currently go to `debugPrint`, a SnackBar, or a silent fallback. Use typed failures and visible states for:

- permission denied,
- location unavailable,
- network timeout,
- rate limited public API,
- Firebase unavailable,
- stale data,
- microphone/audio unavailable,
- emergency delivery failure.

The user should always know whether the displayed safety result is live, cached, estimated, or unavailable.

#### 10. Control refresh work and race conditions

The dashboard refresh loop can overlap network requests, and multiple screens can independently request location and external APIs. Add cancellation or request versioning so an older response cannot overwrite newer state. Use a central refresh coordinator and backoff instead of a fixed 15-second loop for every operation.

#### 11. Treat public APIs as unreliable dependencies

Overpass, Nominatim, OSRM, news RSS, and map tiles have rate limits, availability issues, attribution requirements, and varying data quality. Add user-agent/attribution compliance, response validation, rate limiting, retries only where appropriate, and a provider abstraction so the app can swap providers or add a proxy/cache later.

### P1: Privacy and trust

- Publish a privacy policy describing precise location, background location, microphone, speech recognition, contacts, incident reports, and audio evidence.
- Minimize exact location retention and define expiration for `live_sessions`, `active_alerts`, and incident data.
- Do not store more contact data than needed; consider secure storage for local emergency information.
- Use anonymous or pseudonymous community reporting where possible.
- Add consent and an in-app disclosure before background microphone or location monitoring.
- Add abuse reporting, moderation, rate limits, and duplicate detection for community incidents.
- Avoid exposing exact coordinates in a public forum unless the user explicitly consents and the product genuinely needs it.

### P2: Product quality and differentiation

#### Check-in journeys

Add a planned arrival workflow: choose a destination, start a timer, notify a guardian, send reminders, and escalate only when the user misses the check-in.

#### Better risk explanations

Show why a score changed, the age and source of each signal, and confidence. A single number should never be the only safety recommendation.

#### Trusted places and routes

Complete saved places and add safer-route preferences, accessible routes, transport stops, and one-tap navigation to verified nearby help.

#### Guardian experience

Add an authenticated guardian inbox, active-alert history, acknowledgement, call shortcuts, and clear session expiry. Guardian invitations should be accepted by the invited account rather than stored as a local email list.

#### Accessibility and localization

Test large text, screen readers, high contrast, reduced motion, haptic/audio alternatives, right-to-left layouts, and translated emergency copy. Emergency actions must remain understandable without relying on color alone.

## 8. Safety Score Assessment

The current score is a simple weighted heuristic:

- start at `0.5`,
- adjust for news count,
- adjust for infrastructure count,
- clamp the result,
- override to a low score for any nearby crowd report.

This is useful for a demo because it makes multiple data sources visible, but it is not yet a defensible measure of personal safety. Problems include:

- news article count is not the same as local incident severity,
- public infrastructure tags are incomplete and inconsistently mapped,
- one report can dominate all other signals,
- missing data can look like a safe result,
- there is no confidence or freshness score,
- the thresholds are not calibrated against labelled outcomes,
- the system does not distinguish time of day, route, population density, or incident type.

Recommended next step: rename the value to something like `environmental risk estimate`, expose its source and freshness, and maintain separate dimensions such as `nearby incidents`, `help availability`, `environmental visibility`, and `data confidence`. Only later consider a single composite score after collecting anonymized evaluation data and defining false-positive/false-negative costs.

## 9. Testing Strategy

The repository currently has one smoke test in `test/widget_test.dart`. It builds `SafeSightApp` and checks the splash branding. That is a useful boot check but does not cover the safety-critical behavior.

### Unit tests to add

- Password strength validation and Firebase error mapping.
- Safety score thresholds and crowd-report override.
- Incident freshness and distance filtering.
- Overpass, OSRM, and RSS response parsing with malformed data.
- Cache freshness and invalidation.
- SOS state transitions and cooldown behavior.
- Guardian/session expiration logic.

### Widget tests to add

- Login validation and loading state.
- Unverified email behavior.
- Hold-to-trigger SOS, cancellation, and no-contact handling.
- Permission-denied UI for map and dashboard.
- Empty, loading, cached, and error states.
- Live tracking active, ended, and arrived states.

### Integration/device tests to add

- Firebase emulator tests for authentication and Firestore security rules.
- Android tests on multiple vendors for foreground service and volume/shake triggers.
- iOS tests for location/audio permission flows and background limitations.
- Offline and airplane-mode SOS behavior.
- Deep-link behavior for Google Maps and SMS.
- Accessibility tests with large text and screen readers.

### Operational checks

- Crash reporting and non-sensitive emergency-event telemetry.
- API latency, timeout, rate-limit, and cache-hit metrics.
- Alert creation and delivery audit trail.
- Battery impact of background monitoring.
- Firestore read/write cost monitoring.

## 10. Recommended Delivery Roadmap

### Phase 1: Make the MVP trustworthy

1. Add Firestore Security Rules and emulator tests.
2. Fix reactive authentication and email verification gating.
3. Remove fabricated map fallback markers.
4. Implement typed emergency/session state with retry and expiry.
5. Add explicit stale/offline/error labels.
6. Add unit tests for scoring, parsing, SOS, and auth.

### Phase 2: Stabilize the platform

1. Move Firestore/API logic into repositories and Riverpod controllers.
2. Add geospatial incident queries and indexes.
3. Move alert fan-out and guardian resolution to trusted backend code.
4. Validate background behavior on representative Android and iOS devices.
5. Add privacy consent, data retention, deletion, and moderation workflows.

### Phase 3: Improve the product

1. Add check-in journeys and planned arrival monitoring.
2. Complete the guardian inbox and acknowledgement flow.
3. Improve safety explanations, confidence, freshness, and route context.
4. Add accessibility, localization, and design-system consistency.
5. Add analytics focused on successful assistance rather than engagement alone.

### Phase 4: Prepare for production

1. Replace or proxy public APIs where reliability and rate limits require it.
2. Complete threat modelling and an independent security review.
3. Run a staged beta with emergency-flow drills and clear disclaimers.
4. Define support, incident response, data retention, and abuse-handling procedures.
5. Establish release gates for permission changes, background behavior, and emergency delivery.

## 11. Definition of Production Readiness

SafeSight should not be described as production-ready until all of the following are true:

- Emergency activation has a tested, observable delivery path with clear failure handling.
- Firestore rules prevent unauthorized reading and writing of sensitive data.
- Authentication state cannot bypass verification or protected routes.
- All displayed safe-zone data is verified, cached, or explicitly marked unavailable.
- Background features have documented support and limitations on each target platform.
- Location, audio, contacts, and incident retention are consented to and documented.
- Safety results show source, freshness, uncertainty, and limitations.
- Critical flows have automated tests plus real-device tests.
- The app has crash reporting, operational logs, cost monitoring, and an emergency support plan.

## 12. Bottom Line

SafeSight already has the bones of a compelling safety companion: a clear user promise, an effective three-tab shell, practical location intelligence, and unusually broad emergency tooling. The next meaningful step is not adding more sensors or more screens. It is making the existing emergency and location flows trustworthy under bad connectivity, denied permissions, stale data, app restarts, platform restrictions, and adversarial access.

The strongest near-term investment is a reliable emergency domain layer backed by secure Firebase rules and server-side alert orchestration. Once that foundation is in place, the map, guardian network, safety assessment, and background features can grow without asking users to trust behavior that the current client-only architecture cannot yet guarantee.

## 13. Refactor Status

The first implementation pass has established these pieces:

- Typed `SafetyAssessment`, `SafeZone`, and `Guardian` models.
- Isolated Google News RSS and optional Gemini data sources.
- A repository-backed seven-day incident query with a bounded result set.
- A conservative safety result: no recent incidents defaults to `SAFE`; missing Gemini configuration does not invent an alert.
- A Firestore-backed guardian repository used by the SOS eligibility gate.
- An explicit emergency state model and UUID-backed live-session repository.
- Removal of fabricated map fallback markers; unavailable verified centers are now shown as unavailable.
- Removal of direct SMS composer dispatch from SOS, live tracking, arrival, and background alerts.
- A corrected splash smoke test assertion.

These changes are deliberately an incremental migration. FCM server-side fan-out, six-character/QR guardian acceptance, Firestore Security Rules, an active emergency screen, periodic background location updates for the new SOS controller, and MapLibre/OpenFreeMap migration still require dedicated follow-up work. A Gemini API key should be supplied through `--dart-define=GEMINI_API_KEY=...` for development; production deployments should proxy model access through trusted backend code rather than shipping a reusable API key in the client.

## 14. Runtime Log Remediation

The Android trace exposed several operational requirements that are now reflected in the codebase:

- Background Firebase initialization no longer treats every exception as "already initialized" and no longer continues Firestore work when initialization fails.
- Background Firestore work is skipped when the isolate has no restored authenticated user, preventing owner-rule violations.
- `victimUid` is written to new live sessions and alerts so security rules can authorize the owner.
- Firestore rules and the `active_alerts`/`incidents` index definitions are included in `firestore.rules` and `firestore.indexes.json` and must be deployed to the Firebase project.
- SOS and background location acquisition now fall back to a last-known position after a bounded current-location timeout.
- Overpass requests use encoded query parameters and verified emergency-center tags, addressing the previous HTTP 406 response.
- RSS input is capped at 20 headlines before optional AI assessment to avoid oversized prompts.

Deploy the Firebase configuration before testing guardian alerts:

```bash
firebase deploy --only firestore
```

The remaining `curly_braces_in_flow_control_structures` analyzer messages are style infos in older files, not runtime failures. The Google Play Services provider-installation warnings are device/environment diagnostics and are separate from SafeSight's Firebase and Firestore issues.