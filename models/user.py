from extensions import db  

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default='viewer')  # viewer, admin, tech
    must_change_password = db.Column(db.Boolean, default=False)
    failed_login_attempts = db.Column(db.Integer, default=0)
    locked_until = db.Column(db.String(30))
    last_login_at = db.Column(db.String(30))

    def __repr__(self):
        return f"<User {self.username} ({self.role})>"
