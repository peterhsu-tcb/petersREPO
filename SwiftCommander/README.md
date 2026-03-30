# SwiftCommander

A native macOS dual-pane file manager inspired by [Total Commander](https://www.ghisler.com/) for Windows. Built with Swift and SwiftUI.

![SwiftCommander](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

### Dual-Pane Interface
- **Side-by-side file browsing** with independent navigation per pane
- **Tab to switch** between left and right panes
- **Drag & drop** support between panes
- Active pane highlighting

### Navigation
- **Back/Forward/Up** navigation buttons per pane
- **Path bar** with direct path editing
- **Quick Access sidebar** with favorites, devices, and recent folders
- **History tracking** for each pane

### File Operations
- **F5 - Copy** files between panes
- **F6 - Move** files between panes
- **F7 - Create folder**
- **F8 - Delete** (move to Trash or permanent delete)
- **F2 - Rename** selected item
- **Conflict resolution** dialogs (Replace, Keep Both, Skip)
- **Multi-select** support

### Search
- **Filename search** with instant filtering
- **Content search** within text files
- **Regex search** for advanced patterns
- **Spotlight integration** for fast indexed search

### Archive Support
- **Create archives**: ZIP, TAR, TAR.GZ, TAR.BZ2
- **Extract archives**: ZIP, TAR, GZIP, BZIP2
- **List archive contents**

### Terminal Integration
- **F9 - Open Terminal** at current directory
- Support for Terminal.app and iTerm2
- **Run commands** directly from the app

### Additional Features
- **Preview panel** for selected files
- **File info** display (size, permissions, dates)
- **Text file preview** with syntax highlighting
- **Multi-window support** (⌘N)
- **Hidden files toggle** (⌘⇧.)
- **Customizable settings**

## Screenshots

*Coming soon*

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (for development)

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/swiftcommander.git
cd swiftcommander/SwiftCommander

# Build with Swift Package Manager
swift build

# Run
swift run SwiftCommander
```

### Using Xcode

```bash
# Open the package in Xcode
cd SwiftCommander
open Package.swift

# Build and run with ⌘R
```

## Keyboard Shortcuts

### Function Keys (Total Commander style)
| Key | Action |
|-----|--------|
| F1 | Help |
| F2 | Rename |
| F3 | View file |
| F4 | Edit file |
| F5 | Copy |
| F6 | Move |
| F7 | Create folder |
| F8 | Delete |
| F9 | Open terminal |
| F10 | Quit |

### Standard macOS Shortcuts
| Shortcut | Action |
|----------|--------|
| ⌘N | New window |
| ⌘⇧N | New folder |
| ⌘⌥N | New file |
| ⌘R | Refresh |
| ⌘F | Search |
| ⌘G | Go to path |
| ⌘⇧. | Toggle hidden files |
| ⌘⇧T | Open terminal here |
| Tab | Switch panes |
| ⌘[ | Go back |
| ⌘] | Go forward |
| ⌘↑ | Go to parent folder |
| ⌘A | Select all |
| ⌘I | Invert selection |

## Project Structure

```
SwiftCommander/
├── Package.swift
├── README.md
├── Sources/
│   └── SwiftCommander/
│       ├── SwiftCommanderApp.swift    # Main app entry point
│       ├── Models/
│       │   ├── FileItem.swift         # File/folder representation
│       │   ├── PaneState.swift        # Pane state management
│       │   └── FileOperation.swift    # Operation types & progress
│       ├── Managers/
│       │   ├── FileManagerService.swift  # File operations
│       │   ├── ArchiveManager.swift      # Archive handling
│       │   ├── SearchManager.swift       # Search functionality
│       │   └── TerminalManager.swift     # Terminal integration
│       └── Views/
│           ├── ContentView.swift      # Main layout
│           ├── FilePaneView.swift     # File browser pane
│           ├── Dialogs.swift          # Modal dialogs
│           └── SettingsView.swift     # Preferences
└── Tests/
    └── SwiftCommanderTests/
        └── SwiftCommanderTests.swift
```

## Architecture

- **SwiftCommanderApp**: Main application with menu commands and window management
- **AppState**: Centralized state management with @Published properties
- **PaneState**: Per-pane state (current path, selection, history)
- **FileManagerService**: Singleton for file system operations
- **Views**: SwiftUI views composing the UI

## Similar Projects & Inspiration

- [Folderium](https://github.com/abdullahguch/folderium) - Native macOS file manager with dual-pane layout (SwiftUI)
- [Total Commander](https://www.ghisler.com/) - The original Windows dual-pane file manager
- [Double Commander](https://doublecmd.sourceforge.io/) - Cross-platform Total Commander alternative
- [muCommander](https://www.mucommander.com/) - Cross-platform file manager (Java)

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [Total Commander](https://www.ghisler.com/) by Christian Ghisler
- UI patterns from [Folderium](https://github.com/abdullahguch/folderium)
- Built with SwiftUI and Swift
