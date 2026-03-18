from extensions import db  

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password = db.Column(db.String(128), nullable=False)
    role = db.Column(db.String(20), default='viewer')  # viewer, admin, tech

    def __repr__(self):
        return f"<User {self.username} ({self.role})>"
