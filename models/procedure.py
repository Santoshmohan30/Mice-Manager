from extensions import db  

class Procedure(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    mouse_id = db.Column(db.Integer, db.ForeignKey('mouse.id'), nullable=False)
    type = db.Column(db.String(50), nullable=False)  # e.g., "Surgery", "Injection"
    date = db.Column(db.String(20), nullable=False)
    notes = db.Column(db.Text)

    def __repr__(self):
        return f"<Procedure {self.type} for Mouse {self.mouse_id} on {self.date}>"

