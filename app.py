from flask import Flask, render_template, redirect, url_for, request, flash
from extensions import db, migrate
import os
from datetime import datetime
from flask import Response
import csv
import io

# Initialize app
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'mice-secret-key')
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mice.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

@app.context_processor
def inject_now():
    return {'now': datetime.now}


# Bind extensions to app
db.init_app(app)
migrate.init_app(app, db)

# Import models AFTER db.init_app to avoid circular imports
from models import Mouse, Weight, CageTransfer, Procedure, Breeding, Pup, User, CalendarEvent

# -------------------- DASHBOARD --------------------
@app.route('/')
def home():
    return redirect(url_for('dashboard'))

@app.route('/dashboard')
def dashboard():
    mice = Mouse.query.all()
    total_mice = len(mice)

    grouped_mice = {}
    for mouse in mice:
        if mouse.strain not in grouped_mice:
            grouped_mice[mouse.strain] = []
        grouped_mice[mouse.strain].append(mouse)

    return render_template("dashboard.html", grouped_mice=grouped_mice, total_mice=total_mice)

@app.route('/add_strain', methods=['GET', 'POST'])
def add_strain():
    if request.method == 'POST':
        strain = request.form['strain']
        flash(f'New strain "{strain}" added.', 'success')
        return redirect(url_for('dashboard'))
    return render_template('add_strain.html')


# -------------------- MICE --------------------
@app.route('/mice')
def mice_list():
    strain_filter = request.args.get('strain')
    gender_filter = request.args.get('gender')
    genotype_filter = request.args.get('genotype')
    dob_start = request.args.get('dob_start')
    dob_end = request.args.get('dob_end')
    sort_dob = request.args.get('sort_dob')

    query = Mouse.query

    if strain_filter:
        query = query.filter_by(strain=strain_filter)
    if gender_filter:
        query = query.filter_by(gender=gender_filter)
    if genotype_filter:
        query = query.filter_by(genotype=genotype_filter)
    if dob_start:
        query = query.filter(Mouse.dob >= dob_start)
    if dob_end:
        query = query.filter(Mouse.dob <= dob_end)

    if sort_dob == 'asc':
        query = query.order_by(Mouse.dob.asc())
    elif sort_dob == 'desc':
        query = query.order_by(Mouse.dob.desc())

    mice = query.all()

    strains = [s[0] for s in db.session.query(Mouse.strain).distinct()]
    genders = [g[0] for g in db.session.query(Mouse.gender).distinct()]
    genotypes = [g[0] for g in db.session.query(Mouse.genotype).distinct()]

    return render_template('mice.html', mice=mice,
                           strains=strains,
                           genders=genders,
                           genotypes=genotypes)

@app.route('/add_mouse', methods=['GET', 'POST'])
def add_mouse():
    if request.method == 'POST':
        new_mouse = Mouse(
            strain=request.form['strain'],
            gender=request.form['gender'],
            genotype=request.form['genotype'],
            dob=request.form['dob'],
            cage=request.form['cage'],
            notes=request.form.get('notes', ''),
            training='training' in request.form,
            project=request.form.get('project', '')
        )
        db.session.add(new_mouse)
        db.session.commit()
        flash("Mouse added successfully", "success")
        return redirect(url_for('mice_list'))
    return render_template('add_mouse.html')

@app.route('/edit_mouse/<int:id>', methods=['GET', 'POST'])
def edit_mouse(id):
    mouse = Mouse.query.get_or_404(id)
    if request.method == 'POST':
        mouse.strain = request.form['strain']
        mouse.gender = request.form['gender']
        mouse.genotype = request.form['genotype']
        mouse.dob = request.form['dob']
        mouse.cage = request.form['cage']
        mouse.notes = request.form.get('notes', '')
        db.session.commit()
        flash('Mouse updated.', 'success')
        return redirect(url_for('mice_list'))
    return render_template('edit_mouse.html', mouse=mouse)


# -------------------- CAGE TRANSFER --------------------
@app.route('/cage_transfer/<int:mouse_id>', methods=['GET', 'POST'])
def cage_transfer(mouse_id):
    mouse = Mouse.query.get_or_404(mouse_id)
    if request.method == 'POST':
        new_cage = request.form['new_cage']
        transfer = CageTransfer(mouse_id=mouse.id, new_cage=new_cage)
        db.session.add(transfer)
        mouse.cage = new_cage
        db.session.commit()
        flash("Cage transfer logged", "info")
        return redirect(url_for('mice_list'))
    return render_template('cage_transfer.html', mouse=mouse)


# -------------------- BREEDING --------------------
@app.route('/breeding')
def breeding_log():
    records = Breeding.query.order_by(Breeding.pair_date.desc()).all()
    return render_template('breeding.html', records=records)

@app.route('/breeding/add', methods=['GET', 'POST'])
def add_breeding():
    if request.method == 'POST':
        male_id = request.form['male_id']
        female_id = request.form['female_id']
        pair_date = request.form['pair_date']
        litter_count = request.form.get('litter_count') or None
        litter_date = request.form.get('litter_date') or None
        wean_date = request.form.get('wean_date') or None
        notes = request.form.get('notes') or None

        new_pair = Breeding(
            male_id=male_id,
            female_id=female_id,
            pair_date=pair_date,
            litter_count=litter_count,
            litter_date=litter_date,
            wean_date=wean_date,
            notes=notes
        )
        db.session.add(new_pair)
        db.session.commit()
        flash('Breeding record added.', 'success')
        return redirect(url_for('breeding_log'))

    return render_template('add_breeding.html')

