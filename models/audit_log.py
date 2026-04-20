from extensions import db


class AuditLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    created_at = db.Column(db.String(30), nullable=False)
    username = db.Column(db.String(50), nullable=False)
    level = db.Column(db.String(20), nullable=False, default="INFO")
    action = db.Column(db.String(100), nullable=False)
    entity_type = db.Column(db.String(50), nullable=False)
    entity_id = db.Column(db.String(50), nullable=False)
    request_id = db.Column(db.String(40))
    method = db.Column(db.String(10))
    path = db.Column(db.String(255))
    status_code = db.Column(db.Integer)
    remote_addr = db.Column(db.String(64))
    details = db.Column(db.Text)

    def __repr__(self):
        return f"<AuditLog {self.action} {self.entity_type}:{self.entity_id}>"
