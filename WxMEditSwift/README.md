# WxMEditSwift

A native macOS port of [wxMEdit](https://github.com/wxmedit/wxMEdit) — the
multi-mode text/hex editor that descends from MadEdit — written from scratch
in Swift and SwiftUI/AppKit.

## Scope

wxMEdit is a large C++/wxWidgets codebase (GPLv2). This project is **not** a
line-by-line translation; doing so would be impractical and would also
inherit GPL obligations. Instead, WxMEditSwift is a clean-room
reimplementation of wxMEdit's signature features using native macOS APIs:

- **Three editing modes**: Text, Column (block), and Hex
- **Multi-encoding I/O**: UTF-8 / UTF-8 BOM / UTF-16 LE+BE / UTF-32 LE+BE,
  Latin-1/2, Windows-125x, Shift-JIS, EUC-JP, GB18030, Big5, EUC-KR, KOI8-R
- **Line-ending detection and conversion**: LF / CRLF / CR
- **Find & replace**: literal, case sensitivity, whole-word, full regex, wrap
- **Hex view**: classic `offset | hex bytes | ascii` rendering, configurable
  bytes-per-row
- **Column edit operations**: rectangular extract / delete / insert / fill,
  with automatic space-padding for short lines
- **Tabbed multi-document interface** with native NSTextView (undo/redo, IME,
  spellcheck-disabled-by-default for code editing)

Features that wxMEdit ships and that are intentionally *out of scope* for
this initial cut: bookmarks, syntax highlighting, large-file streaming,
printing, plugin scripting, and the right-to-left / vertical text layouts.
The architecture leaves room for them.

## Project layout

```
WxMEditSwift/
├── Sources/WxMEditSwift/
│   ├── WxMEditSwiftApp.swift          # @main + menu commands
│   ├── Models/
│   │   ├── AppState.swift             # open documents, active selection
│   │   ├── Document.swift             # text + bytes + selection state
│   │   ├── EditMode.swift             # .text / .column / .hex
│   │   ├── LineEnding.swift           # LF / CRLF / CR detect+convert
│   │   └── TextEncoding.swift         # encoding catalog + BOM detection
│   ├── Services/
│   │   ├── ColumnEditService.swift    # rectangular block operations
│   │   ├── FileService.swift          # load/save with encoding detection
│   │   ├── FindReplaceService.swift   # NSRegularExpression-based search
│   │   └── HexService.swift           # hex render/parse/edit
│   ├── Views/
│   │   ├── ContentView.swift          # main layout, tab bar
│   │   ├── FindBarView.swift          # find/replace bar
│   │   ├── HexEditorView.swift        # hex pane (NSViewRepresentable)
│   │   ├── StatusBarView.swift        # mode/encoding/EOL/cursor
│   │   └── TextEditorView.swift       # text pane (NSViewRepresentable)
│   └── Utils/Utils.swift              # placeholder for shared helpers
├── Tests/WxMEditSwiftTests/
│   └── WxMEditSwiftTests.swift        # unit tests (encoding, hex, column, find)
├── Info.plist
├── Package.swift
└── WxMEditSwift.entitlements
```

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+ / Xcode 15+

> The package **uses SwiftUI and AppKit**, so it can only be compiled and run
> on macOS. The same applies to the sibling `WEditor`, `SwiftCommander`, and
> `SwiftCompare` projects in this repository.

## Build & run

```bash
cd WxMEditSwift
swift build
swift run WxMEditSwift
```

## Keyboard shortcuts

| Shortcut          | Action               |
|-------------------|----------------------|
| `⌘N`              | New document         |
| `⌘O`              | Open file…           |
| `⌘S` / `⌘⇧S`      | Save / Save As…      |
| `⌘F`              | Toggle find bar      |
| `⌘⌥1` / `⌘⌥2` / `⌘⌥3` | Text / Column / Hex mode |

## License

Part of the petersREPO collection of macOS utilities. See repository root.
