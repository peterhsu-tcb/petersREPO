# WEditor

A powerful text editor for macOS with column edit mode and comprehensive syntax highlighting, inspired by UltraEdit and Context editor. Written in Swift and SwiftUI.

## Features

### Text Editing
- Full-featured text editing with undo/redo support
- Multi-tab document editing
- Line operations: duplicate, delete, move up/down
- Auto-indent and bracket matching
- Configurable tab width (spaces or tabs)
- Word wrap toggle
- Multiple line ending support (LF, CR, CRLF)
- Multiple encoding support (UTF-8, UTF-16, ASCII, Latin-1, Shift-JIS, and more)

### Column (Block) Edit Mode
- Toggle column edit mode with `⌘⇧B` or via the Column menu
- Rectangular block selection using Alt+Drag or Alt+Shift+Arrow keys
- Column insert, delete, and replace operations
- Column paste (paste multi-line text into a rectangular region)
- Column fill with character
- Sequential line numbering in column selection
- Column indent/unindent

### Syntax Highlighting
Supports 30+ programming languages and file formats:

| Category | Languages |
|----------|-----------|
| **Systems** | C, C++, Objective-C, Rust, Go |
| **Application** | Swift, Java, C#, Kotlin, Scala, Dart |
| **Scripting** | Python, JavaScript, TypeScript, Ruby, PHP, Perl, Lua, R, Elixir |
| **Functional** | Haskell |
| **Web** | HTML, CSS, JSON, XML |
| **Data** | YAML, TOML, INI, SQL |
| **DevOps** | Shell/Bash, Dockerfile, Makefile |
| **Documentation** | Markdown |

### Themes
- **WEditor Dark** - Custom dark theme with balanced colors
- **WEditor Light** - Clean light theme for daytime use
- **Monokai** - Classic Monokai-inspired dark theme
- **Solarized Dark** - Solarized color palette dark variant

### Find & Replace
- Incremental search with match highlighting
- Case-sensitive / case-insensitive search
- Whole word matching
- Regular expression support
- Find next / Find previous with wrap-around
- Replace single or all occurrences
- Match count display

### Editor Features
- Line number gutter with current line highlight
- Mini map for document overview
- Status bar with cursor position, line count, language, encoding, and line endings
- Configurable font (Menlo, Monaco, SF Mono, Courier New, Andale Mono)
- Adjustable font size (8-32pt)
- Adjustable line spacing
- Show/hide whitespace characters
- Indent guides

### File Management
- Open multiple files in tabs
- Recent files history
- Auto-save support
- File encoding detection
- Language auto-detection from file extension and filename

## Quick Start

```bash
cd WEditor
swift build
swift run WEditor
```

## Keyboard Shortcuts

### File Operations
| Shortcut | Action |
|----------|--------|
| `⌘N` | New File |
| `⌘O` | Open File |
| `⌘S` | Save |
| `⌘⇧S` | Save As |
| `⌘⌥S` | Save All |
| `⌘W` | Close Tab |

### Editing
| Shortcut | Action |
|----------|--------|
| `⌘Z` | Undo |
| `⌘⇧Z` | Redo |
| `⌘A` | Select All |
| `⌘L` | Select Line |
| `⌘D` | Select Word |
| `⌘⇧D` | Duplicate Line |
| `⌘⇧K` | Delete Line |
| `⌥↑` | Move Line Up |
| `⌥↓` | Move Line Down |

### Search
| Shortcut | Action |
|----------|--------|
| `⌘F` | Find |
| `⌘⌥H` | Find and Replace |
| `⌘G` | Find Next |
| `⌘⇧G` | Find Previous |
| `⌘⌥G` | Go to Line |

### View
| Shortcut | Action |
|----------|--------|
| `⌘+` | Increase Font Size |
| `⌘-` | Decrease Font Size |
| `⌘0` | Reset Font Size |
| `⌘⌥Z` | Toggle Word Wrap |
| `⌘⇧B` | Toggle Column Edit Mode |

## Architecture

```
WEditor/
├── Sources/WEditor/
│   ├── WEditorApp.swift           # App entry point and AppState
│   ├── Models/
│   │   ├── Document.swift         # Document model with cursor/selection
│   │   ├── SyntaxDefinition.swift # 30+ language syntax definitions
│   │   ├── Theme.swift            # Color themes
│   │   └── EditorSettings.swift   # User preferences
│   ├── Services/
│   │   ├── FileService.swift              # File I/O with encoding detection
│   │   ├── SyntaxHighlightingService.swift # Regex-based syntax highlighting
│   │   ├── SearchReplaceService.swift     # Find/replace with regex support
│   │   └── ColumnEditService.swift        # Column/block editing operations
│   ├── Views/
│   │   ├── ContentView.swift      # Main layout with tabs
│   │   ├── EditorView.swift       # Text editor with syntax highlighting
│   │   ├── GutterView.swift       # Line numbers
│   │   ├── MiniMapView.swift      # Document overview
│   │   ├── StatusBarView.swift    # Status information
│   │   ├── FindReplaceView.swift  # Search and replace bar
│   │   └── SettingsView.swift     # Preferences window
│   └── Utils/
│       └── Extensions.swift       # Helper extensions
├── Tests/WEditorTests/
│   └── WEditorTests.swift         # Comprehensive unit tests
├── Package.swift
└── README.md
```

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9 or later
- Xcode 15 or later (for development)

## License

Part of the petersREPO collection of macOS utilities.
