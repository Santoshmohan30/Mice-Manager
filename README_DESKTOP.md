# Mice Manager - Desktop Application

This is the desktop version of the Mice Manager application, built using PyQt5 for a native desktop experience that runs completely offline.

## Features

- **Complete Offline Operation**: No internet connection required
- **Native Desktop Interface**: Fast, responsive GUI built with PyQt5
- **Same Functionality**: All features from the web version available
- **Database Integration**: Uses the same SQLite database as the web app
- **Cross-Platform**: Works on Windows, macOS, and Linux

## Installation

### Prerequisites

- Python 3.7 or higher
- pip (Python package installer)

### Setup

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Database Setup** (if not already done):
   ```bash
   python -c "from app import app, db; app.app_context().push(); db.create_all()"
   ```

## Usage

### Option 1: Use the Launcher (Recommended)
Run the launcher to choose between web and desktop applications:
```bash
python launcher.py
```

### Option 2: Direct Desktop App Launch
Run the desktop application directly:
```bash
python desktop_app.py
```

### Option 3: Web Application
Run the original Flask web application:
```bash
python app.py
```

## Desktop Application Features

### Dashboard
- Overview statistics (total mice, active breeding pairs, upcoming events)
- Quick action buttons
- Recent activity display

### Mice Management
- View all mice in a table format
- Add new mice with detailed information
- Edit existing mouse records
- Delete mice
- Filter by strain, gender, and other criteria
- Search functionality

### Breeding Management
- Track breeding pairs
- Record pair dates and litter information
- View breeding status
- Manage breeding records

### Procedures
- Log procedures performed on mice
- Track procedure dates and types
- Add notes for each procedure

### Calendar
- Schedule and track events
- Categorize events (breeding, procedure, maintenance, etc.)
- View upcoming events

## Database

The desktop application uses the same SQLite database (`mice.db`) as the web application, ensuring data consistency between both interfaces.

## File Structure

```
MiceManager/
├── desktop_app.py          # Main desktop application
├── launcher.py            # Application launcher
├── app.py                 # Original Flask web application
├── models/                # Database models
├── templates/             # Web app templates
├── static/                # Web app static files
├── mice.db               # SQLite database
└── requirements.txt      # Python dependencies
```

## Troubleshooting

### Common Issues

1. **PyQt5 Installation Issues**:
   - On macOS: `brew install pyqt5`
   - On Ubuntu/Debian: `sudo apt-get install python3-pyqt5`
   - On Windows: Use pip: `pip install PyQt5`

2. **Database Connection Errors**:
   - Ensure `mice.db` exists in the project root
   - Check file permissions
   - Run database initialization if needed

3. **Import Errors**:
   - Make sure all dependencies are installed: `pip install -r requirements.txt`
   - Check Python version compatibility

### Error Reporting

If you encounter issues:
1. Check the console output for error messages
2. Ensure all dependencies are properly installed
3. Verify database file exists and is accessible
4. Check Python version (3.7+ required)

## Development

### Adding New Features

To add new features to the desktop application:

1. **Update Models**: Modify files in the `models/` directory
2. **Update Desktop App**: Add new functionality to `desktop_app.py`
3. **Update Web App**: Add corresponding functionality to `app.py`
4. **Test Both**: Ensure both interfaces work correctly

### Building Standalone Executable

To create a standalone executable (optional):

```bash
# Install PyInstaller
pip install pyinstaller

# Create executable
pyinstaller --onefile --windowed desktop_app.py

# The executable will be in the dist/ directory
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the console output for error messages
3. Ensure all dependencies are properly installed
4. Verify database integrity

## License

This application is provided as-is for laboratory management purposes. 