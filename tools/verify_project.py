import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app import app


def main():
    client = app.test_client()
    checks = []
    for route in ["/health", "/ready", "/login", "/dashboard", "/mice", "/analytics", "/scan-cage-card"]:
        response = client.get(route, follow_redirects=True)
        checks.append((route, response.status_code))

    failed = [route for route, status in checks if status != 200]
    for route, status in checks:
        print(f"{route}: {status}")

    if failed:
        raise SystemExit(f"Verification failed for: {', '.join(failed)}")
    print("Verification passed.")


if __name__ == "__main__":
    main()
