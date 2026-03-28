# Mice Manager System Design Next Steps

## Implemented in this production batch

- Added central app configuration in `config.py`.
- Added OCR timeout controls so scan requests fail fast instead of hanging indefinitely.
- Added OCR runtime logging for easier diagnosis of slow scans and OCR engine selection.
- Simplified the scan autofill contract to the fields used most in the live workflow.
- Added parser tests for lab-specific raw OCR text.
- Added a lightweight verification script for core routes.

## Highest-priority next steps

1. Extract auth, mice, scan, analytics, and admin routes into separate modules.
2. Move scan and OCR code into a dedicated `services/scan_service.py`.
3. Add background jobs for expensive OCR tasks instead of processing everything in-request.
4. Add persistent structured logs and request timing metrics.
5. Add fixture-based OCR tests using real cage-card images.
6. Add PostgreSQL migration and production-grade deployment after the local workflow is stable.
