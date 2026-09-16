# SafeSight Progress Tracker

## Emergency Lifecycle & Duress Protocol
- [x] Create Active SOS Screen with numeric keypad.
- [x] Wire `ActiveSosScreen` into `dashboard_tab.dart` or root navigation to overlay on active broadcast.
- [x] Refactor `sos_controller.dart` to validate `primary_pin` and `duress_pin` from local storage.
- [x] Implement covert silent escalation on Duress PIN entry.

## Environment Scan Optimization
- [x] Analyze codebase for legacy lighting telemetry mapping.
- [x] Remove `_DiagnosticBadge` mapping to `_infraCount` (street lighting false-positive reduction).

## Gemini News Sourcing Update
- [x] Update `RssNewsDataSource` to parse `<link>` element from RSS.
- [x] Modify `GeminiRiskDatasource` JSON schema to output `verifiedSources` array containing explicit headline URLs.
- [x] Propagate `verifiedSources` into `SafetyAssessment` domain model.
- [x] Render expandable "Recent 7-Day Local Reports" section in `dashboard_tab.dart` allowing users to click and launch news sources via `url_launcher`.

## Audit & Benchmarks
- [x] Publish `ACCURACY_AND_BENCHMARKS.md` detailing the AI performance metrics, FPR reduction, and cryptographic privacy guarantees.
