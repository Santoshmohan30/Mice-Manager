# Render Deploy

This repository is configured for a free Render web service.

Important:

- Render free web services are fine for testing and preview use
- Render's own documentation says free services should not be used for production
- free services spin down after 15 minutes of inactivity

Official docs:

- [Render free deploy docs](https://render.com/docs/free)

## Files added for deployment

- `render.yaml`
- `wsgi.py`
- `requirements.txt` includes `gunicorn`

## How to deploy

1. Push this repository to GitHub
2. Log in to Render
3. Click `New`
4. Choose `Blueprint`
5. Select this GitHub repository
6. Render will read `render.yaml`
7. Approve the deploy

## Environment

The app uses:

- `SECRET_KEY`
- `DATABASE_URL` for PostgreSQL-backed deployment

Render will generate this automatically from `render.yaml`.

## Notes

- For real hosted use, set `DATABASE_URL` to a PostgreSQL database
- The app supports SQLite locally and PostgreSQL in hosted environments
- free Render service plus free database is acceptable for testing, not serious production

## Start command

Render runs:

```bash
gunicorn wsgi:application
```
