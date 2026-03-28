# Mice Manager Cross-Platform Architecture

## Architecture decision

Mice Manager now follows a practical offline-first split:

- Flutter is the shared application layer for macOS and Android
- macOS is the local desktop hub
- Android is the primary field device
- SQLite stays local on each device
- repositories and services isolate business logic from storage
- OCR and sync are treated as adapters and services, not mixed directly into UI

This keeps the app usable without cloud dependency while still leaving room for a stronger sync layer later.

## What is already in place

The current implementation now includes:

1. local SQLite persistence on Android
2. macOS and Android build targets
3. owner-protected role model
4. mice management with `LAF` / `LAB`
5. breeding and procedures
6. date-based task tracking and weaning workflow support
7. offline OCR intake on Android
8. OCR history with archive and restore
9. local export/import sync bundles
10. same-Wi-Fi QR-driven Mac hub import flow

## Shared model design

The Flutter app includes shared domain models for:

- `Mouse`
- `Breeding`
- `Procedure`
- `UserAccount`
- `Role`
- `OCRDocument`
- `SyncPackage`
- `UpdateManifest`
- `DeviceTrust`
- `HousingType`
- `CalendarTask`

## Owner-protected auth design

The current role model keeps `OWNER` separate from `ADMIN`.

Key rules:

- `OWNER` cannot be silently replaced by an admin
- `isOwner` and `isProtected` are explicit in the user model
- local session state is stored separately from account records
- owner-level actions are intentionally narrower and more protected than admin actions

The recovery flow is still not final. That should be treated as security-sensitive future work, not rushed UI.

## Housing design

`housing_type` is required on each mouse and currently supports:

- `LAF`
- `LAB`

This is intentionally designed to extend later into:

- room
- rack
- cage zone
- facility location

## Sync design

The current sync architecture is local-first, not cloud-first:

- phones collect and use data locally
- the Mac app acts as a trusted hub
- data can move through export/import bundles
- same-Wi-Fi QR pairing allows a phone to import from the Mac hub over LAN

This is appropriate for a small lab starting point. The next major system-design upgrade is conflict-safe multi-user sync for several active devices.

## Current source location

See:

- `/Users/sonny03/Documents/MiceManager/apps/mice_manager_flutter`
