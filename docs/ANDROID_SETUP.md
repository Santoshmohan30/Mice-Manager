# Android App Setup

This project now includes a starter Android app in `android-app/`.

## What the Android app does now

- Shows a login screen
- Calls the Flask API at `/api/login`
- Loads dashboard summary data from `/api/dashboard`
- Loads mouse records from `/api/mice`

## What you need to install

1. Android Studio
2. Java 17 if Android Studio does not install it for you

## How to open the app

1. Open Android Studio
2. Choose **Open**
3. Select the folder `android-app`
4. Wait for Gradle sync to finish

## How to run the backend first

In the main project folder:

```bash
source venv/bin/activate
python app.py
```

The Flask app should run at:

`http://127.0.0.1:5000`

## Important note about localhost

This is very important:

- `localhost` inside Android emulator means the emulator itself
- `localhost` on a real phone means the phone itself
- It does **not** mean your laptop

Use this instead:

- Android emulator: `http://10.0.2.2:5000`
- Real phone on same Wi-Fi: `http://YOUR-COMPUTER-IP:5000`

The current Android app uses:

`http://10.0.2.2:5000`

inside:

`android-app/app/src/main/java/com/sonny03/micemanager/MainActivity.kt`

If you want to use a real phone, change the base URL in `MobileRepository`.

## How to run the Android app

1. Start the Flask backend
2. In Android Studio, create or start an emulator
3. Press **Run**
4. Log in with:
   - Username: `admin`
   - Password: `ChangeMe123!`

## What to build next

These are the next Android improvements:

1. Add create/edit mouse forms
2. Add breeding screen
3. Add calendar screen
4. Store login token safely
5. Add offline sync and retry logic

## Cost

This part can be free:

- Flask
- SQLite
- PostgreSQL
- Android Studio
- Local testing
- GitHub free tier

The only common future cost is Google Play publishing, which is optional.
