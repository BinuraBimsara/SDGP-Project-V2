# App Check Setup

## Flutter

- App initializes App Check in `frontend/lib/main.dart`.
- Android uses `playIntegrity` in release and `debug` in debug mode.
- Apple uses `appAttestWithDeviceCheckFallback` in release and `debug` in debug mode.
- Web requires `RECAPTCHA_SITE_KEY` from build-time define.

Example:

```bash
flutter run --dart-define=RECAPTCHA_SITE_KEY=your_key
```

## Firebase Console

- Enable App Check for all client apps.
- Turn on enforcement for Firestore, Storage, and callable functions after token verification tests.
