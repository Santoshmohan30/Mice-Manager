# Food Restriction And Weight Tracking

This module extends the existing Flutter app without replacing the current mice, breeding, OCR, sync, or auth flows.

## What Was Added

- experiment-level food restriction pages
- tracked mice inside each experiment
- editable daily weight and food entries
- automatic baseline, percent-of-original, and percent-change calculations
- duplicate daily-entry protection per mouse and date
- threshold visualization for 90%, 85%, 80%, and 75%
- CSV export for:
  - one experiment
  - one tracked mouse
  - all food restriction data

## Storage

SQLite schema version moved to `7`.

New tables:

- `food_restriction_experiments`
- `food_restriction_mice`
- `food_restriction_entries`

There is also a unique index on `(experiment_mouse_id, entry_date)` to prevent duplicate day entries for the same mouse.

## Calculation Rules

- the first recorded weight entry for a tracked mouse is treated as the 100% baseline
- editing the first entry updates the baseline value used across the full history
- percent of original:
  - `(current weight / first recorded weight) * 100`
- percent change:
  - `((current weight - previous weight) / previous weight) * 100`

## UI Flow

1. Open the Food Restriction tab
2. Create an experiment
3. Add tracked mice to that experiment
4. Open a tracked mouse
5. Add daily entries
6. Review the chart, thresholds, and history table
7. Export CSV when needed

## Backward Compatibility

- existing app modules remain unchanged in behavior
- existing mice records are not rewritten
- this feature uses its own SQLite tables so it can evolve safely
