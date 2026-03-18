from extensions import db

class CageTransfer(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    mouse_id = db.Column(db.Integer, db.ForeignKey('mouse.id'), nullable=False)
    date = db.Column(db.String(20), nullable=False)
    new_cage = db.Column(db.String(20), nullable=False)

    def __repr__(self):
        return f"<CageTransfer Mouse {self.mouse_id} ➝ {self.new_cage} on {self.date}>"

