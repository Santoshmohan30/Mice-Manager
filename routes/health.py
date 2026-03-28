from datetime import datetime

from flask import Blueprint, current_app, jsonify
from sqlalchemy import text

from extensions import db


health_blueprint = Blueprint("health", __name__)


@health_blueprint.get("/health")
def health():
    return jsonify(
        {
            "status": "ok",
            "service": "mice-manager",
            "time": datetime.utcnow().isoformat(timespec="seconds") + "Z",
        }
    )


@health_blueprint.get("/ready")
def ready():
    try:
        db.session.execute(text("SELECT 1"))
        return jsonify(
            {
                "status": "ready",
                "database": "ok",
                "time": datetime.utcnow().isoformat(timespec="seconds") + "Z",
            }
        )
    except Exception as error:
        current_app.logger.exception("Readiness check failed")
        return jsonify({"status": "not_ready", "database": "error", "error": str(error)}), 503
