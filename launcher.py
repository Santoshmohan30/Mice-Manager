#!/usr/bin/env python3
"""
Mice Manager Launcher
Choose between web application and desktop application
"""

import sys
import os
import subprocess
from PyQt5.QtWidgets import QApplication, QMainWindow, QWidget, QVBoxLayout, QPushButton, QLabel
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont

class LauncherWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Mice Manager Launcher")
        self.setGeometry(300, 300, 400, 200)
        self.setup_ui()
    
    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        
        # Title
        title = QLabel("Mice Manager")
        title.setFont(QFont("Arial", 20, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        layout.addWidget(title)
        
        subtitle = QLabel("Choose your preferred interface:")
        subtitle.setAlignment(Qt.AlignCenter)
        layout.addWidget(subtitle)
        
        # Buttons
        web_btn = QPushButton("Web Application")
        web_btn.setMinimumHeight(50)
        web_btn.clicked.connect(self.launch_web_app)
        layout.addWidget(web_btn)
        
        desktop_btn = QPushButton("Desktop Application")
        desktop_btn.setMinimumHeight(50)
        desktop_btn.clicked.connect(self.launch_desktop_app)
        layout.addWidget(desktop_btn)
        
        # Exit button
        exit_btn = QPushButton("Exit")
        exit_btn.clicked.connect(self.close)
        layout.addWidget(exit_btn)
    
    def launch_web_app(self):
        """Launch the Flask web application"""
        try:
            # Start Flask app in a new process
            subprocess.Popen([sys.executable, "app.py"])
            self.close()
        except Exception as e:
            from PyQt5.QtWidgets import QMessageBox
            QMessageBox.critical(self, "Error", f"Failed to launch web app: {str(e)}")
    
    def launch_desktop_app(self):
        """Launch the desktop application"""
        try:
            # Start desktop app in a new process
            subprocess.Popen([sys.executable, "desktop_app.py"])
            self.close()
        except Exception as e:
            from PyQt5.QtWidgets import QMessageBox
            QMessageBox.critical(self, "Error", f"Failed to launch desktop app: {str(e)}")

def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    window = LauncherWindow()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == '__main__':
    main() 