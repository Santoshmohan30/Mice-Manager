# Private Free Deployment

This is the best free path if you want to keep the application private and avoid paid hosting.

## Recommended free deployment model

Use one always-on lab computer or one personal computer as the private server.

That machine will run:

- Flask app
- SQLite database
- local backups

Only people you trust should access it through:

- same Wi-Fi network
- VPN
- remote desktop into the host machine

## Why this is the best free option

It is:

- free
- private
- simple
- under your control

It avoids:

- cloud costs
- public internet exposure
- paid database hosting
- public Play Store publishing pressure

## What to do

1. Keep the app on one host machine
2. Create regular backups from the Recovery page
3. Also run:

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
python tools/create_backup.py
```

4. Copy backup files outside the project folder
5. Give lab users accounts from the Users page
6. Use the Android app by pointing it to the host machine IP address on the same Wi-Fi

## Host machine setup

Run the app:

```bash
cd /Users/sonny03/Documents/MiceManager
source venv/bin/activate
python app.py
```

Then other devices on the same network should use the host machine LAN IP, for example:

`http://192.168.1.25:5000`

## Important privacy note

Do not expose this app directly to the public internet without:

- HTTPS
- stronger secrets
- production server
- PostgreSQL
- monitoring
- hardened auth

For now, keep it private on your internal network.

## Free Android distribution

If you do not want to pay Google Play's one-time fee yet:

- build the APK in Android Studio
- install it directly on your phone
- or use private internal testing later when ready

That is the lowest-cost path today.

## Best next upgrade when money becomes available

1. Move database to PostgreSQL
2. Add HTTPS reverse proxy
3. Move backups off-device automatically
4. Add production monitoring
