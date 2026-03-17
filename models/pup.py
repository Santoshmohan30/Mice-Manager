from extensions import db
from datetime import date, timedelta

class Pup(db.Model):
    __tablename__ = 'pup'

    id = db.Column(db.Integer, primary_key=True)
    breeding_id = db.Column(db.Integer, db.ForeignKey('breeding.id'), nullable=False)

    sex = db.Column(db.String(1), nullable=False)  # 'M' or 'F'
    genotype = db.Column(db.String(50))
    birth_date = db.Column(db.Date, nullable=False)
    notes = db.Column(db.Text)

    # Relationship back to breeding record
    breeding = db.relationship('Breeding', backref=db.backref('pups', lazy=True))

    @property
    def weaning_due(self):
        """Returns True if pup is >= 21 days old."""
        if self.birth_date:
            return date.today() >= self.birth_date + timedelta(days=21)
        return False

    def __repr__(self):
        return f"<Pup {self.id}: Sex={self.sex}, Genotype={self.genotype}>"
