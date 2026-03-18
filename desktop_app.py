import sys
import os
from datetime import datetime, timedelta
from PyQt5.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                             QHBoxLayout, QTabWidget, QTableWidget, QTableWidgetItem,
                             QPushButton, QLabel, QLineEdit, QComboBox, QDateEdit,
                             QTextEdit, QMessageBox, QDialog, QFormLayout, QSpinBox,
                             QGroupBox, QGridLayout, QHeaderView, QSplitter)
from PyQt5.QtCore import Qt, QDate, pyqtSignal
from PyQt5.QtGui import QFont, QIcon
import sqlite3
from sqlalchemy import create_engine, text, MetaData
from sqlalchemy.orm import sessionmaker, scoped_session
from sqlalchemy.ext.declarative import declarative_base

# Create a standalone database setup for desktop app
Base = declarative_base()

# Import desktop-specific models that match actual database schema
from desktop_models import Mouse, Breeding, Procedure, CalendarEvent, Pup, User, Weight, CageTransfer

class MiceManagerDesktop(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Mice Manager - Desktop Application")
        self.setGeometry(100, 100, 1200, 800)
        
        # Initialize database
        self.init_database()
        
        # Create main widget and layout
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        layout = QVBoxLayout(main_widget)
        
        # Create title
        title = QLabel("Mice Manager")
        title.setFont(QFont("Arial", 24, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        # Create tab widget
        self.tabs = QTabWidget()
        layout.addWidget(self.tabs)
        
        # Create tabs
        self.create_dashboard_tab()
        self.create_mice_tab()
        self.create_breeding_tab()
        self.create_procedures_tab()
        self.create_calendar_tab()
        
        # Load initial data
        self.load_dashboard_data()
        self.load_mice_data()
        self.load_breeding_data()
        self.load_procedures_data()
        self.load_calendar_data()
    
    def init_database(self):
        """Initialize database connection"""
        try:
            # Use the same database as Flask app (in instance folder)
            db_path = os.path.join(os.path.dirname(__file__), 'instance', 'mice.db')
            
            # Create engine
            self.engine = create_engine(f'sqlite:///{db_path}')
            
            # Create session factory
            session_factory = sessionmaker(bind=self.engine)
            self.session = scoped_session(session_factory)
            
            # Create tables if they don't exist
            Base.metadata.create_all(self.engine)
            
            print(f"Database connected: {db_path}")
            
        except Exception as e:
            QMessageBox.critical(self, "Database Error", f"Failed to connect to database: {str(e)}")
            print(f"Database error: {str(e)}")
    
    def create_dashboard_tab(self):
        """Create dashboard tab with overview statistics"""
        dashboard_widget = QWidget()
        layout = QVBoxLayout(dashboard_widget)
        
        # Statistics group
        stats_group = QGroupBox("Statistics")
        stats_layout = QGridLayout(stats_group)
        
        self.total_mice_label = QLabel("Total Mice: 0")
        self.total_mice_label.setFont(QFont("Arial", 14, QFont.Bold))
        stats_layout.addWidget(self.total_mice_label, 0, 0)
        
        self.active_breeding_label = QLabel("Active Breeding Pairs: 0")
        self.active_breeding_label.setFont(QFont("Arial", 14, QFont.Bold))
        stats_layout.addWidget(self.active_breeding_label, 0, 1)
        
        self.upcoming_events_label = QLabel("Upcoming Events: 0")
        self.upcoming_events_label.setFont(QFont("Arial", 14, QFont.Bold))
        stats_layout.addWidget(self.upcoming_events_label, 0, 2)
        
        layout.addWidget(stats_group)
        
        # Quick actions
        actions_group = QGroupBox("Quick Actions")
        actions_layout = QHBoxLayout(actions_group)
        
        add_mouse_btn = QPushButton("Add New Mouse")
        add_mouse_btn.clicked.connect(self.show_add_mouse_dialog)
        actions_layout.addWidget(add_mouse_btn)
        
        add_breeding_btn = QPushButton("Add Breeding Pair")
        add_breeding_btn.clicked.connect(self.show_add_breeding_dialog)
        actions_layout.addWidget(add_breeding_btn)
        
        add_event_btn = QPushButton("Add Calendar Event")
        add_event_btn.clicked.connect(self.show_add_event_dialog)
        actions_layout.addWidget(add_event_btn)
        
        layout.addWidget(actions_group)
        
        # Recent activity
        recent_group = QGroupBox("Recent Activity")
        recent_layout = QVBoxLayout(recent_group)
        
        self.recent_table = QTableWidget()
        self.recent_table.setColumnCount(4)
        self.recent_table.setHorizontalHeaderLabels(["Date", "Action", "Details", "User"])
        recent_layout.addWidget(self.recent_table)
        
        layout.addWidget(recent_group)
        
        self.tabs.addTab(dashboard_widget, "Dashboard")
    
    def create_mice_tab(self):
        """Create mice management tab"""
        mice_widget = QWidget()
        layout = QVBoxLayout(mice_widget)
        
        # Search/filter controls
        filter_group = QGroupBox("Search & Filter")
        filter_layout = QHBoxLayout(filter_group)
        
        self.strain_filter = QComboBox()
        self.strain_filter.addItem("All Strains")
        filter_layout.addWidget(QLabel("Strain:"))
        filter_layout.addWidget(self.strain_filter)
        
        self.gender_filter = QComboBox()
        self.gender_filter.addItems(["All", "Male", "Female"])
        filter_layout.addWidget(QLabel("Gender:"))
        filter_layout.addWidget(self.gender_filter)
        
        filter_btn = QPushButton("Apply Filters")
        filter_btn.clicked.connect(self.load_mice_data)
        filter_layout.addWidget(filter_btn)
        
        layout.addWidget(filter_group)
        
        # Mice table
        self.mice_table = QTableWidget()
        self.mice_table.setColumnCount(9)
        self.mice_table.setHorizontalHeaderLabels([
            "ID", "Strain", "Gender", "Genotype", "DOB", "Cage", "Training", "Project", "Actions"
        ])
        self.mice_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.mice_table)
        
        # Action buttons
        buttons_layout = QHBoxLayout()
        
        add_mouse_btn = QPushButton("Add Mouse")
        add_mouse_btn.clicked.connect(self.show_add_mouse_dialog)
        buttons_layout.addWidget(add_mouse_btn)
        
        edit_mouse_btn = QPushButton("Edit Selected")
        edit_mouse_btn.clicked.connect(self.edit_selected_mouse)
        buttons_layout.addWidget(edit_mouse_btn)
        
        delete_mouse_btn = QPushButton("Delete Selected")
        delete_mouse_btn.clicked.connect(self.delete_selected_mouse)
        buttons_layout.addWidget(delete_mouse_btn)
        
        layout.addLayout(buttons_layout)
        
        self.tabs.addTab(mice_widget, "Mice")
    
    def create_breeding_tab(self):
        """Create breeding management tab"""
        breeding_widget = QWidget()
        layout = QVBoxLayout(breeding_widget)
        
        # Breeding table
        self.breeding_table = QTableWidget()
        self.breeding_table.setColumnCount(7)
        self.breeding_table.setHorizontalHeaderLabels([
            "ID", "Male", "Female", "Pair Date", "Litter Date", "Status", "Actions"
        ])
        self.breeding_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.breeding_table)
        
        # Action buttons
        buttons_layout = QHBoxLayout()
        
        add_breeding_btn = QPushButton("Add Breeding Pair")
        add_breeding_btn.clicked.connect(self.show_add_breeding_dialog)
        buttons_layout.addWidget(add_breeding_btn)
        
        delete_breeding_btn = QPushButton("Delete Selected")
        delete_breeding_btn.clicked.connect(self.delete_selected_breeding)
        buttons_layout.addWidget(delete_breeding_btn)
        
        layout.addLayout(buttons_layout)
        
        self.tabs.addTab(breeding_widget, "Breeding")
    
    def create_procedures_tab(self):
        """Create procedures management tab"""
        procedures_widget = QWidget()
        layout = QVBoxLayout(procedures_widget)
        
        # Procedures table
        self.procedures_table = QTableWidget()
        self.procedures_table.setColumnCount(6)
        self.procedures_table.setHorizontalHeaderLabels([
            "ID", "Mouse ID", "Type", "Date", "Notes", "Actions"
        ])
        self.procedures_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.procedures_table)
        
        # Action buttons
        buttons_layout = QHBoxLayout()
        
        add_procedure_btn = QPushButton("Add Procedure")
        add_procedure_btn.clicked.connect(self.show_add_procedure_dialog)
        buttons_layout.addWidget(add_procedure_btn)
        
        delete_procedure_btn = QPushButton("Delete Selected")
        delete_procedure_btn.clicked.connect(self.delete_selected_procedure)
        buttons_layout.addWidget(delete_procedure_btn)
        
        layout.addLayout(buttons_layout)
        
        self.tabs.addTab(procedures_widget, "Procedures")
    
    def create_calendar_tab(self):
        """Create calendar management tab"""
        calendar_widget = QWidget()
        layout = QVBoxLayout(calendar_widget)
        
        # Calendar events table
        self.calendar_table = QTableWidget()
        self.calendar_table.setColumnCount(5)
        self.calendar_table.setHorizontalHeaderLabels([
            "ID", "Title", "Date", "Category", "Actions"
        ])
        self.calendar_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.calendar_table)
        
        # Action buttons
        buttons_layout = QHBoxLayout()
        
        add_event_btn = QPushButton("Add Event")
        add_event_btn.clicked.connect(self.show_add_event_dialog)
        buttons_layout.addWidget(add_event_btn)
        
        delete_event_btn = QPushButton("Delete Selected")
        delete_event_btn.clicked.connect(self.delete_selected_event)
        buttons_layout.addWidget(delete_event_btn)
        
        layout.addLayout(buttons_layout)
        
        self.tabs.addTab(calendar_widget, "Calendar")
    
    def load_dashboard_data(self):
        """Load dashboard statistics"""
        try:
            # Total mice
            total_mice = self.session.query(Mouse).count()
            self.total_mice_label.setText(f"Total Mice: {total_mice}")
            
            # Active breeding pairs
            active_breeding = self.session.query(Breeding).filter(
                Breeding.litter_date.is_(None)
            ).count()
            self.active_breeding_label.setText(f"Active Breeding Pairs: {active_breeding}")
            
            # Upcoming events (next 7 days)
            today = datetime.now().date()
            upcoming_events = self.session.query(CalendarEvent).filter(
                CalendarEvent.date >= today,
                CalendarEvent.date <= today + timedelta(days=7)
            ).count()
            self.upcoming_events_label.setText(f"Upcoming Events: {upcoming_events}")
            
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load dashboard data: {str(e)}")
    
    def load_mice_data(self):
        """Load mice data into table"""
        try:
            query = self.session.query(Mouse)
            
            # Apply filters
            strain_filter = self.strain_filter.currentText()
            if strain_filter != "All Strains":
                query = query.filter(Mouse.strain == strain_filter)
            
            gender_filter = self.gender_filter.currentText()
            if gender_filter != "All":
                query = query.filter(Mouse.gender == gender_filter)
            
            mice = query.all()
            
            self.mice_table.setRowCount(len(mice))
            
            for i, mouse in enumerate(mice):
                self.mice_table.setItem(i, 0, QTableWidgetItem(str(mouse.id)))
                self.mice_table.setItem(i, 1, QTableWidgetItem(mouse.strain or ""))
                self.mice_table.setItem(i, 2, QTableWidgetItem(mouse.gender or ""))
                self.mice_table.setItem(i, 3, QTableWidgetItem(mouse.genotype or ""))
                self.mice_table.setItem(i, 4, QTableWidgetItem(mouse.dob or ""))
                self.mice_table.setItem(i, 5, QTableWidgetItem(mouse.cage or ""))
                self.mice_table.setItem(i, 6, QTableWidgetItem("Yes" if mouse.training else "No"))
                self.mice_table.setItem(i, 7, QTableWidgetItem(mouse.project or ""))
                
                # Action buttons
                actions_widget = QWidget()
                actions_layout = QHBoxLayout(actions_widget)
                
                edit_btn = QPushButton("Edit")
                edit_btn.clicked.connect(lambda checked, m=mouse: self.edit_mouse(m))
                actions_layout.addWidget(edit_btn)
                
                delete_btn = QPushButton("Delete")
                delete_btn.clicked.connect(lambda checked, m=mouse: self.delete_mouse(m))
                actions_layout.addWidget(delete_btn)
                
                self.mice_table.setCellWidget(i, 8, actions_widget)
            
            # Update strain filter options
            strains = [s[0] for s in self.session.query(Mouse.strain).distinct()]
            current_strain = self.strain_filter.currentText()
            self.strain_filter.clear()
            self.strain_filter.addItem("All Strains")
            self.strain_filter.addItems(strains)
            if current_strain in strains:
                self.strain_filter.setCurrentText(current_strain)
                
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load mice data: {str(e)}")
    
    def load_breeding_data(self):
        """Load breeding data into table"""
        try:
            breedings = self.session.query(Breeding).all()
            
            self.breeding_table.setRowCount(len(breedings))
            
            for i, breeding in enumerate(breedings):
                self.breeding_table.setItem(i, 0, QTableWidgetItem(str(breeding.id)))
                
                # Get mouse details
                male = self.session.query(Mouse).get(breeding.male_id)
                female = self.session.query(Mouse).get(breeding.female_id)
                
                male_text = f"{male.strain} (ID: {male.id})" if male else "Unknown"
                female_text = f"{female.strain} (ID: {female.id})" if female else "Unknown"
                
                self.breeding_table.setItem(i, 1, QTableWidgetItem(male_text))
                self.breeding_table.setItem(i, 2, QTableWidgetItem(female_text))
                self.breeding_table.setItem(i, 3, QTableWidgetItem(str(breeding.pair_date)))
                self.breeding_table.setItem(i, 4, QTableWidgetItem(str(breeding.litter_date) if breeding.litter_date else "Pending"))
                
                status = "Active" if not breeding.litter_date else "Completed"
                self.breeding_table.setItem(i, 5, QTableWidgetItem(status))
                
                # Action buttons
                actions_widget = QWidget()
                actions_layout = QHBoxLayout(actions_widget)
                
                delete_btn = QPushButton("Delete")
                delete_btn.clicked.connect(lambda checked, b=breeding: self.delete_breeding(b))
                actions_layout.addWidget(delete_btn)
                
                self.breeding_table.setCellWidget(i, 6, actions_widget)
                
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load breeding data: {str(e)}")
    
    def load_procedures_data(self):
        """Load procedures data into table"""
        try:
            procedures = self.session.query(Procedure).all()
            
            self.procedures_table.setRowCount(len(procedures))
            
            for i, procedure in enumerate(procedures):
                self.procedures_table.setItem(i, 0, QTableWidgetItem(str(procedure.id)))
                self.procedures_table.setItem(i, 1, QTableWidgetItem(str(procedure.mouse_id)))
                self.procedures_table.setItem(i, 2, QTableWidgetItem(procedure.type))
                self.procedures_table.setItem(i, 3, QTableWidgetItem(str(procedure.date)))
                self.procedures_table.setItem(i, 4, QTableWidgetItem(procedure.notes))
                
                # Action buttons
                actions_widget = QWidget()
                actions_layout = QHBoxLayout(actions_widget)
                
                delete_btn = QPushButton("Delete")
                delete_btn.clicked.connect(lambda checked, p=procedure: self.delete_procedure(p))
                actions_layout.addWidget(delete_btn)
                
                self.procedures_table.setCellWidget(i, 5, actions_widget)
                
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load procedures data: {str(e)}")
    
    def load_calendar_data(self):
        """Load calendar data into table"""
        try:
            events = self.session.query(CalendarEvent).order_by(CalendarEvent.date).all()
            
            self.calendar_table.setRowCount(len(events))
            
            for i, event in enumerate(events):
                self.calendar_table.setItem(i, 0, QTableWidgetItem(str(event.id)))
                self.calendar_table.setItem(i, 1, QTableWidgetItem(event.title))
                self.calendar_table.setItem(i, 2, QTableWidgetItem(str(event.date)))
                self.calendar_table.setItem(i, 3, QTableWidgetItem(event.category))
                
                # Action buttons
                actions_widget = QWidget()
                actions_layout = QHBoxLayout(actions_widget)
                
                delete_btn = QPushButton("Delete")
                delete_btn.clicked.connect(lambda checked, e=event: self.delete_event(e))
                actions_layout.addWidget(delete_btn)
                
                self.calendar_table.setCellWidget(i, 4, actions_widget)
                
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load calendar data: {str(e)}")
    
    def show_add_mouse_dialog(self):
        """Show dialog to add new mouse"""
        dialog = AddMouseDialog(self.session, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_mice_data()
            self.load_dashboard_data()
    
    def show_add_breeding_dialog(self):
        """Show dialog to add new breeding pair"""
        dialog = AddBreedingDialog(self.session, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_breeding_data()
            self.load_dashboard_data()
    
    def show_add_procedure_dialog(self):
        """Show dialog to add new procedure"""
        dialog = AddProcedureDialog(self.session, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_procedures_data()
    
    def show_add_event_dialog(self):
        """Show dialog to add new calendar event"""
        dialog = AddEventDialog(self.session, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_calendar_data()
            self.load_dashboard_data()
    
    def edit_selected_mouse(self):
        """Edit the selected mouse"""
        current_row = self.mice_table.currentRow()
        if current_row >= 0:
            mouse_id = int(self.mice_table.item(current_row, 0).text())
            mouse = self.session.query(Mouse).get(mouse_id)
            if mouse:
                dialog = EditMouseDialog(mouse, self.session, self)
                if dialog.exec_() == QDialog.Accepted:
                    self.load_mice_data()
    
    def delete_selected_mouse(self):
        """Delete the selected mouse"""
        current_row = self.mice_table.currentRow()
        if current_row >= 0:
            mouse_id = int(self.mice_table.item(current_row, 0).text())
            mouse = self.session.query(Mouse).get(mouse_id)
            if mouse:
                self.delete_mouse(mouse)
    
    def delete_selected_breeding(self):
        """Delete the selected breeding record"""
        current_row = self.breeding_table.currentRow()
        if current_row >= 0:
            breeding_id = int(self.breeding_table.item(current_row, 0).text())
            breeding = self.session.query(Breeding).get(breeding_id)
            if breeding:
                self.delete_breeding(breeding)
    
    def delete_selected_procedure(self):
        """Delete the selected procedure"""
        current_row = self.procedures_table.currentRow()
        if current_row >= 0:
            procedure_id = int(self.procedures_table.item(current_row, 0).text())
            procedure = self.session.query(Procedure).get(procedure_id)
            if procedure:
                self.delete_procedure(procedure)
    
    def delete_selected_event(self):
        """Delete the selected event"""
        current_row = self.calendar_table.currentRow()
        if current_row >= 0:
            event_id = int(self.calendar_table.item(current_row, 0).text())
            event = self.session.query(CalendarEvent).get(event_id)
            if event:
                self.delete_event(event)
    
    def edit_mouse(self, mouse):
        """Edit a specific mouse"""
        dialog = EditMouseDialog(mouse, self.session, self)
        if dialog.exec_() == QDialog.Accepted:
            self.load_mice_data()
    
    def delete_mouse(self, mouse):
        """Delete a specific mouse"""
        reply = QMessageBox.question(self, "Confirm Delete", 
                                   f"Are you sure you want to delete mouse {mouse.id}?",
                                   QMessageBox.Yes | QMessageBox.No)
        if reply == QMessageBox.Yes:
            try:
                self.session.delete(mouse)
                self.session.commit()
                self.load_mice_data()
                self.load_dashboard_data()
                QMessageBox.information(self, "Success", "Mouse deleted successfully")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to delete mouse: {str(e)}")
    
    def delete_breeding(self, breeding):
        """Delete a specific breeding record"""
        reply = QMessageBox.question(self, "Confirm Delete", 
                                   f"Are you sure you want to delete breeding record {breeding.id}?",
                                   QMessageBox.Yes | QMessageBox.No)
        if reply == QMessageBox.Yes:
            try:
                self.session.delete(breeding)
                self.session.commit()
                self.load_breeding_data()
                self.load_dashboard_data()
                QMessageBox.information(self, "Success", "Breeding record deleted successfully")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to delete breeding record: {str(e)}")
    
    def delete_procedure(self, procedure):
        """Delete a specific procedure"""
        reply = QMessageBox.question(self, "Confirm Delete", 
                                   f"Are you sure you want to delete procedure {procedure.id}?",
                                   QMessageBox.Yes | QMessageBox.No)
        if reply == QMessageBox.Yes:
            try:
                self.session.delete(procedure)
                self.session.commit()
                self.load_procedures_data()
                QMessageBox.information(self, "Success", "Procedure deleted successfully")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to delete procedure: {str(e)}")
    
    def delete_event(self, event):
        """Delete a specific event"""
        reply = QMessageBox.question(self, "Confirm Delete", 
                                   f"Are you sure you want to delete event '{event.title}'?",
                                   QMessageBox.Yes | QMessageBox.No)
        if reply == QMessageBox.Yes:
            try:
                self.session.delete(event)
                self.session.commit()
                self.load_calendar_data()
                self.load_dashboard_data()
                QMessageBox.information(self, "Success", "Event deleted successfully")
            except Exception as e:
                QMessageBox.critical(self, "Error", f"Failed to delete event: {str(e)}")


class AddMouseDialog(QDialog):
    def __init__(self, session, parent=None):
        super().__init__(parent)
        self.session = session
        self.setWindowTitle("Add New Mouse")
        self.setModal(True)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        self.strain_edit = QLineEdit()
        layout.addRow("Strain:", self.strain_edit)
        
        self.gender_combo = QComboBox()
        self.gender_combo.addItems(["Male", "Female"])
        layout.addRow("Gender:", self.gender_combo)
        
        self.genotype_edit = QLineEdit()
        layout.addRow("Genotype:", self.genotype_edit)
        
        self.dob_edit = QLineEdit()
        layout.addRow("Date of Birth:", self.dob_edit)
        
        self.cage_edit = QLineEdit()
        layout.addRow("Cage:", self.cage_edit)
        
        self.training_checkbox = QComboBox()
        self.training_checkbox.addItems(["No", "Yes"])
        layout.addRow("Training:", self.training_checkbox)
        
        self.project_edit = QLineEdit()
        layout.addRow("Project:", self.project_edit)
        
        self.notes_edit = QTextEdit()
        self.notes_edit.setMaximumHeight(100)
        layout.addRow("Notes:", self.notes_edit)
        
        # Buttons
        buttons_layout = QHBoxLayout()
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_mouse)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        buttons_layout.addWidget(save_btn)
        buttons_layout.addWidget(cancel_btn)
        layout.addRow(buttons_layout)
    
    def save_mouse(self):
        try:
            new_mouse = Mouse(
                strain=self.strain_edit.text(),
                gender=self.gender_combo.currentText(),
                genotype=self.genotype_edit.text(),
                dob=self.dob_edit.text(),
                cage=self.cage_edit.text(),
                training=self.training_checkbox.currentText() == "Yes",
                project=self.project_edit.text(),
                notes=self.notes_edit.toPlainText()
            )
            
            self.session.add(new_mouse)
            self.session.commit()
            
            QMessageBox.information(self, "Success", "Mouse added successfully")
            self.accept()
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to add mouse: {str(e)}")


class EditMouseDialog(QDialog):
    def __init__(self, mouse, session, parent=None):
        super().__init__(parent)
        self.mouse = mouse
        self.session = session
        self.setWindowTitle(f"Edit Mouse {mouse.id}")
        self.setModal(True)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        self.strain_edit = QLineEdit(self.mouse.strain)
        layout.addRow("Strain:", self.strain_edit)
        
        self.gender_combo = QComboBox()
        self.gender_combo.addItems(["Male", "Female"])
        self.gender_combo.setCurrentText(self.mouse.gender)
        layout.addRow("Gender:", self.gender_combo)
        
        self.genotype_edit = QLineEdit(self.mouse.genotype)
        layout.addRow("Genotype:", self.genotype_edit)
        
        self.cage_edit = QLineEdit(self.mouse.cage)
        layout.addRow("Cage:", self.cage_edit)
        
        self.dob_edit = QDateEdit()
        self.dob_edit.setDate(QDate.fromString(str(self.mouse.dob), "yyyy-MM-dd"))
        layout.addRow("Date of Birth:", self.dob_edit)
        
        self.notes_edit = QTextEdit()
        self.notes_edit.setPlainText(self.mouse.notes or "")
        self.notes_edit.setMaximumHeight(100)
        layout.addRow("Notes:", self.notes_edit)
        
        # Buttons
        buttons_layout = QHBoxLayout()
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_mouse)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        buttons_layout.addWidget(save_btn)
        buttons_layout.addWidget(cancel_btn)
        layout.addRow(buttons_layout)
    
    def save_mouse(self):
        try:
            self.mouse.strain = self.strain_edit.text()
            self.mouse.gender = self.gender_combo.currentText()
            self.mouse.genotype = self.genotype_edit.text()
            self.mouse.cage = self.cage_edit.text()
            self.mouse.dob = self.dob_edit.date().toPyDate()
            self.mouse.notes = self.notes_edit.toPlainText()
            
            self.session.commit()
            
            QMessageBox.information(self, "Success", "Mouse updated successfully")
            self.accept()
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to update mouse: {str(e)}")


class AddBreedingDialog(QDialog):
    def __init__(self, session, parent=None):
        super().__init__(parent)
        self.session = session
        self.setWindowTitle("Add Breeding Pair")
        self.setModal(True)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        # Get available mice for selection
        male_mice = self.session.query(Mouse).filter(Mouse.gender == "Male").all()
        female_mice = self.session.query(Mouse).filter(Mouse.gender == "Female").all()
        
        self.male_combo = QComboBox()
        self.male_combo.addItem("Select Male")
        for mouse in male_mice:
            self.male_combo.addItem(f"{mouse.strain} (ID: {mouse.id})", mouse.id)
        layout.addRow("Male Mouse:", self.male_combo)
        
        self.female_combo = QComboBox()
        self.female_combo.addItem("Select Female")
        for mouse in female_mice:
            self.female_combo.addItem(f"{mouse.strain} (ID: {mouse.id})", mouse.id)
        layout.addRow("Female Mouse:", self.female_combo)
        
        self.pair_date_edit = QDateEdit()
        self.pair_date_edit.setDate(QDate.currentDate())
        layout.addRow("Pair Date:", self.pair_date_edit)
        
        self.notes_edit = QTextEdit()
        self.notes_edit.setMaximumHeight(100)
        layout.addRow("Notes:", self.notes_edit)
        
        # Buttons
        buttons_layout = QHBoxLayout()
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_breeding)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        buttons_layout.addWidget(save_btn)
        buttons_layout.addWidget(cancel_btn)
        layout.addRow(buttons_layout)
    
    def save_breeding(self):
        try:
            male_id = self.male_combo.currentData()
            female_id = self.female_combo.currentData()
            
            if male_id is None or female_id is None:
                QMessageBox.warning(self, "Warning", "Please select both male and female mice")
                return
            
            new_breeding = Breeding(
                male_id=male_id,
                female_id=female_id,
                pair_date=self.pair_date_edit.date().toPyDate(),
                notes=self.notes_edit.toPlainText()
            )
            
            self.session.add(new_breeding)
            self.session.commit()
            
            QMessageBox.information(self, "Success", "Breeding pair added successfully")
            self.accept()
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to add breeding pair: {str(e)}")


class AddProcedureDialog(QDialog):
    def __init__(self, session, parent=None):
        super().__init__(parent)
        self.session = session
        self.setWindowTitle("Add Procedure")
        self.setModal(True)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        # Get available mice for selection
        mice = self.session.query(Mouse).all()
        
        self.mouse_combo = QComboBox()
        self.mouse_combo.addItem("Select Mouse")
        for mouse in mice:
            self.mouse_combo.addItem(f"{mouse.strain} (ID: {mouse.id})", mouse.id)
        layout.addRow("Mouse:", self.mouse_combo)
        
        self.type_edit = QLineEdit()
        layout.addRow("Procedure Type:", self.type_edit)
        
        self.date_edit = QDateEdit()
        self.date_edit.setDate(QDate.currentDate())
        layout.addRow("Date:", self.date_edit)
        
        self.notes_edit = QTextEdit()
        self.notes_edit.setMaximumHeight(100)
        layout.addRow("Notes:", self.notes_edit)
        
        # Buttons
        buttons_layout = QHBoxLayout()
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_procedure)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        buttons_layout.addWidget(save_btn)
        buttons_layout.addWidget(cancel_btn)
        layout.addRow(buttons_layout)
    
    def save_procedure(self):
        try:
            mouse_id = self.mouse_combo.currentData()
            
            if mouse_id is None:
                QMessageBox.warning(self, "Warning", "Please select a mouse")
                return
            
            new_procedure = Procedure(
                mouse_id=mouse_id,
                type=self.type_edit.text(),
                date=self.date_edit.date().toPyDate(),
                notes=self.notes_edit.toPlainText()
            )
            
            self.session.add(new_procedure)
            self.session.commit()
            
            QMessageBox.information(self, "Success", "Procedure added successfully")
            self.accept()
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to add procedure: {str(e)}")


