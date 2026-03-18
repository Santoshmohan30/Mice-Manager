#!/usr/bin/env python3
"""
Mice Manager Desktop Installation Script
This script installs the desktop application and creates shortcuts
"""

import os
import sys
import shutil
import subprocess
from pathlib import Path

def main():
    print("🐭 Mice Manager Desktop Installation")
    print("=" * 40)
    
    # Get current directory
    current_dir = Path(__file__).parent.absolute()
    dist_dir = current_dir / "dist"
    
    if not dist_dir.exists():
        print(" Error: dist/ directory not found!")
        print("Please run the build process first:")
        print("  pyinstaller --onefile --windowed --name 'MiceManager' desktop_app.py")
        print("  pyinstaller --onefile --windowed --name 'MiceManagerLauncher' launcher.py")
        return
    
    # Check for executables
    desktop_app = dist_dir / "MiceManager"
    launcher_app = dist_dir / "MiceManagerLauncher"
    
    if not desktop_app.exists() and not (dist_dir / "MiceManager.app").exists():
        print(" Error: MiceManager executable not found!")
        return
    
    if not launcher_app.exists() and not (dist_dir / "MiceManagerLauncher.app").exists():
        print("Error: MiceManagerLauncher executable not found!")
        return
    
    print(" Executables found!")
    
    # Create installation directory
    install_dir = Path.home() / "Applications" / "MiceManager"
    install_dir.mkdir(parents=True, exist_ok=True)
    
    print(f" Installing to: {install_dir}")
    
    # Copy files
    try:
        # Copy database if it exists
        db_file = current_dir / "mice.db"
        if db_file.exists():
            shutil.copy2(db_file, install_dir / "mice.db")
            print("Database copied")
        
        # Copy executables
        if sys.platform == "darwin":  # macOS
            # Copy .app bundles
            if (dist_dir / "MiceManager.app").exists():
                shutil.copytree(dist_dir / "MiceManager.app", install_dir / "MiceManager.app", dirs_exist_ok=True)
                print(" MiceManager.app copied")
            
            if (dist_dir / "MiceManagerLauncher.app").exists():
                shutil.copytree(dist_dir / "MiceManagerLauncher.app", install_dir / "MiceManagerLauncher.app", dirs_exist_ok=True)
                print(" MiceManagerLauncher.app copied")
        
        else:  # Windows/Linux
            # Copy executable files
            if desktop_app.exists():
                shutil.copy2(desktop_app, install_dir / "MiceManager")
                print(" MiceManager executable copied")
            
            if launcher_app.exists():
                shutil.copy2(launcher_app, install_dir / "MiceManagerLauncher")
                print(" MiceManagerLauncher executable copied")
        
        # Create shortcuts/aliases
        if sys.platform == "darwin":  # macOS
            # Create symbolic links in Applications
            apps_dir = Path("/Applications")
            
            try:
                if (install_dir / "MiceManager.app").exists():
                    if (apps_dir / "MiceManager.app").exists():
                        os.remove(apps_dir / "MiceManager.app")
                    os.symlink(install_dir / "MiceManager.app", apps_dir / "MiceManager.app")
                    print(" Shortcut created in Applications")
                
                if (install_dir / "MiceManagerLauncher.app").exists():
                    if (apps_dir / "MiceManagerLauncher.app").exists():
                        os.remove(apps_dir / "MiceManagerLauncher.app")
                    os.symlink(install_dir / "MiceManagerLauncher.app", apps_dir / "MiceManagerLauncher.app")
                    print(" Launcher shortcut created in Applications")
                    
            except PermissionError:
                print("  Could not create shortcuts in Applications (permission denied)")
                print("   You can manually copy the .app files to Applications")
        
        # Create README
        readme_content = f"""# Mice Manager Desktop Application

## Installation Location
{install_dir}

## How to Use

### Option 1: Use Launcher (Recommended)
Double-click "MiceManagerLauncher" to choose between web and desktop applications.

### Option 2: Direct Desktop App
Double-click "MiceManager" to launch the desktop application directly.

### Option 3: Command Line
```bash
cd {install_dir}
./MiceManagerLauncher  # or ./MiceManager
```

## Features
- Complete offline operation
- Native desktop interface
- Same functionality as web version
- Uses existing database

## Support
For issues, check the console output or refer to README_DESKTOP.md
"""
        
        with open(install_dir / "README.txt", "w") as f:
            f.write(readme_content)
        
        print(" README created")
        
        print("\n Installation Complete!")
        print(f"Application installed to: {install_dir}")
        
        if sys.platform == "darwin":
            print("\n To launch the application:")
            print("   1. Open Applications folder")
            print("   2. Double-click 'MiceManagerLauncher' or 'MiceManager'")
            print("   3. Or use Spotlight (Cmd+Space) and search for 'MiceManager'")
        else:
            print("\n To launch the application:")
            print(f"   1. Navigate to: {install_dir}")
            print("   2. Double-click 'MiceManagerLauncher' or 'MiceManager'")
        
        print("\n For more information, see README_DESKTOP.md")
        
    except Exception as e:
        print(f" Installation failed: {str(e)}")
        return

if __name__ == "__main__":
    main() 