@app.route('/add_pup/<int:breeding_id>', methods=['POST'])
def add_pup(breeding_id):
    sex = request.form.get('sex')
    genotype = request.form.get('genotype')
    from datetime import datetime
    birth_date_str = request.form.get('birth_date')
    birth_date = datetime.strptime(birth_date_str, '%Y-%m-%d').date()
    notes = request.form.get('notes')

    new_pup = Pup(
        breeding_id=breeding_id,
        sex=sex,
        genotype=genotype,
        birth_date=birth_date,
        notes=notes
    )
    db.session.add(new_pup)
    db.session.commit()
    flash('Pup added successfully.', 'success')
    return redirect(url_for('breeding_log'))

# Optional pup list page
@app.route('/pups')
def pup_list():
    pups = Pup.query.order_by(Pup.birth_date.desc()).all()
    return render_template('pup_list.html', pups=pups)
from datetime import date, timedelta

@app.route('/delete_breeding/<int:id>', methods=['POST'])
def delete_breeding(id):
    record = Breeding.query.get_or_404(id)
    db.session.delete(record)
    db.session.commit()
    flash('Breeding record deleted successfully.', 'success')
    return redirect(url_for('breeding_log'))


# -------------------- PROCEDURES --------------------
@app.route('/procedures', methods=['GET', 'POST'])
def procedures():
    if request.method == 'POST':
        procedure = Procedure(
            mouse_id=request.form['mouse_id'],
            type=request.form['type'],
            date=request.form['date'],
            notes=request.form['notes']
        )
        db.session.add(procedure)
        db.session.commit()
        flash("Procedure logged", "info")
        return redirect(url_for('procedures'))
    procedures = Procedure.query.all()
    return render_template('procedures.html', procedures=procedures)


# -------------------- CALENDAR --------------------
@app.route('/calendar')
def calendar_view():
    events = CalendarEvent.query.all()
    return render_template('calendar.html', events=events)

@app.route('/calendar/add', methods=['POST'])
def add_calendar_event():
    title = request.form['title']
    date_val = request.form['date']
    category = request.form['category']
    notes = request.form['notes']
    email = request.form.get('email')

    new_event = CalendarEvent(
        title=title,
        date=date_val,
        category=category,
        notes=notes
    )

    db.session.add(new_event)
    db.session.commit()

    if email and email.endswith('@buffalo.edu'):
        print(f"Notify: {email} - Event added: {title} on {date_val}")

    flash("Calendar event added!", "success")
    return redirect(url_for('calendar_view'))

@app.route('/calendar/delete/<int:event_id>', methods=['POST'])
def delete_calendar_event(event_id):
    event = CalendarEvent.query.get_or_404(event_id)
    db.session.delete(event)
    db.session.commit()
    flash("Event deleted.", "danger")
    return redirect(url_for('calendar_view'))


# -------------------- MISC --------------------
@app.route('/delete_mouse/<int:id>', methods=['POST'])
def delete_mouse(id):
    mouse = Mouse.query.get_or_404(id)
    db.session.delete(mouse)
    db.session.commit()
    flash('Mouse deleted. Cage reusable.', 'success')
    return redirect(url_for('mice_list'))

@app.route('/export/<table>')
def export_csv(table):
    from models import Mouse, CageTransfer, Procedure, Breeding, Pup  # import models here

    output = io.StringIO()
    writer = csv.writer(output)

    if table == 'mice':
        writer.writerow(['ID', 'Strain', 'Gender', 'Genotype', 'Cage', 'DOB', 'Notes'])
        for mouse in Mouse.query.all():
            writer.writerow([mouse.id, mouse.strain, mouse.gender, mouse.genotype, mouse.cage, mouse.dob, mouse.notes])

    elif table == 'pups':
        writer.writerow(['ID', 'Breeding ID', 'Gender', 'Genotype', 'DOB', 'Notes'])
        for pup in Pup.query.all():
            writer.writerow([pup.id, pup.breeding_id, pup.gender, pup.genotype, pup.dob, pup.notes])

    elif table == 'breeding':
        writer.writerow(['ID', 'Male ID', 'Female 1 ID', 'Female 2 ID', 'Start Date', 'End Date', 'Status'])
        for b in Breeding.query.all():
            writer.writerow([b.id, b.male_id, b.female1_id, b.female2_id, b.start_date, b.end_date, b.status])

    else:
        return "Invalid table name", 400

    response = Response(output.getvalue(), mimetype='text/csv')
    response.headers['Content-Disposition'] = f'attachment; filename={table}_data.csv'
    return response

# -------------------- ERROR HANDLING --------------------
@app.errorhandler(404)
def not_found(e):
    return render_template("404.html"), 404


# -------------------- RUN APP --------------------
if __name__ == '__main__':
    app.run(debug=True) 