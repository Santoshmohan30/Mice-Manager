from extensions import db

class CalendarEvent(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    date = db.Column(db.String(20), nullable=False)
    category = db.Column(db.String(50))  # e.g., "Weaning", "Surgery", "Injection"
    notes = db.Column(db.Text)

    def __repr__(self):
        return f"<Event {self.title} on {self.date}>"
