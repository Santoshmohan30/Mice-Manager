import os
from datetime import timedelta


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "mice-secret-key")
    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///mice.db").replace("postgres://", "postgresql://", 1)
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"
    SESSION_COOKIE_SECURE = False
    PERMANENT_SESSION_LIFETIME = timedelta(hours=8)

    DEFAULT_ROOM = os.environ.get("DEFAULT_ROOM", "B2126 JSMBS")
    DEFAULT_PROTOCOL_NUMBER = os.environ.get("DEFAULT_PROTOCOL_NUMBER", "202300048")
    DEFAULT_OWNER_PI = os.environ.get("DEFAULT_OWNER_PI", "Dheeraj, Roy")

    OCR_TIMEOUT_SECONDS = int(os.environ.get("OCR_TIMEOUT_SECONDS", "8"))
    OCR_COMPILE_TIMEOUT_SECONDS = int(os.environ.get("OCR_COMPILE_TIMEOUT_SECONDS", "12"))
    IMAGE_CONVERT_TIMEOUT_SECONDS = int(os.environ.get("IMAGE_CONVERT_TIMEOUT_SECONDS", "6"))
    OCR_MAX_DIMENSION = int(os.environ.get("OCR_MAX_DIMENSION", "1800"))
    OCR_MIN_TARGET_DIMENSION = int(os.environ.get("OCR_MIN_TARGET_DIMENSION", "1400"))

    LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
