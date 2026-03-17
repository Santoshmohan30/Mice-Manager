from extensions import db  

class Mouse(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    strain = db.Column(db.String(100), nullable=False)
    gender = db.Column(db.String(10), nullable=False)
    genotype = db.Column(db.String(50), nullable=False)
    dob = db.Column(db.String(20), nullable=False)
    cage = db.Column(db.String(20), nullable=False)
    notes = db.Column(db.Text)

    # NEW FIELDS
    training = db.Column(db.Boolean, default=False)  # Is this mouse for training?
    project = db.Column(db.String(100))              # Project the mouse is part of

    def __repr__(self):
        return f"<Mouse {self.id} | {self.strain} | {self.gender}>"
