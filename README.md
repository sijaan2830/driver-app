# DC Driver — DryClean Plus driver app

Flutter app for Android and iOS. Drivers see today's route, drive to customers with live
location sharing, scan bag tags, take a doorstep photo / signature and finish each job.

Firebase project: `dryclean-flutter-app` (Android `com.drycleanplus.dc_driver`, iOS `com.drycleanplus.dcDriver`).

## Run

```bash
flutter pub get
flutter run            # Android phone/emulator
```

iOS builds need a Mac or Codemagic (same as the customer app). Minimum iOS 15, Android 7 (API 24).

**Demo mode** — tap *Try demo mode* on the login screen. Six realistic London jobs, the van drives
itself towards the stop, nothing is saved to Firebase.

## Real mode — what must exist

| What | Where | Notes |
|---|---|---|
| Driver login | Firebase Auth (email + password) | Created by an admin. |
| Driver profile | `drivers/{uid}` → `name`, `phone`, `vehicle {make, colour, reg}` | Without this doc the app refuses to sign in. |
| Jobs | `jobs/{jobId}` with `driverId` = driver uid and `date` = `yyyy-MM-dd` (today) | Created by dispatch in the admin panel. Fields: `orderId`, `orderDocId`, `type` (`pickup`/`delivery`), `status` (`assigned`), `sequence`, `slot`, `customerName`, `customerUid`, `phone`, `address {line1, line2, city, postalCode}`, optional `geo {lat, lng}`, `notes`, `handoff`, `items [{name, qty}]`, `bags`, `amountDue`, `paymentMethod`. |

## What the app writes (real time)

| Action | Writes |
|---|---|
| Go online / offline | `drivers/{uid}.isOnline`, `driver_locations/{uid}` |
| GPS (every 5 s on a trip, 60 s otherwise) | `driver_locations/{uid}` (fleet map) and `live_tracking/{orderId}` (customer's live map: `lat`, `lng`, `heading`, `etaMinutes`, `distanceMeters`) |
| Start trip | job `en_route`, order `pickup_en_route` / `out_for_delivery`, `orders/{id}/history` |
| Arrived (auto within 100 m, or tap) | job `arrived`, order `pickup_arrived` / `delivery_arrived` |
| Collected / Delivered | job `completed` + `pod` (photo, signature in Storage `pod/…`), order `collected` / `delivered`, `bags/{tag}`; `live_tracking/{orderId}` deleted |
| Can't complete | job `failed` + reason, order `pickup_failed` / `delivery_failed` |

Maps use OpenStreetMap (`flutter_map`) — no API key. Turn-by-turn opens Google Maps.

> Firestore security rules must allow drivers to do the writes above (see `SYSTEM_PLAN.md` §11 in the website repo).