class AddEventDialog(QDialog):
    def __init__(self, session, parent=None):
        super().__init__(parent)
        self.session = session
        self.setWindowTitle("Add Calendar Event")
        self.setModal(True)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout(self)
        
        self.title_edit = QLineEdit()
        layout.addRow("Title:", self.title_edit)
        
        self.date_edit = QDateEdit()
        self.date_edit.setDate(QDate.currentDate())
        layout.addRow("Date:", self.date_edit)
        
        self.category_combo = QComboBox()
        self.category_combo.addItems(["Breeding", "Procedure", "Maintenance", "Other"])
        layout.addRow("Category:", self.category_combo)
        
        self.notes_edit = QTextEdit()
        self.notes_edit.setMaximumHeight(100)
        layout.addRow("Notes:", self.notes_edit)
        
        # Buttons
        buttons_layout = QHBoxLayout()
        save_btn = QPushButton("Save")
        save_btn.clicked.connect(self.save_event)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        
        buttons_layout.addWidget(save_btn)
        buttons_layout.addWidget(cancel_btn)
        layout.addRow(buttons_layout)
    
    def save_event(self):
        try:
            new_event = CalendarEvent(
                title=self.title_edit.text(),
                date=self.date_edit.date().toPyDate(),
                category=self.category_combo.currentText(),
                notes=self.notes_edit.toPlainText()
            )
            
            self.session.add(new_event)
            self.session.commit()
            
            QMessageBox.information(self, "Success", "Event added successfully")
            self.accept()
            
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to add event: {str(e)}")


def main():
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show the main window
    window = MiceManagerDesktop()
    window.show()
    
    # Start the event loop
    sys.exit(app.exec_())


if __name__ == '__main__':
    main() 