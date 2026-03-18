# Mice Manager Android App

This is an initial Android client scaffold for the Flask backend in this repository.

What it does now:
- Signs in against `/api/login`
- Loads `/api/dashboard`
- Lists mice from `/api/mice`

Important connection note:
- Android emulator should use `http://10.0.2.2:5000`
- A real phone cannot use `localhost` for your laptop's Flask server
- On a real phone, replace the base URL in `MobileRepository` with your computer's LAN IP, for example `http://192.168.1.25:5000`

Next mobile steps:
- Add editable mouse forms that call `PUT /api/mice/<id>`
- Add breeding and calendar screens
- Add token persistence with encrypted storage
