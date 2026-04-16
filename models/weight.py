from extensions import db  

class Weight(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    mouse_id = db.Column(db.Integer, db.ForeignKey('mouse.id'), nullable=False)
    date = db.Column(db.String(20), nullable=False)
    weight = db.Column(db.Float, nullable=False)
    food_given = db.Column(db.Float, nullable=True)
    person_performing = db.Column(db.String(120))
    condition = db.Column(db.String(120))
    notes = db.Column(db.Text)

    def __repr__(self):
        return f"<WeightLog Mouse {self.mouse_id} | {self.date} | {self.weight}g>"
