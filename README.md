# Klinmai - Smart Desktop Organizer for macOS

A beautiful, native macOS menu bar app that organizes your desktop with one click. Files automatically go where they belong - Pictures to Pictures, Documents to Documents, and more.

## Features

- 🎯 **One-Click Organization** - Left-click the menu bar icon to instantly organize your desktop
- 📁 **Smart Native Organization** - Files are moved to their proper macOS folders
- 📸 **Screenshot Management** - Optionally organize screenshots by month
- 🎨 **Beautiful Pink Theme** - Elegant, native macOS interface
- ⚡ **Lightweight** - Runs quietly in your menu bar, just like Caffeine

## Installation

### Build from Source

```bash
git clone https://github.com/jadewii/klinmai-app.git
cd klinmai-app
swift build -c release
```

The built app will be at `.build/release/DesktopCleaner`

## Usage

1. Launch the app - it appears as an icon in your menu bar
2. **Left-click** the icon to organize your desktop instantly
3. **Right-click** for menu options:
   - About Klinmai
   - Preferences (customize organization settings)
   - Quit

## File Organization

Klinmai intelligently organizes files to native macOS folders:

- **Images** (jpg, png, gif, heic) → Pictures
- **Documents** (pdf, doc, docx, txt, pages) → Documents  
- **Music** (mp3, m4a, wav, aiff) → Music
- **Videos** (mp4, mov, avi, mkv) → Movies
- **Screenshots** → Documents/Screenshots (organized by month)
- **Code Projects** → Developer/Projects
- **Archives** (zip, dmg, pkg) → Downloads/Archives

## Development

Built with Swift and SwiftUI for macOS 13+

### Project Structure

```
├── main.swift                    # App entry point
├── DesktopCleanerApp.swift      # Main app delegate
├── SetupView.swift              # Preferences window
├── Models/
│   └── AppState.swift           # App state management
└── Services/
    └── FileOrganizer.swift      # File organization logic
```

### Key Technologies

- SwiftUI + AppKit hybrid for native macOS experience
- NSStatusItem for menu bar integration
- FileManager for safe file operations

## License

MIT