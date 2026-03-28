# Mice Manager System Design Next Steps

## What is done already

The project is no longer at the rough prototype stage.

The current repo now includes:

- central app configuration in `config.py`
- scan and OCR service extraction in `services/scan_service.py`
- OCR timeout handling and runtime logging
- parser tests for lab-specific OCR text
- route verification tooling
- health and readiness routes
- a Flutter macOS and Android application path
- local SQLite-backed offline mobile workflows
- local roles, session handling, and protected owner model
- local export/import sync bundle support
- same-Wi-Fi Mac hub import flow

## What still matters most

The next architecture work should focus on the things that increase trust, reliability, and team use.

1. Finish conflict-safe sync for multi-device lab use.
2. Add stronger merge rules so multiple people do not overwrite each other silently.
3. Expand fixture-based OCR tests using real cage-card photos from the lab.
4. Improve macOS hub management for trusted devices and sync review.
5. Add a secure owner recovery flow instead of placeholder recovery design.
6. Move more Flask route groups into cleaner modules where still needed.
7. Add richer request timing, structured logs, and failure diagnostics.
8. Add PostgreSQL-backed deployment when the local workflow is considered stable enough for shared hosted use.

## Practical next milestone

The strongest next milestone is:

- Mac hub as the trusted source
- Android devices as offline-first clients
- reviewed sync for a small lab team
- safer multi-user behavior for 3 or more people

That is the point where Mice Manager moves from a strong personal build into a genuinely team-ready local system.
