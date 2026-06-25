# Net Meter Flutter

A Flutter + native Android sample app for monitoring **mobile/SIM data only**:

- live mobile internet speed
- active data SIM / slot label
- mobile data usage for the whole phone
- mobile data usage per app
- adjustable time ranges
- charts
- PDF share/export

## Android reality check

Android allows per-app traffic stats through `NetworkStatsManager`, but the user must enable **Usage Access** for this app. On Android 10+ subscriber identifiers are restricted; this project queries mobile traffic with `subscriberId = null`, so historical usage is usually **all mobile data combined**. The app can still show the **currently active data SIM** with `SubscriptionManager.getActiveDataSubscriptionId()` when permission/device support allows it.

## How to run

```bash
flutter pub get
flutter run
```

If Gradle wrapper files are missing in your environment, create a fresh Flutter project and copy these files over it:

```bash
flutter create --platforms=android net_meter_flutter
# then copy this zip content over the generated project
flutter pub get
flutter run
```

## Permissions

Inside the app, tap:

1. **فعال‌سازی Usage Access** and enable this app.
2. Allow phone permission if Android asks, so the app can read active SIM/slot information.

`QUERY_ALL_PACKAGES` is included because app-wide per-package labels require seeing installed packages. This is fine for private/internal builds, but Google Play may require a policy justification.

## Main files

- `lib/main.dart` UI and orchestration
- `lib/services/native_traffic_service.dart` MethodChannel bridge
- `lib/services/pdf_report_service.dart` PDF generator
- `android/app/src/main/kotlin/ir/helssa/netmeter/MainActivity.kt` native traffic/SIM implementation
