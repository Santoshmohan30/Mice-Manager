from extensions import db

class Mouse(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    strain = db.Column(db.String(100), nullable=False)
    group_type = db.Column(db.String(30), default="genetic_strain")
    gender = db.Column(db.String(10), nullable=False)
    genotype = db.Column(db.String(50), nullable=False)
    dob = db.Column(db.String(20), nullable=False)
    cage = db.Column(db.String(20), nullable=False)
    rack_location = db.Column(db.String(50))
    notes = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    deleted_at = db.Column(db.String(30))

    # ✅ NEW FIELDS
    training = db.Column(db.Boolean, default=False)  # Is this mouse for training?
    project = db.Column(db.String(100))              # Project the mouse is part of
    owner_pi = db.Column(db.String(120))
    protocol_number = db.Column(db.String(60))
    animal_count = db.Column(db.Integer)
    received_date = db.Column(db.String(20))
    vendor = db.Column(db.String(120))
    age = db.Column(db.String(40))
    weight = db.Column(db.String(40))
    species = db.Column(db.String(40))
    room = db.Column(db.String(80))
    requisition_number = db.Column(db.String(60))
    cost_center = db.Column(db.String(80))

    def __repr__(self):
        return f"<Mouse {self.id} | {self.strain} | {self.gender}>"
