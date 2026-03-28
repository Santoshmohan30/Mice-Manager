import csv
import base64
import io
import json
import logging
import os
import re
import secrets
import sqlite3
import subprocess
import tempfile
from datetime import date, datetime, timedelta
from functools import wraps
from pathlib import Path

from sqlalchemy import inspect
from flask import (
    Flask,
    Response,
    flash,
    g,
    jsonify,
    redirect,
    render_template,
    request,
    send_file,
    session,
    url_for,
)
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from markupsafe import Markup
from PIL import Image, ImageFilter, ImageOps, ImageStat
from sqlalchemy.exc import OperationalError
from werkzeug.security import check_password_hash, generate_password_hash

from config import Config
from extensions import db, migrate
from routes import health_blueprint
from services import ScanService


app = Flask(__name__)
app.config.from_object(Config)

logging.basicConfig(
    level=getattr(logging, app.config["LOG_LEVEL"], logging.INFO),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

db.init_app(app)
migrate.init_app(app, db)
app.register_blueprint(health_blueprint)

from models import AuditLog, Breeding, CalendarEvent, CageTransfer, Mouse, Procedure, Pup, User, Weight

DEFAULT_ROOM = app.config["DEFAULT_ROOM"]
DEFAULT_PROTOCOL_NUMBER = app.config["DEFAULT_PROTOCOL_NUMBER"]
DEFAULT_OWNER_PI = app.config["DEFAULT_OWNER_PI"]

STRAIN_ALIASES = {
    "CALB1": "Calb1-IRES-Cre",
    "CALBI": "Calb1-IRES-Cre",
    "CALV1": "Calb1-IRES-Cre",
    "CALV": "Calb1-IRES-Cre",
    "CALB": "Calb1-IRES-Cre",
    "IRSCRE": "Calb1-IRES-Cre",
    "IRESCRE": "Calb1-IRES-Cre",
    "C1QL2": "C1ql2-RES-Cre",
    "CIQL2": "C1ql2-RES-Cre",
    "C1QL": "C1ql2-RES-Cre",
    "TNNT1": "Tnnt1-IRES-CreERT2",
    "TNNT": "Tnnt1-IRES-CreERT2",
    "TNT": "Tnnt1-IRES-CreERT2",
    "CREERT2": "Tnnt1-IRES-CreERT2",
    "NPSR1": "Npsr1-IRES-Flp",
    "NPSR": "Npsr1-IRES-Flp",
    "FLP": "Npsr1-IRES-Flp",
    "C57/BL": "C57/BL",
    "C57BL": "C57/BL",
    "C57 BL": "C57/BL",
    "C57BL6": "C57/BL",
    "C57 BL6": "C57/BL",
}


def token_serializer():
    return URLSafeTimedSerializer(app.config["SECRET_KEY"], salt="mice-manager-api")


def password_policy_errors(password, username=""):
    issues = []
    if len(password) < 10:
        issues.append("Password must be at least 10 characters.")
    if password.lower() == password:
        issues.append("Password must include at least one uppercase letter.")
    if password.upper() == password:
        issues.append("Password must include at least one lowercase letter.")
    if not any(char.isdigit() for char in password):
        issues.append("Password must include at least one number.")
    if all(char.isalnum() for char in password):
        issues.append("Password must include at least one special character.")
    if username and username.lower() in password.lower():
        issues.append("Password should not contain the username.")
    return issues


def is_safe_redirect_target(target):
    return bool(target) and target.startswith("/") and not target.startswith("//")


def csrf_token():
    token = session.get("_csrf_token")
    if not token:
        token = secrets.token_urlsafe(32)
        session["_csrf_token"] = token
    return token


def csrf_input():
    return Markup(f'<input type="hidden" name="_csrf_token" value="{csrf_token()}">')


def inject_now():
    return {"now": datetime.now, "csrf_input": csrf_input, "display_date_us": display_date_us}


app.context_processor(inject_now)


def parse_iso_date(value):
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d").date()
    except ValueError:
        return None


def normalize_label(value):
    return " ".join((value or "").strip().upper().replace("-", " ").split())


def display_group_label(raw_value):
    cleaned = " ".join((raw_value or "").strip().split())
    return cleaned or "Unknown"


CANONICAL_LABELS = {
    "C1QL2 RES CRE": "C1ql2-RES-Cre",
    "CALB1 IRES CRE": "Calb1-IRES-Cre",
    "NPSR1 IRES FLP": "Npsr1-IRES-Flp",
    "TNNT1 IRES CREERT2": "Tnnt1-IRES-CreERT2",
    "C57 BL": "C57/BL",
    "AAV": "AAV",
    "AAV GCAMP": "AAV-GCaMP",
    "AAV GPMCA2": "AAV-GPMCA2",
    "AAV MIX G2 1": "AAV-MIX-G2-1",
    "AAV MIX G2 2": "AAV-MIX-G2-2",
    "AAV MIX G2 3": "AAV-MIX-G2-3",
    "DOUBLE IMPLANT": "DOUBLE IMPLANT",
    "DOUBLEIMPLANT": "DOUBLE IMPLANT",
    "EEG IMPLANT": "EEG-IMPLANT",
    "IMPLANT": "IMPLANT",
}


def infer_group_type_from_label(raw_value):
    label = normalize_label(raw_value)
    procedure_keywords = ["AAV", "IMPLANT", "EEG", "SURGERY", "INJECTION", "INJECT", "VIRUS"]
    if any(keyword in label for keyword in procedure_keywords):
        return "procedure_cohort"
    return "genetic_strain"


def canonical_mouse_label(raw_value, group_type=None):
    normalized = normalize_label(raw_value)
    if normalized in CANONICAL_LABELS:
        return CANONICAL_LABELS[normalized]

    effective_group_type = group_type or infer_group_type_from_label(raw_value)
    if effective_group_type == "procedure_cohort":
        return normalized.replace(" ", "-")
    return display_group_label(raw_value)


def classify_mouse_group(mouse):
    return mouse.group_type or infer_group_type_from_label(mouse.strain)


def today_iso():
    return date.today().isoformat()


def is_sqlite_backend():
    return app.config["SQLALCHEMY_DATABASE_URI"].startswith("sqlite:")


def database_file():
    if not is_sqlite_backend():
        raise RuntimeError("database_file() is only available for SQLite backends")
    return Path(app.instance_path) / "mice.db"


def backup_directory():
    directory = Path(app.root_path) / "backups"
    directory.mkdir(exist_ok=True)
    return directory


def safe_backup_label(label):
    cleaned = "".join(char if char.isalnum() or char in {"-", "_"} else "-" for char in (label or "manual"))
    return cleaned.strip("-") or "manual"


def create_database_backup(label="manual"):
    if not is_sqlite_backend():
        raise RuntimeError("Automatic in-app backup is only supported for SQLite.")
    source = database_file()
    if not source.exists():
        raise FileNotFoundError(f"Database not found at {source}")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    filename = f"{timestamp}-{safe_backup_label(label)}.db"
    destination = backup_directory() / filename

    with sqlite3.connect(source) as source_connection:
        with sqlite3.connect(destination) as backup_connection:
            source_connection.backup(backup_connection)

    return destination


def available_backups():
    backups = []
    for path in sorted(backup_directory().glob("*.db"), reverse=True):
        backups.append(
            {
                "name": path.name,
                "path": path,
                "size_kb": round(path.stat().st_size / 1024, 1),
                "modified_at": datetime.fromtimestamp(path.stat().st_mtime),
            }
        )
    return backups


def restore_database_from_backup(backup_name):
    if not is_sqlite_backend():
        raise RuntimeError("In-app restore is only supported for SQLite.")
    backup_path = backup_directory() / backup_name
    if not backup_path.exists():
        raise FileNotFoundError(f"Backup not found: {backup_name}")

    live_database = database_file()
    db.session.remove()
    db.engine.dispose()

    with sqlite3.connect(backup_path) as source_connection:
        with sqlite3.connect(live_database) as live_connection:
            source_connection.backup(live_connection)


def current_user():
    user_id = session.get("user_id")
    if not user_id:
        return None
    return db.session.get(User, user_id)


def parse_datetime(value):
    if not value:
        return None
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def active_mouse_query():
    return Mouse.query.filter(Mouse.is_active.is_(True))


def log_action(action, entity_type, entity_id, details=""):
    username = g.user.username if getattr(g, "user", None) else "system"
    db.session.add(
        AuditLog(
            created_at=datetime.now().isoformat(timespec="seconds"),
            username=username,
            action=action,
            entity_type=entity_type,
            entity_id=str(entity_id),
            details=details or "",
        )
    )


def table_columns(table_name):
    return {column["name"] for column in inspect(db.engine).get_columns(table_name)}


def ensure_user_schema():
    def safe_add_column(connection, statement):
        try:
            connection.exec_driver_sql(statement)
        except OperationalError as error:
            message = str(error).lower()
            if "duplicate column name" not in message and "already exists" not in message and "duplicate_column" not in message:
                raise

    with db.engine.begin() as connection:
        columns = table_columns("user")
        if "must_change_password" not in columns:
            safe_add_column(connection, 'ALTER TABLE "user" ADD COLUMN must_change_password BOOLEAN')
            connection.exec_driver_sql("UPDATE user SET must_change_password = 0 WHERE must_change_password IS NULL")
        if "failed_login_attempts" not in columns:
            safe_add_column(connection, 'ALTER TABLE "user" ADD COLUMN failed_login_attempts INTEGER')
            connection.exec_driver_sql("UPDATE user SET failed_login_attempts = 0 WHERE failed_login_attempts IS NULL")
        if "locked_until" not in columns:
            safe_add_column(connection, 'ALTER TABLE "user" ADD COLUMN locked_until VARCHAR(30)')
        if "last_login_at" not in columns:
            safe_add_column(connection, 'ALTER TABLE "user" ADD COLUMN last_login_at VARCHAR(30)')


@app.before_request
def load_current_user():
    session.permanent = True
    g.user = current_user()


@app.before_request
def enforce_password_change():
    if g.get("user") is None:
        return None
    exempt_endpoints = {"change_password", "logout", "static"}
    if g.user.must_change_password and request.endpoint not in exempt_endpoints and not request.path.startswith("/api/"):
        flash("Please update your password to continue.", "warning")
        return redirect(url_for("change_password"))


@app.before_request
def validate_csrf():
    if request.method != "POST":
        return None
    if request.path.startswith("/api/"):
        return None
    token = session.get("_csrf_token")
    submitted = request.form.get("_csrf_token")
    if not token or token != submitted:
        flash("Your session form token expired. Please try again.", "danger")
        return redirect(request.referrer or url_for("login"))


@app.after_request
def add_security_headers(response):
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Cache-Control"] = "no-store"
    return response


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if g.user is None:
            flash("Please sign in to continue.", "warning")
            return redirect(url_for("login", next=request.path))
        return view(*args, **kwargs)

    return wrapped_view


def role_required(*roles):
    def decorator(view):
        @wraps(view)
        def wrapped_view(*args, **kwargs):
            if g.user is None:
                flash("Please sign in to continue.", "warning")
                return redirect(url_for("login", next=request.path))
            if g.user.role not in roles:
                flash("You do not have permission for that action.", "danger")
                return redirect(url_for("dashboard"))
            return view(*args, **kwargs)

        return wrapped_view

    return decorator


def login_locked(user):
    lock_until = parse_datetime(user.locked_until)
    return bool(lock_until and lock_until > datetime.now())


def register_failed_login(user):
    user.failed_login_attempts = (user.failed_login_attempts or 0) + 1
    if user.failed_login_attempts >= 5:
        user.locked_until = (datetime.now() + timedelta(minutes=15)).isoformat(timespec="seconds")
        user.failed_login_attempts = 0


def register_successful_login(user):
    user.failed_login_attempts = 0
    user.locked_until = None
    user.last_login_at = datetime.now().isoformat(timespec="seconds")


def api_user():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return None

    token = auth_header.removeprefix("Bearer ").strip()
    if not token:
        return None

    try:
        payload = token_serializer().loads(token, max_age=60 * 60 * 24 * 7)
    except (BadSignature, SignatureExpired):
        return None

    user_id = payload.get("user_id")
    return db.session.get(User, user_id)


def api_login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        user = api_user()
        if user is None:
            return jsonify({"error": "Authentication required"}), 401
        g.api_user = user
        return view(*args, **kwargs)

    return wrapped_view


def serialize_mouse(mouse):
    return {
        "id": mouse.id,
        "strain": mouse.strain,
        "group_type": classify_mouse_group(mouse),
        "gender": mouse.gender,
        "genotype": mouse.genotype,
        "dob": mouse.dob,
        "cage": mouse.cage,
        "rack_location": mouse.rack_location or "",
        "notes": mouse.notes or "",
        "training": bool(mouse.training),
        "project": mouse.project or "",
        "owner_pi": mouse.owner_pi or "",
        "protocol_number": mouse.protocol_number or "",
        "animal_count": mouse.animal_count if mouse.animal_count is not None else "",
        "received_date": mouse.received_date or "",
        "vendor": mouse.vendor or "",
        "age": mouse.age or "",
        "weight": mouse.weight or "",
        "species": mouse.species or "",
        "room": mouse.room or "",
        "requisition_number": mouse.requisition_number or "",
        "cost_center": mouse.cost_center or "",
        "is_active": bool(mouse.is_active),
        "deleted_at": mouse.deleted_at or "",
    }


def serialize_breeding(record):
    return {
        "id": record.id,
        "male_id": record.male_id,
        "female_id": record.female_id,
        "pair_date": record.pair_date,
        "litter_count": record.litter_count,
        "litter_date": record.litter_date,
        "wean_date": record.wean_date,
        "status": record.status,
        "weaning_date": record.weaning_date,
        "notes": record.notes or "",
    }


def mouse_choices():
    mice = active_mouse_query().order_by(Mouse.id.asc()).all()
    return mice


def mouse_label_options():
    return {
        "genetic_strain": ["C1ql2-RES-Cre", "Calb1-IRES-Cre", "Npsr1-IRES-Flp", "Tnnt1-IRES-CreERT2", "C57/BL"],
        "procedure_cohort": ["AAV", "AAV-GCaMP", "AAV-GPMCA2", "AAV-MIX-G2-1", "AAV-MIX-G2-2", "AAV-MIX-G2-3", "DOUBLE IMPLANT", "EEG-IMPLANT", "IMPLANT"],
    }


def calculate_age_from_dob(dob_value):
    normalized = normalize_date(dob_value)
    if not normalized:
        return ""
    try:
        born = datetime.strptime(normalized, "%Y-%m-%d").date()
    except ValueError:
        return ""
    delta_days = max(0, (date.today() - born).days)
    if delta_days == 1:
        return "1 day"
    return f"{delta_days} days"


def display_date_us(value):
    normalized = normalize_date(value)
    if not normalized:
        return normalize_text_value(value)
    try:
        parsed = datetime.strptime(normalized, "%Y-%m-%d")
    except ValueError:
        return normalized
    return parsed.strftime("%m/%d/%Y")


_scan_service = None


def get_scan_service():
    global _scan_service
    if _scan_service is None:
        _scan_service = ScanService(
            config=app.config,
            logger=app.logger,
            mouse_label_options=mouse_label_options,
            canonical_mouse_label=canonical_mouse_label,
            infer_group_type_from_label=infer_group_type_from_label,
            normalize_date=normalize_date,
            normalize_gender=normalize_gender,
            normalize_species=normalize_species,
            normalize_text_value=normalize_text_value,
            calculate_age_from_dob=calculate_age_from_dob,
            display_date_us=display_date_us,
            defaults={
                "room": DEFAULT_ROOM,
                "protocol_number": DEFAULT_PROTOCOL_NUMBER,
                "owner_pi": DEFAULT_OWNER_PI,
            },
            strain_aliases=STRAIN_ALIASES,
        )
    return _scan_service


def apply_mouse_form(mouse, form):
    mouse.group_type = infer_group_type_from_label(form["strain"])
    mouse.strain = canonical_mouse_label(form["strain"].strip(), mouse.group_type)
    mouse.gender = normalize_gender(form.get("gender", ""))
    mouse.genotype = form.get("genotype", "").strip()
    mouse.dob = normalize_date(form.get("dob", ""))
    mouse.cage = normalize_text_value(form.get("cage", ""))
    mouse.rack_location = form.get("rack_location", "").strip()
    mouse.notes = form.get("notes", "").strip()
    mouse.training = form.get("training") in {"on", "true", "True", True}
    mouse.project = form.get("project", "").strip()
    mouse.owner_pi = form.get("owner_pi", "").strip()
    mouse.protocol_number = DEFAULT_PROTOCOL_NUMBER
    animal_count = form.get("animal_count", "").strip()
    mouse.animal_count = int(animal_count) if animal_count.isdigit() else None
    mouse.received_date = normalize_date(form.get("received_date", ""))
    mouse.vendor = None
    mouse.age = calculate_age_from_dob(mouse.dob)
    mouse.weight = None
    mouse.species = normalize_species(form.get("species", "")) or "Mouse"
    mouse.room = DEFAULT_ROOM
    mouse.requisition_number = normalize_text_value(form.get("requisition_number", ""))
    mouse.cost_center = normalize_text_value(form.get("cost_center", ""))


def normalize_text_value(value):
    return re.sub(r"\s+", " ", (value or "").strip()).strip(" ,.:;|-")


def normalize_gender(value):
    cleaned = normalize_label(value)
    if cleaned in {"M", "MALE"}:
        return "MALE"
    if cleaned in {"F", "FEMALE"}:
        return "FEMALE"
    return "UNKNOWN" if cleaned else ""


def normalize_species(value):
    cleaned = normalize_label(value).replace(" ", "")
    if cleaned in {"MOUSE", "VMOUSE", "VMIOUSE"}:
        return "Mouse"
    return normalize_text_value(value)


def normalize_boolean(value):
    cleaned = normalize_label(value)
    if cleaned in {"YES", "Y", "TRUE", "1", "TRAINING"}:
        return True
    if cleaned in {"NO", "N", "FALSE", "0"}:
        return False
    return None


def normalize_date(value):
    raw = normalize_text_value(value)
    if not raw:
        return ""
    patterns = [
        "%Y-%m-%d",
        "%m/%d/%Y",
        "%m/%d/%y",
        "%m-%d-%Y",
        "%m-%d-%y",
    ]
    for pattern in patterns:
        try:
            return datetime.strptime(raw, pattern).date().isoformat()
        except ValueError:
            continue
    return ""


SCAN_FIELD_SPECS = [
    ("strain", ["STRAIN"], "text"),
    ("gender", ["GENDER", "SEX"], "gender"),
    ("genotype", ["GENOTYPE", "GT"], "text"),
    ("dob", ["DOB", "DATE OF BIRTH", "BORN"], "date"),
    ("cage", ["CAGE", "CAGE NUMBER", "CAGE NO", "BOX"], "text"),
    ("rack_location", ["RACK", "RACK LOCATION"], "text"),
    ("owner_pi", ["OWNER", "PI", "LAB CONTACT", "INVESTIGATOR"], "text"),
    ("protocol_number", ["PROTOCOL", "PROTOCOL NUMBER", "IACUC"], "text"),
    ("age", ["AGE"], "text"),
    ("room", ["ROOM"], "text"),
    ("requisition_number", ["REQUISITION NUMBER", "REQUISITION"], "text"),
    ("notes", ["NOTES"], "text"),
]


def empty_scan_field():
    return {"value": "", "confidence": 0.0, "source": "none"}


def set_scan_field(fields, key, value, confidence, source):
    value = value if not isinstance(value, str) else normalize_text_value(value)
    if value in {None, ""}:
        return
    if confidence > fields[key]["confidence"]:
        fields[key] = {"value": value, "confidence": round(confidence, 2), "source": source}


def clean_ocr_text(text):
    return "\n".join(normalize_text_value(line) for line in (text or "").splitlines() if normalize_text_value(line))


def normalize_scan_value(field, value):
    raw = normalize_text_value(value)
    if not raw:
        return ""
    if field == "dob":
        return normalize_date(raw)
    if field == "gender":
        return normalize_gender(raw)
    if field == "strain":
        return canonical_mouse_label(raw)
    if field == "cage":
        return raw.replace(" ", "")
    return raw


def infer_known_strain_from_text(text):
    return get_scan_service().infer_known_strain_from_text(text)


def extract_label_value_pairs(lines):
    pairs = []
    normalized_labels = {}
    for field, labels, _kind in SCAN_FIELD_SPECS:
        for label in labels:
            normalized_labels[normalize_label(label)] = (field, label)

    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped:
            continue
        normalized_line = normalize_label(stripped)
        for normalized_label, (field, original_label) in sorted(normalized_labels.items(), key=lambda item: len(item[0]), reverse=True):
            if normalized_line.startswith(normalized_label):
                remainder = stripped[len(original_label):].strip(" :.-")
                if remainder:
                    pairs.append((field, remainder, index))
                    break
            if ":" in stripped:
                label_part, value_part = stripped.split(":", 1)
                if normalize_label(label_part) == normalized_label and value_part.strip():
                    pairs.append((field, value_part.strip(), index))
                    break
    return pairs


def infer_fields_from_text(text, source, base_confidence):
    fields = {field: empty_scan_field() for field, _labels, _kind in SCAN_FIELD_SPECS}
    cleaned_text = clean_ocr_text(text)
    lines = cleaned_text.splitlines()

    for field, value, _index in extract_label_value_pairs(lines):
        normalized_value = normalize_scan_value(field, value)
        confidence = base_confidence + 0.18
        if normalized_value:
            set_scan_field(fields, field, normalized_value, min(confidence, 0.98), f"{source}_label_match")

    full_text = cleaned_text.upper()
    for canonical in mouse_label_options()["genetic_strain"]:
        if normalize_label(canonical) in full_text:
            set_scan_field(fields, "strain", canonical, 0.96, "rule_match")
    for canonical in mouse_label_options()["procedure_cohort"]:
        if normalize_label(canonical) in full_text:
            set_scan_field(fields, "strain", canonical, 0.94, "rule_match")
    inferred_strain = infer_known_strain_from_text(cleaned_text)
    if inferred_strain:
        set_scan_field(fields, "strain", inferred_strain, 0.95, "alias_match")

    if re.search(r"\bMALE\b|\bSEX\s*[:\-]?\s*M\b|\bGENDER\s*[:\-]?\s*M\b", cleaned_text, flags=re.IGNORECASE):
        set_scan_field(fields, "gender", "MALE", 0.9, "rule_match")
    if re.search(r"\bFEMALE\b|\bSEX\s*[:\-]?\s*F\b|\bGENDER\s*[:\-]?\s*F\b", cleaned_text, flags=re.IGNORECASE):
        set_scan_field(fields, "gender", "FEMALE", 0.9, "rule_match")

    genotype_match = re.search(r"\b(?:GENOTYPE|GT)\s*[:\-]?\s*([A-Z0-9+/_. -]+)", cleaned_text, flags=re.IGNORECASE)
    if genotype_match:
        set_scan_field(fields, "genotype", genotype_match.group(1), 0.84, "rule_match")

    date_matches = re.findall(r"\b(?:\d{4}-\d{2}-\d{2}|\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\b", cleaned_text)
    if date_matches and not fields["dob"]["value"]:
        normalized_date = normalize_date(date_matches[0])
        if normalized_date:
            set_scan_field(fields, "dob", normalized_date, 0.72, "ocr")

    cc_cage_matches = re.findall(r"\bCC00[A-Z0-9-]*\d\b", cleaned_text, flags=re.IGNORECASE)
    if cc_cage_matches:
        set_scan_field(fields, "cage", cc_cage_matches[-1].upper(), 0.99, "lab_rule")

    cage_match = re.search(r"\b(?:CAGE(?: NUMBER| NO)?|BOX)\s*[:#\-]?\s*([A-Z0-9-]+)\b", cleaned_text, flags=re.IGNORECASE)
    if cage_match:
        set_scan_field(fields, "cage", cage_match.group(1), 0.88, "rule_match")

    rack_match = re.search(r"\bRACK(?: LOCATION)?\s*[:\-]?\s*([A-Z0-9- ]+)\b", cleaned_text, flags=re.IGNORECASE)
    if rack_match:
        set_scan_field(fields, "rack_location", rack_match.group(1), 0.84, "rule_match")

    owner_match = re.search(r"\b(?:LAB CONTACT|OWNER|PI)\s*[:\-]?\s*([A-Z ,.-]+)", cleaned_text, flags=re.IGNORECASE)
    if owner_match:
        set_scan_field(fields, "owner_pi", owner_match.group(1), 0.9, "label_match")
    elif re.search(r"\bDHEERAJ\b", cleaned_text, flags=re.IGNORECASE) and re.search(r"\bROY\b", cleaned_text, flags=re.IGNORECASE):
        set_scan_field(fields, "owner_pi", DEFAULT_OWNER_PI, 0.9, "rule_match")

    requisition_match = re.search(r"\b\d{6}\s+[A-Z]{2,5}\d{4,6}-\d+\b", cleaned_text, flags=re.IGNORECASE)
    if requisition_match:
        set_scan_field(fields, "requisition_number", requisition_match.group(0).upper(), 0.95, "rule_match")
    else:
        requisition_match = re.search(r"\b20\d{6,}\b", cleaned_text)
        if requisition_match:
            set_scan_field(fields, "requisition_number", requisition_match.group(0), 0.9, "rule_match")

    room_match = re.search(r"\bB2126\s+JSMBS\b", cleaned_text, flags=re.IGNORECASE)
    if room_match:
        set_scan_field(fields, "room", DEFAULT_ROOM, 0.99, "rule_match")

    return fields


def merge_scan_fields(*field_maps):
    merged = {field: empty_scan_field() for field, _labels, _kind in SCAN_FIELD_SPECS}
    for field_map in field_maps:
        for key, payload in field_map.items():
            if payload["confidence"] > merged[key]["confidence"]:
                merged[key] = payload
    if merged["gender"]["value"] not in {"MALE", "FEMALE", "UNKNOWN", ""}:
        merged["gender"] = empty_scan_field()
    return merged


def extract_cage_card_fields(raw_text, diagnostics=None):
    return get_scan_service().extract_cage_card_fields(raw_text, diagnostics=diagnostics)


def image_to_data_url(image, format_name="PNG"):
    return get_scan_service().image_to_data_url(image, format_name=format_name)


def analyze_image_quality(image):
    return get_scan_service().analyze_image_quality(image)


def preprocess_ocr_image(image):
    return get_scan_service().preprocess_ocr_image(image)


def score_ocr_text(text):
    return get_scan_service().score_ocr_text(text)


VISION_OCR_SCRIPT = Path(__file__).parent / "tools" / "vision_ocr.swift"
VISION_OCR_BINARY = Path(__file__).parent / "tools" / ".cache" / "vision_ocr"


def macos_sdk_path():
    return get_scan_service().macos_sdk_path()


def ensure_compiled_vision_ocr():
    return get_scan_service().ensure_compiled_vision_ocr()


def run_vision_ocr_on_image(path):
    return get_scan_service().run_vision_ocr_on_image(path)


def run_tesseract_on_image(path, psm_mode):
    return get_scan_service().run_tesseract_on_image(path, psm_mode)


def ocr_uploaded_image(file_storage):
    return get_scan_service().ocr_uploaded_image(file_storage)


def ensure_mouse_schema():
    def safe_add_column(connection, column_name, statement):
        try:
            connection.exec_driver_sql(statement)
        except OperationalError as error:
            message = str(error).lower()
            if "duplicate column name" not in message and "already exists" not in message and "duplicate_column" not in message:
                raise

    with db.engine.begin() as connection:
        columns = table_columns("mouse")
        if "rack_location" not in columns:
            safe_add_column(connection, "rack_location", "ALTER TABLE mouse ADD COLUMN rack_location VARCHAR(50)")
        if "group_type" not in columns:
            safe_add_column(connection, "group_type", "ALTER TABLE mouse ADD COLUMN group_type VARCHAR(30)")
        if "is_active" not in columns:
            safe_add_column(connection, "is_active", "ALTER TABLE mouse ADD COLUMN is_active BOOLEAN")
            connection.exec_driver_sql("UPDATE mouse SET is_active = 1 WHERE is_active IS NULL")
        if "deleted_at" not in columns:
            safe_add_column(connection, "deleted_at", "ALTER TABLE mouse ADD COLUMN deleted_at VARCHAR(30)")
        if "owner_pi" not in columns:
            safe_add_column(connection, "owner_pi", "ALTER TABLE mouse ADD COLUMN owner_pi VARCHAR(120)")
        if "protocol_number" not in columns:
            safe_add_column(connection, "protocol_number", "ALTER TABLE mouse ADD COLUMN protocol_number VARCHAR(60)")
        if "animal_count" not in columns:
            safe_add_column(connection, "animal_count", "ALTER TABLE mouse ADD COLUMN animal_count INTEGER")
        if "received_date" not in columns:
            safe_add_column(connection, "received_date", "ALTER TABLE mouse ADD COLUMN received_date VARCHAR(20)")
        if "vendor" not in columns:
            safe_add_column(connection, "vendor", "ALTER TABLE mouse ADD COLUMN vendor VARCHAR(120)")
        if "age" not in columns:
            safe_add_column(connection, "age", "ALTER TABLE mouse ADD COLUMN age VARCHAR(40)")
        if "weight" not in columns:
            safe_add_column(connection, "weight", "ALTER TABLE mouse ADD COLUMN weight VARCHAR(40)")
        if "species" not in columns:
            safe_add_column(connection, "species", "ALTER TABLE mouse ADD COLUMN species VARCHAR(40)")
        if "room" not in columns:
            safe_add_column(connection, "room", "ALTER TABLE mouse ADD COLUMN room VARCHAR(80)")
        if "requisition_number" not in columns:
            safe_add_column(connection, "requisition_number", "ALTER TABLE mouse ADD COLUMN requisition_number VARCHAR(60)")
        if "cost_center" not in columns:
            safe_add_column(connection, "cost_center", "ALTER TABLE mouse ADD COLUMN cost_center VARCHAR(80)")


def normalize_existing_mouse_data():
    changed = False
    for mouse in Mouse.query.all():
        inferred_group_type = mouse.group_type or infer_group_type_from_label(mouse.strain)
        canonical_label = canonical_mouse_label(mouse.strain, inferred_group_type)
        if mouse.is_active is None:
            mouse.is_active = True
            changed = True
        if mouse.group_type != inferred_group_type:
            mouse.group_type = inferred_group_type
            changed = True
        if mouse.strain != canonical_label:
            mouse.strain = canonical_label
            changed = True
    if changed:
        db.session.commit()


def ensure_default_admin():
    db.create_all()
    ensure_mouse_schema()
    ensure_user_schema()
    if User.query.count() == 0:
        default_password = os.environ.get("DEFAULT_ADMIN_PASSWORD", "ChangeMe123!")
        admin = User(
            username=os.environ.get("DEFAULT_ADMIN_USERNAME", "admin"),
            password=generate_password_hash(default_password),
            role="admin",
            must_change_password=True,
            failed_login_attempts=0,
        )
        db.session.add(admin)
        db.session.commit()


def normalize_existing_user_data():
    changed = False
    for user in User.query.all():
        if user.failed_login_attempts is None:
            user.failed_login_attempts = 0
            changed = True
        if user.must_change_password is None:
            user.must_change_password = False
            changed = True
    if changed:
        db.session.commit()


with app.app_context():
    ensure_default_admin()
    normalize_existing_mouse_data()
    normalize_existing_user_data()


@app.route("/")
def home():
    if g.user:
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if g.user:
        return redirect(url_for("dashboard"))

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        user = User.query.filter_by(username=username).first()

        if user and login_locked(user):
            lock_until = parse_datetime(user.locked_until)
            flash(f"Account locked until {lock_until.strftime('%H:%M:%S')} due to repeated failed logins.", "danger")
            return render_template("login.html", default_hint=False, default_admin_name=os.environ.get("DEFAULT_ADMIN_USERNAME", "admin"))

        if user and check_password_hash(user.password, password):
            session.clear()
            session["user_id"] = user.id
            session["_csrf_token"] = secrets.token_urlsafe(32)
            register_successful_login(user)
            log_action("login", "user", user.username, "Successful web login")
            db.session.commit()
            flash(f"Welcome back, {user.username}.", "success")
            if user.must_change_password:
                flash("Please change your password before continuing.", "warning")
                return redirect(url_for("change_password"))
            next_url = request.args.get("next")
            next_url = next_url if is_safe_redirect_target(next_url) else url_for("dashboard")
            return redirect(next_url)

        if user:
            register_failed_login(user)
            db.session.commit()
        flash("Invalid username or password.", "danger")

    default_admin_name = os.environ.get("DEFAULT_ADMIN_USERNAME", "admin")
    default_hint = User.query.count() == 1 and User.query.filter_by(username=default_admin_name).first() is not None
    return render_template("login.html", default_hint=default_hint, default_admin_name=default_admin_name)


@app.route("/logout", methods=["POST"])
@login_required
def logout():
    log_action("logout", "user", g.user.username, "Signed out")
    db.session.commit()
    session.clear()
    flash("You have been signed out.", "info")
    return redirect(url_for("login"))


@app.route("/change-password", methods=["GET", "POST"])
@login_required
def change_password():
    if request.method == "POST":
        current_password = request.form.get("current_password", "")
        new_password = request.form.get("new_password", "")
        confirm_password = request.form.get("confirm_password", "")

        if not check_password_hash(g.user.password, current_password):
            flash("Current password is incorrect.", "danger")
            return redirect(url_for("change_password"))
        if new_password != confirm_password:
            flash("New password and confirmation do not match.", "danger")
            return redirect(url_for("change_password"))

        issues = password_policy_errors(new_password, g.user.username)
        if issues:
            for issue in issues:
                flash(issue, "danger")
            return redirect(url_for("change_password"))

        g.user.password = generate_password_hash(new_password)
        g.user.must_change_password = False
        log_action("password_change", "user", g.user.username, "Changed own password")
        db.session.commit()
        flash("Password updated successfully.", "success")
        return redirect(url_for("dashboard"))

    return render_template("change_password.html")


@app.route("/users", methods=["GET", "POST"])
@role_required("admin")
def users():
    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        role = request.form.get("role", "viewer").strip()

        if not username or not password:
            flash("Username and password are required.", "danger")
            return redirect(url_for("users"))

        if User.query.filter_by(username=username).first():
            flash("That username already exists.", "warning")
            return redirect(url_for("users"))

        issues = password_policy_errors(password, username)
        if issues:
            for issue in issues:
                flash(issue, "danger")
            return redirect(url_for("users"))

        db.session.add(
            User(
                username=username,
                password=generate_password_hash(password),
                role=role,
                must_change_password=True,
                failed_login_attempts=0,
            )
        )
        log_action("create", "user", username, f"Created user with role {role}")
        db.session.commit()
        flash("User account created.", "success")
        return redirect(url_for("users"))

    return render_template("users.html", users=User.query.order_by(User.username.asc()).all())


@app.route("/users/<int:user_id>/password", methods=["POST"])
@role_required("admin")
def reset_user_password(user_id):
    user = User.query.get_or_404(user_id)
    password = request.form.get("password", "")
    issues = password_policy_errors(password, user.username)
    if issues:
        for issue in issues:
            flash(issue, "danger")
        return redirect(url_for("users"))

    user.password = generate_password_hash(password)
    user.must_change_password = True
    user.failed_login_attempts = 0
    user.locked_until = None
    log_action("password_reset", "user", user.username, "Password reset by admin")
    db.session.commit()
    flash(f"Password updated for {user.username}.", "success")
    return redirect(url_for("users"))


@app.route("/audit-log")
@role_required("admin")
def audit_log():
    entries = AuditLog.query.order_by(AuditLog.id.desc()).limit(250).all()
    return render_template("audit_log.html", entries=entries)


@app.route("/backups")
@role_required("admin")
def backups():
    return render_template(
        "backups.html",
        live_database_path=str(database_file()) if is_sqlite_backend() else "PostgreSQL / external database",
        sqlite_mode=is_sqlite_backend(),
        backups=available_backups(),
    )


@app.route("/backups/create", methods=["POST"])
@role_required("admin")
def create_backup():
    if not is_sqlite_backend():
        flash("In-app backup is available only for SQLite. Use your database provider backup tools for PostgreSQL.", "warning")
        return redirect(url_for("backups"))
    label = request.form.get("label", "manual")
    backup_path = create_database_backup(label=label)
    log_action("backup_create", "database", backup_path.name, f"Created backup {backup_path.name}")
    db.session.commit()
    flash(f"Backup created: {backup_path.name}", "success")
    return redirect(url_for("backups"))


@app.route("/backups/download/<path:backup_name>")
@role_required("admin")
def download_backup(backup_name):
    if not is_sqlite_backend():
        flash("Backup download is available only for SQLite backups.", "warning")
        return redirect(url_for("backups"))
    backup_path = backup_directory() / backup_name
    if not backup_path.exists():
        flash("Backup file not found.", "danger")
        return redirect(url_for("backups"))
    return send_file(backup_path, as_attachment=True, download_name=backup_path.name)


@app.route("/backups/restore/<path:backup_name>", methods=["POST"])
@role_required("admin")
def restore_backup(backup_name):
    if not is_sqlite_backend():
        flash("In-app restore is available only for SQLite. Use your PostgreSQL restore workflow instead.", "warning")
        return redirect(url_for("backups"))
    restore_target = backup_directory() / backup_name
    if not restore_target.exists():
        flash("Backup file not found.", "danger")
        return redirect(url_for("backups"))

    safety_backup = create_database_backup(label="pre-restore")
    restore_database_from_backup(backup_name)
    db.session.add(
        AuditLog(
            created_at=datetime.now().isoformat(timespec="seconds"),
            username=g.user.username,
            action="backup_restore",
            entity_type="database",
            entity_id=backup_name,
            details=f"Restored backup {backup_name}; safety backup {safety_backup.name}",
        )
    )
    db.session.commit()
    flash(
        f"Database restored from {backup_name}. Safety backup saved as {safety_backup.name}.",
        "warning",
    )
    return redirect(url_for("backups"))


@app.route("/dashboard")
@login_required
def dashboard():
    mice = active_mouse_query().order_by(Mouse.id.asc()).all()
    grouped_mice = {}
    for mouse in mice:
        grouped_mice.setdefault(mouse.strain, []).append(mouse)
    true_strain_count = len({normalize_label(mouse.strain) for mouse in mice if classify_mouse_group(mouse) == "genetic_strain"})

    stats = {
        "total_mice": len(mice),
        "strains": true_strain_count,
        "training_mice": sum(1 for mouse in mice if mouse.training),
        "active_breedings": Breeding.query.count(),
        "calendar_events": CalendarEvent.query.count(),
    }
    recent_events = CalendarEvent.query.order_by(CalendarEvent.date.asc()).limit(5).all()
    return render_template(
        "dashboard.html",
        grouped_mice=grouped_mice,
        stats=stats,
        recent_events=recent_events,
    )


@app.route("/analytics", methods=["GET", "POST"])
@login_required
def analytics():
    mice = active_mouse_query().order_by(Mouse.strain.asc(), Mouse.id.asc()).all()
    breedings = Breeding.query.all()
    procedures_list = Procedure.query.all()
    calendar_events = CalendarEvent.query.all()

    genetic_strains = {}
    procedure_cohorts = {}
    for mouse in mice:
        normalized = normalize_label(mouse.strain)
        target = genetic_strains if mouse.group_type == "genetic_strain" else procedure_cohorts
        target.setdefault(normalized, {"label": display_group_label(mouse.strain), "mice": []})
        target[normalized]["mice"].append(mouse)

    breeding_by_female = {}
    breeding_by_male = {}
    for record in breedings:
        breeding_by_male[record.male_id] = breeding_by_male.get(record.male_id, 0) + 1
        breeding_by_female[record.female_id] = breeding_by_female.get(record.female_id, 0) + 1

    procedure_by_mouse = {}
    for procedure in procedures_list:
        procedure_by_mouse[procedure.mouse_id] = procedure_by_mouse.get(procedure.mouse_id, 0) + 1

    def build_group_rows(grouped_mice):
        rows = []
        for normalized, payload in grouped_mice.items():
            group_mice = payload["mice"]
            rack_counts = {}
            for mouse in group_mice:
                rack_key = mouse.rack_location or "Unassigned"
                rack_counts[rack_key] = rack_counts.get(rack_key, 0) + 1

            dated_mice = [mouse for mouse in group_mice if parse_iso_date(mouse.dob) is not None]
            rows.append(
                {
                    "label": payload["label"],
                    "normalized_label": normalized,
                    "total_mice": len(group_mice),
                    "male_count": sum(1 for mouse in group_mice if mouse.gender == "MALE"),
                    "female_count": sum(1 for mouse in group_mice if mouse.gender == "FEMALE"),
                    "training_count": sum(1 for mouse in group_mice if mouse.training),
                    "active_projects": len({mouse.project for mouse in group_mice if mouse.project}),
                    "breeding_links": sum(
                        breeding_by_male.get(mouse.id, 0) + breeding_by_female.get(mouse.id, 0)
                        for mouse in group_mice
                    ),
                    "procedure_count": sum(procedure_by_mouse.get(mouse.id, 0) for mouse in group_mice),
                    "cages_in_use": len({mouse.cage for mouse in group_mice if mouse.cage}),
                    "rack_summary": ", ".join(
                        f"{rack} ({count})"
                        for rack, count in sorted(rack_counts.items(), key=lambda item: (-item[1], item[0]))
                    ),
                    "avg_age_days": round(
                        sum((date.today() - parse_iso_date(mouse.dob)).days for mouse in dated_mice) / max(1, len(dated_mice)),
                        1,
                    ) if dated_mice else 0,
                }
            )
        return sorted(rows, key=lambda row: (-row["total_mice"], row["label"]))

    strain_rows = build_group_rows(genetic_strains)
    procedure_rows = build_group_rows(procedure_cohorts)

    chart_max = max([row["total_mice"] for row in strain_rows + procedure_rows], default=1)
    for row in strain_rows + procedure_rows:
        row["plot_width"] = round((row["total_mice"] / chart_max) * 100, 1)

    rack_totals = {}
    for mouse in mice:
        rack_key = mouse.rack_location or "Unassigned"
        rack_totals[rack_key] = rack_totals.get(rack_key, 0) + 1
    rack_rows = [{"rack": rack, "count": count} for rack, count in sorted(rack_totals.items(), key=lambda item: (-item[1], item[0]))]
    rack_max = max([row["count"] for row in rack_rows], default=1)
    for row in rack_rows:
        row["plot_width"] = round((row["count"] / rack_max) * 100, 1)

    procedure_type_counts = {}
    for procedure in procedures_list:
        label = display_group_label(procedure.type)
        procedure_type_counts[label] = procedure_type_counts.get(label, 0) + 1
    procedure_type_rows = [
        {"label": label, "count": count}
        for label, count in sorted(procedure_type_counts.items(), key=lambda item: (-item[1], item[0]))
    ]
    procedure_type_max = max([row["count"] for row in procedure_type_rows], default=1)
    for row in procedure_type_rows:
        row["plot_width"] = round((row["count"] / procedure_type_max) * 100, 1)

    default_costs = {
        "purchase_cost_per_mouse": 45.0,
        "housing_cost_per_mouse_per_month": 8.0,
        "feed_cost_per_mouse_per_month": 4.0,
        "procedure_cost_average": 18.0,
        "breeding_pair_cost_per_month": 25.0,
    }

    calculator_values = {}
    for key, default_value in default_costs.items():
        raw_value = request.form.get(key) if request.method == "POST" else request.args.get(key)
        try:
            calculator_values[key] = float(raw_value) if raw_value not in {None, ""} else default_value
        except ValueError:
            calculator_values[key] = default_value

    total_mice = len(mice)
    total_procedures = len(procedures_list)
    total_breedings = len(breedings)

    monthly_housing_total = total_mice * calculator_values["housing_cost_per_mouse_per_month"]
    monthly_feed_total = total_mice * calculator_values["feed_cost_per_mouse_per_month"]
    monthly_breeding_total = total_breedings * calculator_values["breeding_pair_cost_per_month"]
    estimated_purchase_value = total_mice * calculator_values["purchase_cost_per_mouse"]
    estimated_procedure_total = total_procedures * calculator_values["procedure_cost_average"]

    cost_summary = {
        "estimated_purchase_value": round(estimated_purchase_value, 2),
        "monthly_housing_total": round(monthly_housing_total, 2),
        "monthly_feed_total": round(monthly_feed_total, 2),
        "monthly_breeding_total": round(monthly_breeding_total, 2),
        "estimated_procedure_total": round(estimated_procedure_total, 2),
        "estimated_monthly_total": round(monthly_housing_total + monthly_feed_total + monthly_breeding_total, 2),
        "estimated_overall_management_value": round(
            estimated_purchase_value + estimated_procedure_total + monthly_housing_total + monthly_feed_total,
            2,
        ),
    }

    top_strain = max(strain_rows, key=lambda row: row["total_mice"], default=None)
    summary = {
        "strain_count": len(strain_rows),
        "procedure_cohort_count": len(procedure_rows),
        "total_mice": total_mice,
        "total_procedures": total_procedures,
        "total_breedings": total_breedings,
        "calendar_events": len(calendar_events),
        "top_strain": top_strain["label"] if top_strain else "None",
    }

    return render_template(
        "analytics.html",
        summary=summary,
        strain_rows=strain_rows,
        procedure_rows=procedure_rows,
        rack_rows=rack_rows,
        procedure_type_rows=procedure_type_rows,
        calculator_values=calculator_values,
        cost_summary=cost_summary,
    )


@app.route("/add_strain", methods=["GET", "POST"])
@login_required
def add_strain():
    if request.method == "POST":
        strain = request.form.get("strain", "").strip()
        if not strain:
            flash("Strain name is required.", "danger")
            return redirect(url_for("add_strain"))
        flash(f'Strain "{strain}" is now available for new entries.', "success")
        return redirect(url_for("add_mouse", strain=strain))
    return render_template("add_strain.html")


@app.route("/mice")
@login_required
def mice_list():
    strain_filter = request.args.get("strain", "").strip()
    group_type_filter = request.args.get("group_type", "").strip()
    gender_filter = request.args.get("gender", "").strip()
    genotype_filter = request.args.get("genotype", "").strip()
    dob_start = request.args.get("dob_start", "").strip()
    dob_end = request.args.get("dob_end", "").strip()
    sort_dob = request.args.get("sort_dob", "").strip()

    include_archived = request.args.get("include_archived", "").strip() == "1"
    query = Mouse.query if include_archived else active_mouse_query()
    if strain_filter:
        query = query.filter_by(strain=strain_filter)
    if group_type_filter:
        query = query.filter_by(group_type=group_type_filter)
    if gender_filter:
        query = query.filter_by(gender=gender_filter)
    if genotype_filter:
        query = query.filter_by(genotype=genotype_filter)
    if dob_start:
        query = query.filter(Mouse.dob >= dob_start)
    if dob_end:
        query = query.filter(Mouse.dob <= dob_end)

    if sort_dob == "asc":
        query = query.order_by(Mouse.dob.asc())
    elif sort_dob == "desc":
        query = query.order_by(Mouse.dob.desc())
    else:
        query = query.order_by(Mouse.id.desc())

    mice = query.all()
    source_query = Mouse.query if include_archived else active_mouse_query()
    strains = [row[0] for row in source_query.with_entities(Mouse.strain).distinct().order_by(Mouse.strain.asc())]
    genders = [row[0] for row in source_query.with_entities(Mouse.gender).distinct().order_by(Mouse.gender.asc())]
    genotypes = [row[0] for row in source_query.with_entities(Mouse.genotype).distinct().order_by(Mouse.genotype.asc())]

    return render_template(
        "mice.html",
        mice=mice,
        strains=strains,
        group_types=["genetic_strain", "procedure_cohort"],
        genders=genders,
        genotypes=genotypes,
        include_archived=include_archived,
    )


@app.route("/scan-cage-card", methods=["GET", "POST"])
@login_required
def scan_cage_card():
    scan_result = None
    matches = []
    raw_text = ""
    image_preview = ""
    processed_preview = ""
    scan_mode = request.values.get("scan_mode", "create").strip() or "create"
    if scan_mode not in {"create", "archive"}:
        scan_mode = "create"
    created_mouse = None
    archived_mouse = None
    created_id = str(request.args.get("created_mouse_id") or "").strip()
    archived_id = str(request.args.get("archived_mouse_id") or "").strip()
    if created_id.isdigit():
        created_mouse = Mouse.query.get(int(created_id))
    if archived_id.isdigit():
        archived_mouse = Mouse.query.get(int(archived_id))

    if request.method == "POST":
        raw_text = request.form.get("raw_text", "").strip()
        image_file = request.files.get("cage_card_camera") or request.files.get("cage_card_gallery")

        if image_file and getattr(image_file, "filename", ""):
            try:
                started_at = datetime.now()
                app.logger.info("Starting cage-card OCR for filename=%s mode=%s", image_file.filename, scan_mode)
                ocr_result = ocr_uploaded_image(image_file)
                raw_text = ocr_result["raw_text"]
                image_preview = ocr_result["original_preview"]
                processed_preview = ocr_result["processed_preview"]
                scan_result = extract_cage_card_fields(raw_text, diagnostics=ocr_result["diagnostics"])
                elapsed = (datetime.now() - started_at).total_seconds()
                app.logger.info("Finished cage-card OCR in %.2fs using engine=%s", elapsed, ocr_result["diagnostics"].get("ocr_engine", "unknown"))
            except Exception as error:
                app.logger.exception("Cage-card OCR failed")
                flash(str(error), "danger")

        if raw_text:
            if scan_result is None:
                scan_result = extract_cage_card_fields(raw_text)
            if scan_result["mouse_id"]:
                mouse = Mouse.query.get(scan_result["mouse_id"])
                if mouse:
                    matches = [mouse]
            elif scan_result["editor"]["cage"]:
                matches = (
                    active_mouse_query()
                    .filter(Mouse.cage == scan_result["editor"]["cage"])
                    .order_by(Mouse.id.desc())
                    .all()
                )
        else:
            flash("Take a cage card photo or paste OCR text first.", "danger")

    return render_template(
        "scan_cage_card.html",
        raw_text=raw_text,
        scan_result=scan_result,
        matches=matches,
        image_preview=image_preview,
        processed_preview=processed_preview,
        scan_mode=scan_mode,
        created_mouse=created_mouse,
        archived_mouse=archived_mouse,
    )


@app.route("/scan-cage-card/store", methods=["POST"])
@login_required
def store_scanned_mouse():
    field_names = [
        "strain",
        "gender",
        "genotype",
        "dob",
        "cage",
        "rack_location",
        "owner_pi",
        "protocol_number",
        "age",
        "room",
        "requisition_number",
        "notes",
    ]
    values = {name: request.form.get(name, "") for name in field_names}
    values["training"] = request.form.get("training", "")

    warnings = []
    if not values["strain"].strip():
        warnings.append("Strain is required before storing.")
    if not normalize_gender(values["gender"]):
        warnings.append("Gender is required before storing.")
    if not values["cage"].strip():
        warnings.append("Cage is required before storing.")
    if not values["rack_location"].strip():
        warnings.append("Rack location is required before storing.")
    if not values["requisition_number"].strip():
        warnings.append("Requisition number is required before storing.")
    if values["dob"] and not normalize_date(values["dob"]):
        warnings.append("DOB must be a valid date before storing.")

    if warnings:
        for warning in warnings:
            flash(warning, "danger")
        return render_template(
            "scan_cage_card.html",
            raw_text=request.form.get("raw_text", ""),
            scan_result={
                "raw_text": request.form.get("raw_text", ""),
                "overall_confidence": float(request.form.get("overall_confidence", "0") or 0),
                "warnings": warnings,
                "fields": {
                    key: {
                        "value": request.form.get("animal_count", "") if key == "number_of_animals" else request.form.get(key, ""),
                        "confidence": float(request.form.get(f"{key}__confidence", "0") or 0),
                        "source": request.form.get(f"{key}__source", "manual"),
                    }
                    for key, _labels, _kind in SCAN_FIELD_SPECS
                },
                "editor": {
                    "strain": values["strain"],
                    "gender": values["gender"],
                    "genotype": values["genotype"],
                    "dob": values["dob"],
                    "cage": values["cage"],
                    "rack_location": values["rack_location"],
                    "age": values["age"],
                    "room": values["room"],
                    "requisition_number": values["requisition_number"],
                    "notes": values["notes"],
                    "group_type": infer_group_type_from_label(values["strain"]),
                    "project": "",
                    "owner_pi": values.get("owner_pi", "") or DEFAULT_OWNER_PI,
                    "protocol_number": values["protocol_number"] or DEFAULT_PROTOCOL_NUMBER,
                    "animal_count": None,
                    "received_date": "",
                    "vendor": "",
                    "weight": "",
                    "species": "Mouse",
                    "cost_center": "",
                    "training": False,
                },
            },
            matches=[],
            image_preview=request.form.get("image_preview", ""),
            processed_preview=request.form.get("processed_preview", ""),
            scan_mode=request.form.get("scan_mode", "create"),
        )

    new_mouse = Mouse()
    apply_mouse_form(new_mouse, request.form)
    db.session.add(new_mouse)
    db.session.flush()
    log_action("create", "mouse", new_mouse.id, f"Stored scanned mouse {new_mouse.strain} in cage {new_mouse.cage or 'unassigned'}")
    db.session.commit()
    flash(f"Scanned record stored as mouse #{new_mouse.id}.", "success")
    return redirect(url_for("scan_cage_card", scan_mode="create", created_mouse_id=new_mouse.id))


@app.route("/scan-cage-card/archive", methods=["POST"])
@role_required("admin", "tech")
def archive_scanned_mouse():
    target_id = str(request.form.get("target_mouse_id") or "").strip()
    scan_mode = request.form.get("scan_mode", "archive").strip() or "archive"
    if not target_id.isdigit():
        flash("Select a matching mouse before approving archive.", "danger")
        return redirect(url_for("scan_cage_card", scan_mode=scan_mode))

    mouse = active_mouse_query().filter_by(id=int(target_id)).first()
    if mouse is None:
        flash("That mouse could not be found or is already archived.", "danger")
        return redirect(url_for("scan_cage_card", scan_mode=scan_mode))

    mouse.is_active = False
    mouse.deleted_at = datetime.now().isoformat(timespec="seconds")
    log_action("archive", "mouse", mouse.id, f"Archived from scan review in cage {mouse.cage}")
    db.session.commit()
    flash(f"Archived mouse #{mouse.id} from cage {mouse.cage}.", "success")
    return redirect(url_for("scan_cage_card", scan_mode="archive", archived_mouse_id=mouse.id))


@app.route("/add_mouse", methods=["GET", "POST"])
@login_required
def add_mouse():
    if request.method == "POST":
        new_mouse = Mouse()
        apply_mouse_form(new_mouse, request.form)
        db.session.add(new_mouse)
        db.session.flush()
        log_action("create", "mouse", new_mouse.id, f"Created {new_mouse.strain} in cage {new_mouse.cage}")
        db.session.commit()
        flash("Mouse added successfully.", "success")
        return redirect(url_for("mice_list"))

    return render_template(
        "add_mouse.html",
        strain_prefill=request.args.get("strain", ""),
        gender_prefill=request.args.get("gender", "MALE"),
        genotype_prefill=request.args.get("genotype", ""),
        dob_prefill=display_date_us(request.args.get("dob", "")),
        cage_prefill=request.args.get("cage", ""),
        rack_location_prefill=request.args.get("rack_location", ""),
        project_prefill="",
        owner_pi_prefill=request.args.get("owner_pi", "") or DEFAULT_OWNER_PI,
        protocol_number_prefill=DEFAULT_PROTOCOL_NUMBER,
        animal_count_prefill="",
        received_date_prefill="",
        vendor_prefill="",
        age_prefill=request.args.get("age", "") or calculate_age_from_dob(request.args.get("dob", "")),
        weight_prefill="",
        species_prefill="Mouse",
        room_prefill=DEFAULT_ROOM,
        requisition_number_prefill=request.args.get("requisition_number", ""),
        cost_center_prefill="",
        notes_prefill=request.args.get("notes", ""),
        training_prefill=False,
        label_options=mouse_label_options(),
    )


@app.route("/edit_mouse/<int:id>", methods=["GET", "POST"])
@login_required
def edit_mouse(id):
    mouse = Mouse.query.get_or_404(id)
    if request.method == "POST":
        apply_mouse_form(mouse, request.form)
        log_action("update", "mouse", mouse.id, f"Updated {mouse.strain} in cage {mouse.cage}")
        db.session.commit()
        flash("Mouse updated.", "success")
        return redirect(url_for("mice_list"))
    return render_template("edit_mouse.html", mouse=mouse, label_options=mouse_label_options())


@app.route("/delete_mouse/<int:id>", methods=["POST"])
@role_required("admin", "tech")
def delete_mouse(id):
    mouse = Mouse.query.get_or_404(id)
    mouse.is_active = False
    mouse.deleted_at = datetime.now().isoformat(timespec="seconds")
    log_action("archive", "mouse", mouse.id, f"Archived mouse {mouse.strain} in cage {mouse.cage}")
    db.session.commit()
    flash("Mouse archived. It can be restored later.", "success")
    return redirect(url_for("mice_list"))


@app.route("/restore_mouse/<int:id>", methods=["POST"])
@role_required("admin", "tech")
def restore_mouse(id):
    mouse = Mouse.query.get_or_404(id)
    mouse.is_active = True
    mouse.deleted_at = None
    log_action("restore", "mouse", mouse.id, f"Restored mouse {mouse.strain}")
    db.session.commit()
    flash("Mouse restored.", "success")
    return redirect(url_for("mice_list", include_archived=1))


@app.route("/cage_transfer/<int:mouse_id>", methods=["GET", "POST"])
@login_required
def cage_transfer(mouse_id):
    mouse = active_mouse_query().filter_by(id=mouse_id).first_or_404()
    if request.method == "POST":
        new_cage = request.form.get("new_cage", "").strip()
        transfer_date = request.form.get("date", "").strip() or today_iso()
        if not new_cage:
            flash("New cage is required.", "danger")
            return redirect(url_for("cage_transfer", mouse_id=mouse.id))

        transfer = CageTransfer(mouse_id=mouse.id, new_cage=new_cage, date=transfer_date)
        db.session.add(transfer)
        mouse.cage = new_cage
        log_action("cage_transfer", "mouse", mouse.id, f"Moved to cage {new_cage} on {transfer_date}")
        db.session.commit()
        flash("Cage transfer logged.", "info")
        return redirect(url_for("mice_list"))
    return render_template("cage_transfer.html", mouse=mouse)


@app.route("/breeding")
@login_required
def breeding_log():
    records = Breeding.query.order_by(Breeding.pair_date.desc()).all()
    return render_template("breeding.html", records=records, mice=mouse_choices())


@app.route("/breeding/add", methods=["GET", "POST"])
@login_required
def add_breeding():
    mice = mouse_choices()
    if request.method == "POST":
        new_pair = Breeding(
            male_id=request.form["male_id"],
            female_id=request.form["female_id"],
            pair_date=request.form["pair_date"],
            litter_count=request.form.get("litter_count") or None,
            litter_date=request.form.get("litter_date") or None,
            wean_date=request.form.get("wean_date") or None,
            notes=request.form.get("notes") or None,
        )
        db.session.add(new_pair)
        db.session.flush()
        log_action("create", "breeding", new_pair.id, f"Breeding {new_pair.male_id} x {new_pair.female_id}")
        db.session.commit()
        flash("Breeding record added.", "success")
        return redirect(url_for("breeding_log"))

    return render_template("add_breeding.html", mice=mice)


@app.route("/breeding/delete/<int:id>", methods=["POST"])
@role_required("admin", "tech")
def delete_breeding(id):
    record = Breeding.query.get_or_404(id)
    log_action("delete", "breeding", record.id, f"Deleted breeding {record.male_id} x {record.female_id}")
    db.session.delete(record)
    db.session.commit()
    flash("Breeding record deleted.", "info")
    return redirect(url_for("breeding_log"))


@app.route("/add_pup/<int:breeding_id>", methods=["POST"])
@login_required
def add_pup(breeding_id):
    birth_date_value = parse_iso_date(request.form.get("birth_date"))
    if birth_date_value is None:
        flash("A valid pup birth date is required.", "danger")
        return redirect(url_for("breeding_log"))

    new_pup = Pup(
        breeding_id=breeding_id,
        sex=request.form.get("sex", "").strip().upper(),
        genotype=request.form.get("genotype", "").strip() or None,
        birth_date=birth_date_value,
        notes=request.form.get("notes", "").strip() or None,
    )
    db.session.add(new_pup)
    log_action("create", "pup", breeding_id, f"Added pup to breeding {breeding_id}")
    db.session.commit()
    flash("Pup added successfully.", "success")
    return redirect(url_for("breeding_log"))


@app.route("/pups")
@login_required
def pup_list():
    pups = Pup.query.order_by(Pup.birth_date.desc()).all()
    return render_template("pup_list.html", pups=pups)


@app.route("/procedures", methods=["GET", "POST"])
@login_required
def procedures():
    if request.method == "POST":
        procedure = Procedure(
            mouse_id=request.form["mouse_id"],
            type=request.form["type"],
            date=request.form["date"],
            notes=request.form.get("notes", "").strip() or None,
        )
        db.session.add(procedure)
        log_action("create", "procedure", request.form["mouse_id"], f"Logged procedure {request.form['type']}")
        db.session.commit()
        flash("Procedure logged.", "info")
        return redirect(url_for("procedures"))

    procedures_list = Procedure.query.order_by(Procedure.date.desc()).all()
    return render_template("procedures.html", procedures=procedures_list, mice=mouse_choices())


@app.route("/calendar")
@login_required
def calendar_view():
    events = CalendarEvent.query.order_by(CalendarEvent.date.asc()).all()
    return render_template("calendar.html", events=events)


@app.route("/calendar/add", methods=["POST"])
@login_required
def add_calendar_event():
    title = request.form["title"].strip()
    date_val = request.form["date"]
    category = request.form.get("category", "").strip()
    notes = request.form.get("notes", "").strip()
    notify_email = request.form.get("notify") or request.form.get("email")

    new_event = CalendarEvent(
        title=title,
        date=date_val,
        category=category or None,
        notes=notes or None,
    )
    db.session.add(new_event)
    log_action("create", "calendar_event", title, f"Calendar event on {date_val}")
    db.session.commit()

    if notify_email and notify_email.endswith("@buffalo.edu"):
        app.logger.info("Reminder requested for %s about %s on %s", notify_email, title, date_val)

    flash("Calendar event added.", "success")
    return redirect(url_for("calendar_view"))


@app.route("/calendar/delete/<int:event_id>", methods=["POST"])
@role_required("admin", "tech")
def delete_calendar_event(event_id):
    event = CalendarEvent.query.get_or_404(event_id)
    log_action("delete", "calendar_event", event.id, f"Deleted calendar event {event.title}")
    db.session.delete(event)
    db.session.commit()
    flash("Event deleted.", "danger")
    return redirect(url_for("calendar_view"))


@app.route("/export")
@login_required
def export_page():
    return render_template("export.html")


@app.route("/export/<table>")
@login_required
def export_csv(table):
    output = io.StringIO()
    writer = csv.writer(output)

    if table == "mice":
        writer.writerow(["ID", "Strain", "Group Type", "Gender", "Genotype", "DOB", "Cage", "Rack", "Training", "Project", "Active", "Deleted At", "Notes"])
        for mouse in Mouse.query.order_by(Mouse.id.asc()).all():
            writer.writerow(
                [
                    mouse.id,
                    mouse.strain,
                    classify_mouse_group(mouse),
                    mouse.gender,
                    mouse.genotype,
                    mouse.dob,
                    mouse.cage,
                    mouse.rack_location or "",
                    "Yes" if mouse.training else "No",
                    mouse.project or "",
                    "Yes" if mouse.is_active else "No",
                    mouse.deleted_at or "",
                    mouse.notes or "",
                ]
            )
    elif table == "breeding":
        writer.writerow(
            ["ID", "Male ID", "Female ID", "Pair Date", "Litter Count", "Litter Date", "Wean Date", "Status", "Notes"]
        )
        for record in Breeding.query.order_by(Breeding.id.asc()).all():
            writer.writerow(
                [
                    record.id,
                    record.male_id,
                    record.female_id,
                    record.pair_date,
                    record.litter_count or "",
                    record.litter_date or "",
                    record.wean_date or "",
                    record.status,
                    record.notes or "",
                ]
            )
    elif table == "pups":
        writer.writerow(["ID", "Breeding ID", "Sex", "Genotype", "Birth Date", "Weaning Due", "Notes"])
        for pup in Pup.query.order_by(Pup.id.asc()).all():
            writer.writerow(
                [
                    pup.id,
                    pup.breeding_id,
                    pup.sex,
                    pup.genotype or "",
                    pup.birth_date.isoformat(),
                    "Yes" if pup.weaning_due else "No",
                    pup.notes or "",
                ]
            )
    elif table == "procedures":
        writer.writerow(["ID", "Mouse ID", "Type", "Date", "Notes"])
        for procedure in Procedure.query.order_by(Procedure.id.asc()).all():
            writer.writerow([procedure.id, procedure.mouse_id, procedure.type, procedure.date, procedure.notes or ""])
    elif table == "calendar":
        writer.writerow(["ID", "Title", "Date", "Category", "Notes"])
        for event in CalendarEvent.query.order_by(CalendarEvent.id.asc()).all():
            writer.writerow([event.id, event.title, event.date, event.category or "", event.notes or ""])
    else:
        return "Invalid table name", 400

    response = Response(output.getvalue(), mimetype="text/csv")
    response.headers["Content-Disposition"] = f"attachment; filename={table}_data.csv"
    return response


@app.route("/api/login", methods=["POST"])
def api_login():
    payload = request.get_json(silent=True) or {}
    username = (payload.get("username") or "").strip()
    password = payload.get("password") or ""

    user = User.query.filter_by(username=username).first()
    if user and login_locked(user):
        return jsonify({"error": "Account temporarily locked due to failed logins"}), 423
    if user is None or not check_password_hash(user.password, password):
        if user:
            register_failed_login(user)
            db.session.commit()
        return jsonify({"error": "Invalid credentials"}), 401

    register_successful_login(user)
    token = token_serializer().dumps({"user_id": user.id})
    log_action("api_login", "user", user.username, "Successful mobile/API login")
    db.session.commit()
    return jsonify(
        {
            "token": token,
            "user": {
                "id": user.id,
                "username": user.username,
                "role": user.role,
                "must_change_password": bool(user.must_change_password),
            },
        }
    )


@app.route("/api/dashboard")
@api_login_required
def api_dashboard():
    mice = Mouse.query.all()
    grouped = {}
    for mouse in mice:
        grouped[mouse.strain] = grouped.get(mouse.strain, 0) + 1

    return jsonify(
        {
            "stats": {
                "total_mice": len(mice),
                "strains": len(grouped),
                "training_mice": sum(1 for mouse in mice if mouse.training),
                "active_breedings": Breeding.query.count(),
                "calendar_events": CalendarEvent.query.count(),
            },
            "strain_counts": grouped,
            "recent_events": [
                {"id": event.id, "title": event.title, "date": event.date, "category": event.category or ""}
                for event in CalendarEvent.query.order_by(CalendarEvent.date.asc()).limit(10).all()
            ],
        }
    )


@app.route("/api/analytics")
@api_login_required
def api_analytics():
    mice = active_mouse_query().all()
    true_strains = {}
    procedure_cohorts = {}
    rack_counts = {}

    for mouse in mice:
        target = true_strains if mouse.group_type == "genetic_strain" else procedure_cohorts
        target[mouse.strain] = target.get(mouse.strain, 0) + 1
        rack_key = mouse.rack_location or "Unassigned"
        rack_counts[rack_key] = rack_counts.get(rack_key, 0) + 1

    return jsonify(
        {
            "true_strains": true_strains,
            "procedure_cohorts": procedure_cohorts,
            "racks": rack_counts,
        }
    )


@app.route("/api/mice", methods=["GET", "POST"])
@api_login_required
def api_mice():
    if request.method == "GET":
        include_archived = request.args.get("include_archived", "").strip() == "1"
        query = Mouse.query if include_archived else active_mouse_query()
        cage_filter = request.args.get("cage", "").strip()
        if cage_filter:
            query = query.filter(Mouse.cage == cage_filter)
        mice = query.order_by(Mouse.id.desc()).all()
        return jsonify([serialize_mouse(mouse) for mouse in mice])

    payload = request.get_json(silent=True) or {}
    required_fields = ["strain", "gender", "genotype", "dob", "cage"]
    missing = [field for field in required_fields if not payload.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    mouse = Mouse(
        group_type=infer_group_type_from_label(payload["strain"]),
        strain=canonical_mouse_label(payload["strain"].strip(), infer_group_type_from_label(payload["strain"])),
        gender=normalize_gender(payload["gender"]),
        genotype=payload["genotype"].strip(),
        dob=normalize_date(payload["dob"]) or payload["dob"],
        cage=normalize_text_value(payload["cage"]),
        rack_location=(payload.get("rack_location") or "").strip() or None,
        notes=(payload.get("notes") or "").strip() or None,
        training=bool(payload.get("training")),
        project=(payload.get("project") or "").strip() or None,
        owner_pi=(payload.get("owner_pi") or "").strip() or None,
        protocol_number=DEFAULT_PROTOCOL_NUMBER,
        animal_count=int(str(payload.get("animal_count") or "").strip()) if str(payload.get("animal_count") or "").strip().isdigit() else None,
        received_date=normalize_date(payload.get("received_date") or "") or None,
        vendor=None,
        age=calculate_age_from_dob(payload["dob"]),
        weight=None,
        species=normalize_species(payload.get("species") or "") or "Mouse",
        room=DEFAULT_ROOM,
        requisition_number=normalize_text_value(payload.get("requisition_number") or "") or None,
        cost_center=normalize_text_value(payload.get("cost_center") or "") or None,
    )
    db.session.add(mouse)
    db.session.commit()
    return jsonify(serialize_mouse(mouse)), 201


@app.route("/api/mice/<int:mouse_id>", methods=["PUT"])
@api_login_required
def api_update_mouse(mouse_id):
    mouse = Mouse.query.get_or_404(mouse_id)
    payload = request.get_json(silent=True) or {}

    for field in ["gender", "genotype", "dob", "cage", "rack_location", "notes", "project", "owner_pi", "requisition_number", "cost_center"]:
        if field in payload and payload[field] is not None:
            value = payload[field].strip() if isinstance(payload[field], str) else payload[field]
            setattr(mouse, field, value)
    if "strain" in payload and payload["strain"]:
        mouse.group_type = infer_group_type_from_label(payload["strain"])
        mouse.strain = canonical_mouse_label(
            str(payload["strain"]).strip(),
            mouse.group_type,
        )
    if "gender" in payload and payload["gender"]:
        mouse.gender = normalize_gender(payload["gender"])
    if "training" in payload:
        mouse.training = bool(payload["training"])
    if "animal_count" in payload:
        value = str(payload.get("animal_count") or "").strip()
        mouse.animal_count = int(value) if value.isdigit() else None
    if "dob" in payload:
        mouse.dob = normalize_date(payload.get("dob") or "") or str(payload.get("dob") or "")
    if "cage" in payload:
        mouse.cage = normalize_text_value(payload.get("cage") or "")
    if "species" in payload:
        mouse.species = normalize_species(payload.get("species") or "")
    mouse.protocol_number = DEFAULT_PROTOCOL_NUMBER
    mouse.room = DEFAULT_ROOM
    mouse.vendor = None
    mouse.weight = None
    mouse.species = mouse.species or "Mouse"
    mouse.age = calculate_age_from_dob(mouse.dob)

    db.session.commit()
    return jsonify(serialize_mouse(mouse))


@app.route("/api/mice/<int:mouse_id>", methods=["DELETE"])
@api_login_required
def api_archive_mouse(mouse_id):
    mouse = Mouse.query.get_or_404(mouse_id)
    mouse.is_active = False
    mouse.deleted_at = datetime.now().isoformat(timespec="seconds")
    log_action("archive", "mouse", mouse.id, f"Archived by mobile/API from cage {mouse.cage}")
    db.session.commit()
    return jsonify({"status": "archived", "mouse": serialize_mouse(mouse)})


@app.route("/api/cage-card/parse", methods=["POST"])
@api_login_required
def api_parse_cage_card():
    payload = request.get_json(silent=True) or {}
    raw_text = str(payload.get("text") or "").strip()
    if not raw_text:
        return jsonify({"error": "No OCR text was provided."}), 400

    parsed = extract_cage_card_fields(raw_text)
    matches = []

    if parsed["mouse_id"]:
        mouse = Mouse.query.get(parsed["mouse_id"])
        if mouse:
            matches = [mouse]
    elif parsed["editor"]["cage"]:
        matches = active_mouse_query().filter(Mouse.cage == parsed["editor"]["cage"]).order_by(Mouse.id.desc()).all()

    return jsonify(
        {
            "raw_text": parsed["raw_text"],
            "fields": parsed["fields"],
            "confidence": parsed["overall_confidence"],
            "overall_confidence": parsed["overall_confidence"],
            "editor": parsed["editor"],
            "warnings": parsed["warnings"],
            "matches": [serialize_mouse(mouse) for mouse in matches],
        }
    )


@app.route("/api/cage-card/scan-image", methods=["POST"])
@api_login_required
def api_scan_cage_card_image():
    image_file = request.files.get("image")
    if not image_file:
        return jsonify({"error": "No image file was uploaded."}), 400

    try:
        ocr_result = ocr_uploaded_image(image_file)
    except Exception as error:
        return jsonify({"error": str(error)}), 400

    parsed = extract_cage_card_fields(ocr_result["raw_text"], diagnostics=ocr_result["diagnostics"])
    matches = []

    if parsed["mouse_id"]:
        mouse = Mouse.query.get(parsed["mouse_id"])
        if mouse:
            matches = [mouse]
    elif parsed["editor"]["cage"]:
        matches = active_mouse_query().filter(Mouse.cage == parsed["editor"]["cage"]).order_by(Mouse.id.desc()).all()

    return jsonify(
        {
            "raw_text": parsed["raw_text"],
            "fields": parsed["fields"],
            "confidence": parsed["overall_confidence"],
            "overall_confidence": parsed["overall_confidence"],
            "editor": parsed["editor"],
            "warnings": parsed["warnings"],
            "matches": [serialize_mouse(mouse) for mouse in matches],
            "image_preview": ocr_result["original_preview"],
            "processed_preview": ocr_result["processed_preview"],
        }
    )


@app.route("/api/breeding")
@api_login_required
def api_breeding():
    records = Breeding.query.order_by(Breeding.pair_date.desc()).all()
    return jsonify([serialize_breeding(record) for record in records])


@app.errorhandler(404)
def not_found(_error):
    return render_template("404.html"), 404


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
