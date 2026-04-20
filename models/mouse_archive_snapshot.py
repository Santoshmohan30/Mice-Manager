from extensions import db


class MouseArchiveSnapshot(db.Model):
    __tablename__ = "mouse_archive_snapshot"

    id = db.Column(db.Integer, primary_key=True)
    source_mouse_id = db.Column(db.Integer, nullable=False, index=True)
    archived_at = db.Column(db.String(30), nullable=False)
    archived_by = db.Column(db.String(50), nullable=False)
    archive_reason = db.Column(db.String(120))
    strain = db.Column(db.String(100))
    cage = db.Column(db.String(20))
    snapshot_json = db.Column(db.Text, nullable=False)
    restored_at = db.Column(db.String(30))
    restored_by = db.Column(db.String(50))

    def __repr__(self):
        return f"<MouseArchiveSnapshot mouse={self.source_mouse_id} archived_at={self.archived_at}>"
