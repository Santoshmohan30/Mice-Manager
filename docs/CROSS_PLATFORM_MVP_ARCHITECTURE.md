# Mice Manager Cross-Platform MVP Architecture

## A. Architecture decision

- Use Flutter as the shared application shell for macOS and Android.
- Keep SQLite local on each device in v1.
- Use repository pattern and service layer.
- Treat OCR and updater logic as platform adapters.
- Make macOS the control hub and Android the main operational device.
- Keep sync cloud-free in v1 with local JSON sync bundles and local/LAN manifests.

## B. Smallest safe MVP

1. Owner-protected login shell
2. Mouse CRUD with `housing_type` required (`LAF` / `LAB`)
3. Lifecycle fields:
   - `is_alive`
   - `status`
   - `date_of_death`
   - `death_reason`
4. Local SQLite repository layer
5. Offline OCR abstraction with TODO adapters
6. Sync/update abstraction with explicit Android confirmation policy

## C. Shared folder structure

See `apps/mice_manager_flutter/`.

## D. Shared model design

Phase 1 includes:

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

## E. Owner-protected auth design

- `OWNER` is separate from `ADMIN`
- `isOwner` and `isProtected` are explicit
- only `OWNER` can control owner-level settings, promotions, demotions, password policy, trusted sync sources, and recovery
- owner recovery uses a TODO placeholder in Phase 1 and must be implemented securely in Phase 2

## F. LAF/LAB housing design

- `housing_type` is a required field on `Mouse`
- values are constrained by enum:
  - `laf`
  - `lab`
- designed to extend later into:
  - room
  - rack
  - cage zone
  - facility location
