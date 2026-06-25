# Android Network Meter

Flutter + native Android app for monitoring **mobile/SIM internet only**. Wi‑Fi traffic is intentionally excluded from reports.

## Features

- Persian / RTL Material 3 UI.
- Live mobile data speed updated every second:
  - download speed
  - upload speed
  - total speed
  - active network detection so Wi‑Fi/inactive cellular is explained clearly.
- Active data SIM information where Android allows it:
  - SIM slot index
  - carrier/display name
  - subscription ID
  - dual-SIM friendly display.
- Mobile-only usage reports powered by Android `NetworkStatsManager`:
  - queries `ConnectivityManager.TYPE_MOBILE`
  - total download/upload/combined usage
  - per-app mobile usage sorted by highest usage
  - app name, package name, download, upload, total
  - search/filter by app name or package.
- Time ranges:
  - 1 hour, 6 hours, 24 hours, 7 days, 30 days
  - custom date range
  - selectable chart bucket count/resolution.
- Charts with `fl_chart` for mobile usage trends.
- PDF export with `pdf` and `printing`, including range, active SIM, totals, top apps, selected app, and timeline summaries.
- Friendly loading, empty, permission, and error states.

## Android limitations

Android does **not** reliably expose historical per-SIM traffic to normal apps on modern releases. This app therefore:

- shows the **current active data SIM** using native subscription APIs when available;
- queries historical traffic as **all mobile data combined** using `TYPE_MOBILE` and `subscriberId = null`;
- never fakes per-SIM historical usage;
- displays the limitation in the UI so users know that historical per-SIM separation may not be available.

If Wi‑Fi is the active network, live mobile speed can be zero or inactive even though the device has a SIM.

## Required permissions

- `PACKAGE_USAGE_STATS` / Usage Access: required for per-app mobile usage from `NetworkStatsManager`.
- `READ_PHONE_STATE`: requested only when SIM details are needed and Android requires it.
- `ACCESS_NETWORK_STATE`: active network transport detection.
- `QUERY_ALL_PACKAGES`: helps resolve package names and labels for per-app usage. Google Play heavily restricts this permission; production Play releases may need a policy-compliant alternative or justification.

The app handles denied permissions gracefully. Per-app usage screens show: **Per-app mobile usage requires Usage Access.**

## How to run

```bash
flutter pub get
flutter run
```

Run quality checks:

```bash
flutter analyze
flutter test
```

## Troubleshooting

- **No per-app data:** open Usage Access settings from the app and enable access.
- **SIM name/slot missing:** Android version, device policy, or denied phone permission may restrict subscription details.
- **Report is empty:** choose a wider time range, verify mobile data was used, and confirm Usage Access is enabled.
- **Wi‑Fi appears active:** reports still exclude Wi‑Fi; live mobile speed can be zero while Wi‑Fi carries current traffic.
- **Google Play warning:** review `QUERY_ALL_PACKAGES` policy before publishing.

## Screenshots

Actual screenshots are not included in this repository yet. Suggested placeholders:

- Home dashboard with live speed and SIM card.
- Mobile usage report with totals.
- Per-app usage list and search.
- Timeline chart.
- PDF export preview.
