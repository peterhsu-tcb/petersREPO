import Foundation
import SwiftUI

/// Represents a function key command (F1-F10)
struct CommandDefinition: Identifiable {
    let id: FunctionKey
    let label: String
    let icon: String
    let action: CommandAction
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers
    
    var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(keyEquivalent, modifiers: modifiers)
    }
}

/// Function key enumeration
enum FunctionKey: String, CaseIterable, Identifiable {
    case f1 = "F1"
    case f2 = "F2"
    case f3 = "F3"
    case f4 = "F4"
    case f5 = "F5"
    case f6 = "F6"
    case f7 = "F7"
    case f8 = "F8"
    case f9 = "F9"
    case f10 = "F10"
    
    var id: String { rawValue }
    
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .f1: return KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!))
        case .f2: return KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!))
        case .f3: return KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
        case .f4: return KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
        case .f5: return KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
        case .f6: return KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
        case .f7: return KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
        case .f8: return KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))
        case .f9: return KeyEquivalent(Character(UnicodeScalar(NSF9FunctionKey)!))
        case .f10: return KeyEquivalent(Character(UnicodeScalar(NSF10FunctionKey)!))
        }
    }
}

/// Command action types
enum CommandAction: String {
    case help
    case refresh
    case view
    case edit
    case copy
    case move
    case newDirectory
    case delete
    case menu
    case quit
    case goToDirectory
    case search
    case selectAll
    case toggleHidden
    case focusLeftPanel
    case focusRightPanel
    case openFile
    case rename
    case properties
    case bookmark
    case terminal
}

/// Default function key commands (Total Commander style)
struct DefaultCommands {
    static let functionKeyCommands: [CommandDefinition] = [
        CommandDefinition(
            id: .f1,
            label: "Help",
            icon: "questionmark.circle",
            action: .help,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f2,
            label: "Refresh",
            icon: "arrow.clockwise",
            action: .refresh,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f3,
            label: "View",
            icon: "eye",
            action: .view,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f4,
            label: "Edit",
            icon: "pencil",
            action: .edit,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f5,
            label: "Copy",
            icon: "doc.on.doc",
            action: .copy,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f6,
            label: "Move",
            icon: "arrow.right.doc.on.clipboard",
            action: .move,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f7,
            label: "NewDir",
            icon: "folder.badge.plus",
            action: .newDirectory,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f8,
            label: "Delete",
            icon: "trash",
            action: .delete,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f9,
            label: "Menu",
            icon: "line.horizontal.3",
            action: .menu,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF9FunctionKey)!)),
            modifiers: []
        ),
        CommandDefinition(
            id: .f10,
            label: "Quit",
            icon: "xmark.circle",
            action: .quit,
            keyEquivalent: KeyEquivalent(Character(UnicodeScalar(NSF10FunctionKey)!)),
            modifiers: []
        )
    ]
    
    /// Menu commands with keyboard shortcuts
    static let menuCommands: [CommandDefinition] = [
        CommandDefinition(
            id: .f1,
            label: "Go to Directory",
            icon: "folder",
            action: .goToDirectory,
            keyEquivalent: "g",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f2,
            label: "Search",
            icon: "magnifyingglass",
            action: .search,
            keyEquivalent: "f",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f3,
            label: "Select All",
            icon: "checkmark.circle",
            action: .selectAll,
            keyEquivalent: "a",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f4,
            label: "Toggle Hidden",
            icon: "eye.slash",
            action: .toggleHidden,
            keyEquivalent: "h",
            modifiers: [.command, .shift]
        ),
        CommandDefinition(
            id: .f5,
            label: "Focus Left",
            icon: "arrow.left.square",
            action: .focusLeftPanel,
            keyEquivalent: "1",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f6,
            label: "Focus Right",
            icon: "arrow.right.square",
            action: .focusRightPanel,
            keyEquivalent: "2",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f7,
            label: "Rename",
            icon: "pencil.line",
            action: .rename,
            keyEquivalent: "r",
            modifiers: [.command, .shift]
        ),
        CommandDefinition(
            id: .f8,
            label: "Properties",
            icon: "info.circle",
            action: .properties,
            keyEquivalent: "i",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f9,
            label: "Add Bookmark",
            icon: "bookmark",
            action: .bookmark,
            keyEquivalent: "d",
            modifiers: .command
        ),
        CommandDefinition(
            id: .f10,
            label: "Open Terminal",
            icon: "terminal",
            action: .terminal,
            keyEquivalent: "t",
            modifiers: [.command, .shift]
        )
    ]
}
