# SwiftCommander

A powerful dual-pane file manager for macOS, inspired by Total Commander, written in Swift and SwiftUI.

## Features

### Core File Management
- **Dual-Pane Interface**: Side-by-side file browsing with independent navigation
- **File Operations**: Copy, move, delete, rename files and folders
- **Multi-Selection**: Select multiple files using Shift+Click, Cmd+Click, or Cmd+A
- **Drag & Drop**: Drag files between panels or from/to Finder

### Navigation
- **Directory History**: Navigate back/forward through visited directories
- **Quick Navigation**: Jump to parent directory, home, root, or custom bookmarks
- **Breadcrumb Path**: Click on any path component to navigate directly
- **Hidden Files Toggle**: Show/hide hidden files and system files

### File Comparison & Merge
- **Side-by-Side Diff View**: Compare two text files with syntax highlighting
- **Change Detection**: Added (green), removed (red), and modified (orange) lines
- **Merge Operations**: Copy changes from left to right or right to left
- **Chunk-level Merge**: Merge individual change chunks selectively
- **Automatic Backup**: Creates backups before merge operations
- **Diff Statistics**: Shows count of added, removed, modified, and unchanged lines

### Function Key Commands (Total Commander Style)
- **F1**: Help
- **F2**: Refresh panels
- **F3**: View file
- **F4**: Edit file
- **F5**: Copy selected files to other panel
- **F6**: Move selected files to other panel
- **F7**: Create new directory
- **F8**: Delete selected files
- **F9**: Show context menu
- **F10**: Exit application

### Search & Filter
- **Quick Search**: Type to filter files in current directory
- **Find Files**: Search for files by name, content, or attributes
- **File Filter**: Filter by file type, size, or date

### Additional Features
- **Bookmarks**: Save frequently accessed directories
- **Archive Support**: View and extract ZIP archives
- **File Preview**: Quick Look integration for file previews
- **Sorting**: Sort by name, size, date, or type
- **Column Customization**: Show/hide columns (name, size, date, type, permissions)

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Quick Start

```bash
cd SwiftCommander
swift build
swift run SwiftCommander
```

## Building

### Debug Build
```bash
swift build
```

### Release Build
```bash
swift build -c release
```

### Running Tests
```bash
swift test
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘C | Copy selected files |
| ⌘V | Paste files |
| ⌘X | Cut selected files |
| ⌘A | Select all files |
| ⌘⌫ | Delete selected files |
| ⌘N | New folder |
| ⌘R | Refresh panels |
| ⌘F | Find files |
| ⌘D | Compare files |
| ⌘G | Go to directory |
| ⌘H | Toggle hidden files |
| ⌘1 | Focus left panel |
| ⌘2 | Focus right panel |
| ⌘↑ | Go to parent directory |
| ⌘← | Navigate back in history |
| ⌘→ | Navigate forward in history |
| Tab | Switch between panels |
| Enter | Open file/folder |
| Space | Select/deselect current item |

## Architecture

SwiftCommander follows the MVVM pattern with reactive state management:

```
SwiftCommander/
├── Sources/SwiftCommander/
│   ├── Models/           # Data structures
│   │   ├── FileItem.swift
│   │   ├── PanelState.swift
│   │   ├── CommandDefinition.swift
│   │   ├── BookmarkItem.swift
│   │   └── DiffResult.swift
│   ├── Services/         # Business logic
│   │   ├── FileOperationsService.swift
│   │   ├── NavigationService.swift
│   │   ├── SearchService.swift
│   │   ├── ArchiveService.swift
│   │   ├── FileComparisonService.swift
│   │   ├── MergeService.swift
│   │   └── BackupService.swift
│   ├── Views/            # SwiftUI components
│   │   ├── ContentView.swift
│   │   ├── FileListView.swift
│   │   ├── FileRowView.swift
│   │   ├── ToolbarView.swift
│   │   ├── FunctionKeyBar.swift
│   │   ├── QuickSearchView.swift
│   │   ├── CompareView.swift
│   │   └── SettingsView.swift
│   ├── Utils/
│   │   └── Extensions.swift
│   └── SwiftCommanderApp.swift
└── Tests/SwiftCommanderTests/
    └── Unit tests
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
