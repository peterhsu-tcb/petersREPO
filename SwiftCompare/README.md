# SwiftCompare

A powerful file and folder comparison tool for macOS, built with Swift and SwiftUI. SwiftCompare provides functionality similar to Beyond Compare, allowing you to compare files and directories visually and merge differences.

## Features

### File Comparison
- **Side-by-side diff view**: View differences between two files with synchronized scrolling
- **Syntax highlighting**: Different colors for added, removed, and modified lines
- **Line numbers**: Easy reference with line number gutter
- **Difference navigation**: Jump between differences with keyboard shortcuts
- **Filter options**: Show only differences or view entire files

### Folder Comparison
- **Recursive comparison**: Compare entire directory trees
- **Status indicators**: Visual icons showing identical, different, left-only, and right-only items
- **Size and date comparison**: View file sizes and modification dates side-by-side
- **Expandable tree view**: Navigate through folder hierarchies

### Merge Capabilities
- **Copy operations**: Copy files from left to right or right to left
- **One-click sync**: Synchronize differences with a single click
- **Selective merge**: Choose which differences to merge

### User Interface
- **Native macOS app**: Built with SwiftUI for a modern, native experience
- **Drag and drop**: Drop files or folders to start comparing
- **Keyboard shortcuts**: Full keyboard navigation support
- **Dark mode support**: Automatic adaptation to system appearance

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building from source)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/SwiftCompare.git
   cd SwiftCompare
   ```

2. Build with Swift Package Manager:
   ```bash
   cd SwiftCompare
   swift build
   ```

3. Run the application:
   ```bash
   swift run SwiftCompare
   ```

### Creating an App Bundle

To create a standalone macOS application:

1. Open the project in Xcode:
   ```bash
   open SwiftCompare/Package.swift
   ```

2. Build the project (⌘B)

3. Export the app from the Products folder

## Usage

### Comparing Files

1. Launch SwiftCompare
2. Click "Compare Files" or use ⌘O
3. Select two files to compare
4. View the differences in the side-by-side diff view

### Comparing Folders

1. Launch SwiftCompare
2. Click "Compare Folders" or use ⌘⇧O
3. Select two folders to compare
4. Browse the comparison results in the tree view

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘N | New Comparison |
| ⌘O | Compare Files |
| ⌘⇧O | Compare Folders |
| ⌘R | Refresh Comparison |
| ⌘[ | Previous Difference |
| ⌘] | Next Difference |
| ⌘D | Toggle "Show Only Differences" |
| ⌘⌥← | Copy Left to Right |
| ⌘⌥→ | Copy Right to Left |

## Architecture

```
SwiftCompare/
├── Sources/SwiftCompare/
│   ├── Models/
│   │   ├── FileItem.swift          # File/directory representation
│   │   ├── DiffResult.swift        # Diff output structures
│   │   └── ComparisonResult.swift  # Folder comparison results
│   ├── Services/
│   │   ├── FileComparisonService.swift   # Text diff algorithm (LCS)
│   │   └── FolderComparisonService.swift # Directory comparison
│   ├── Views/
│   │   ├── ContentView.swift       # Main app layout
│   │   ├── ComparisonView.swift    # Diff and folder views
│   │   └── SettingsView.swift      # Preferences
│   ├── Utils/
│   │   └── Extensions.swift        # Helper extensions
│   └── SwiftCompareApp.swift       # App entry point
└── Tests/SwiftCompareTests/
    └── FileComparisonServiceTests.swift
```

## Algorithm

SwiftCompare uses the **Longest Common Subsequence (LCS)** algorithm for file comparison:

1. Parse both files into arrays of lines
2. Build a dynamic programming table to find the LCS
3. Trace back through the table to identify:
   - Unchanged lines (in both files)
   - Added lines (only in right file)
   - Removed lines (only in left file)
4. Group consecutive changes into chunks for display

## Configuration

Access settings via SwiftCompare → Settings (⌘,):

### General
- **Ignore whitespace**: Skip whitespace-only differences
- **Ignore case**: Perform case-insensitive comparison
- **Show hidden files**: Include hidden files in folder comparison
- **Recursive comparison**: Compare subdirectories

### Appearance
- **Theme**: System, Light, or Dark
- **Font size**: Adjust text size in diff view

### File Types
- **Text extensions**: Configure which extensions are treated as text
- **Binary extensions**: Configure which extensions are treated as binary

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [Beyond Compare](https://www.scootersoftware.com/)
- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Uses the classic LCS diff algorithm

## Roadmap

- [ ] Three-way merge support
- [ ] Inline editing in diff view
- [ ] Git integration
- [ ] Custom diff colors
- [ ] Plugin system for custom file types
- [ ] Report generation (HTML, PDF)
- [ ] Session saving and loading
- [ ] Command-line interface
