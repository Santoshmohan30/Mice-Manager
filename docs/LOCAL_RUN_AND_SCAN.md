# Local Run And Scan

## Start Without Re-Typing Commands

Double-click this file in Finder:

- `/Users/sonny03/Documents/MiceManager/Start Mice Manager.command`

It starts the Flask server in the background and prints both URLs:

- laptop: `http://127.0.0.1:8000`
- phone: `http://<your-wifi-ip>:8000`

By default it keeps the app up for `6 hours`, then stops it automatically.

If the IP changes after reconnecting to Wi-Fi, run the same file again and use the new phone URL it prints.

## Stop The Local Server

From Terminal:

```bash
cd /Users/sonny03/Documents/MiceManager
./tools/stop_local_server.sh
```

## OCR Cage Card Flow

The Android app scan flow is designed for:

- scan a cage card photo
- extract likely fields
- review the extracted values
- save as a new mouse or update an existing mouse
- scan a cage card and archive a matching mouse by cage

Accuracy is best when cage cards use:

- printed text instead of handwriting
- clear labels like `CAGE`, `DOB`, `SEX`, `GENOTYPE`, `RACK`, `PROJECT`
- one card centered in the photo

OCR is a speed tool, not a blind auto-save tool. Always review the extracted fields before saving or archiving.
