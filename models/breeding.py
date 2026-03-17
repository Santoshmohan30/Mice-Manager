from extensions import db
from datetime import datetime, timedelta

class Breeding(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    male_id = db.Column(db.Integer, nullable=False)
    female_id = db.Column(db.Integer, nullable=False)
    pair_date = db.Column(db.String(20), nullable=False)        # When breeding pair was set
    litter_count = db.Column(db.Integer, nullable=True)          # Number of pups born
    litter_date = db.Column(db.String(20), nullable=True)        # Actual date pups were born
    wean_date = db.Column(db.String(20), nullable=True)          # Actual date of weaning
    notes = db.Column(db.Text)                                   # Additional notes

    def __repr__(self):
        return f"<Breeding Pair {self.male_id} x {self.female_id} on {self.pair_date}>"

    @property
    def estimated_weaning_date(self):
        """Estimate weaning based on pair date (21 days later)."""
        try:
            return (datetime.strptime(self.pair_date, "%Y-%m-%d") + timedelta(days=21)).strftime("%Y-%m-%d")
        except:
            return "Invalid"

    @property
    def status(self):
        """
        Dynamically calculate current breeding status.
        """
        try:
            if self.wean_date:
                return "Weaned"
            elif self.litter_date:
                wean_due = datetime.strptime(self.litter_date, "%Y-%m-%d") + timedelta(days=21)
                if datetime.now() < wean_due:
                    return "Litter Growing"
                else:
                    return "Weaning Due"
            else:
                return "Pregnant"
        except:
            return "Unknown"

    @property
    def weaning_date(self):
        """
        Final weaning date to display:
        - If actual `wean_date` is set, use that
        - Else estimate from `litter_date` (+21 days)
        - Else estimate from `pair_date` (+42 days)
        """
        try:
            if self.wean_date:
                return self.wean_date
            elif self.litter_date:
                return (datetime.strptime(self.litter_date, "%Y-%m-%d") + timedelta(days=21)).strftime("%Y-%m-%d")
            elif self.pair_date:
                return (datetime.strptime(self.pair_date, "%Y-%m-%d") + timedelta(days=42)).strftime("%Y-%m-%d")
            else:
                return "Unknown"
        except:
            return "Invalid"
