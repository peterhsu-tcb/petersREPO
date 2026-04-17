import SwiftUI

/// Editor color theme
struct EditorTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool
    let backgroundColor: Color
    let textColor: Color
    let gutterBackgroundColor: Color
    let gutterTextColor: Color
    let selectionColor: Color
    let columnSelectionColor: Color
    let cursorColor: Color
    let currentLineHighlight: Color
    let lineNumberColor: Color
    let tokenColors: [TokenType: Color]
    
    /// Get color for a token type
    func color(for tokenType: TokenType) -> Color {
        return tokenColors[tokenType] ?? textColor
    }
}

// MARK: - Built-in Themes

extension EditorTheme {
    /// Default dark theme (inspired by popular dark themes)
    static let defaultDark = EditorTheme(
        id: "default-dark",
        name: "WEditor Dark",
        isDark: true,
        backgroundColor: Color(red: 0.12, green: 0.12, blue: 0.14),
        textColor: Color(red: 0.85, green: 0.85, blue: 0.85),
        gutterBackgroundColor: Color(red: 0.10, green: 0.10, blue: 0.12),
        gutterTextColor: Color(red: 0.45, green: 0.45, blue: 0.50),
        selectionColor: Color(red: 0.20, green: 0.35, blue: 0.55).opacity(0.5),
        columnSelectionColor: Color(red: 0.30, green: 0.50, blue: 0.70).opacity(0.4),
        cursorColor: Color.white,
        currentLineHighlight: Color.white.opacity(0.05),
        lineNumberColor: Color(red: 0.45, green: 0.45, blue: 0.50),
        tokenColors: [
            .keyword: Color(red: 0.78, green: 0.47, blue: 0.85),
            .type: Color(red: 0.31, green: 0.76, blue: 0.77),
            .string: Color(red: 0.80, green: 0.55, blue: 0.35),
            .number: Color(red: 0.72, green: 0.80, blue: 0.44),
            .comment: Color(red: 0.45, green: 0.55, blue: 0.40),
            .preprocessor: Color(red: 0.78, green: 0.47, blue: 0.85),
            .operator: Color(red: 0.85, green: 0.85, blue: 0.85),
            .function: Color(red: 0.38, green: 0.68, blue: 0.93),
            .variable: Color(red: 0.62, green: 0.82, blue: 0.97),
            .constant: Color(red: 0.72, green: 0.80, blue: 0.44),
            .attribute: Color(red: 0.95, green: 0.77, blue: 0.37),
            .tag: Color(red: 0.93, green: 0.42, blue: 0.42),
            .tagAttribute: Color(red: 0.95, green: 0.77, blue: 0.37),
            .escape: Color(red: 0.93, green: 0.42, blue: 0.42),
            .regex: Color(red: 0.80, green: 0.55, blue: 0.35),
            .heading: Color(red: 0.38, green: 0.68, blue: 0.93),
            .link: Color(red: 0.38, green: 0.68, blue: 0.93),
            .bold: Color(red: 0.95, green: 0.77, blue: 0.37),
            .italic: Color(red: 0.62, green: 0.82, blue: 0.97),
            .plain: Color(red: 0.85, green: 0.85, blue: 0.85),
        ]
    )
    
    /// Light theme
    static let defaultLight = EditorTheme(
        id: "default-light",
        name: "WEditor Light",
        isDark: false,
        backgroundColor: Color(red: 1.0, green: 1.0, blue: 1.0),
        textColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        gutterBackgroundColor: Color(red: 0.96, green: 0.96, blue: 0.96),
        gutterTextColor: Color(red: 0.55, green: 0.55, blue: 0.60),
        selectionColor: Color(red: 0.65, green: 0.80, blue: 1.0).opacity(0.4),
        columnSelectionColor: Color(red: 0.50, green: 0.70, blue: 1.0).opacity(0.3),
        cursorColor: Color.black,
        currentLineHighlight: Color.black.opacity(0.04),
        lineNumberColor: Color(red: 0.55, green: 0.55, blue: 0.60),
        tokenColors: [
            .keyword: Color(red: 0.55, green: 0.15, blue: 0.65),
            .type: Color(red: 0.10, green: 0.50, blue: 0.55),
            .string: Color(red: 0.65, green: 0.30, blue: 0.10),
            .number: Color(red: 0.15, green: 0.55, blue: 0.15),
            .comment: Color(red: 0.35, green: 0.50, blue: 0.35),
            .preprocessor: Color(red: 0.55, green: 0.15, blue: 0.65),
            .operator: Color(red: 0.15, green: 0.15, blue: 0.15),
            .function: Color(red: 0.15, green: 0.40, blue: 0.70),
            .variable: Color(red: 0.10, green: 0.50, blue: 0.70),
            .constant: Color(red: 0.15, green: 0.55, blue: 0.15),
            .attribute: Color(red: 0.70, green: 0.50, blue: 0.10),
            .tag: Color(red: 0.75, green: 0.20, blue: 0.20),
            .tagAttribute: Color(red: 0.70, green: 0.50, blue: 0.10),
            .escape: Color(red: 0.75, green: 0.20, blue: 0.20),
            .regex: Color(red: 0.65, green: 0.30, blue: 0.10),
            .heading: Color(red: 0.15, green: 0.40, blue: 0.70),
            .link: Color(red: 0.15, green: 0.40, blue: 0.70),
            .bold: Color(red: 0.70, green: 0.50, blue: 0.10),
            .italic: Color(red: 0.10, green: 0.50, blue: 0.70),
            .plain: Color(red: 0.15, green: 0.15, blue: 0.15),
        ]
    )
    
    /// Monokai-inspired dark theme
    static let monokai = EditorTheme(
        id: "monokai",
        name: "Monokai",
        isDark: true,
        backgroundColor: Color(red: 0.16, green: 0.16, blue: 0.15),
        textColor: Color(red: 0.97, green: 0.97, blue: 0.95),
        gutterBackgroundColor: Color(red: 0.14, green: 0.14, blue: 0.13),
        gutterTextColor: Color(red: 0.55, green: 0.55, blue: 0.50),
        selectionColor: Color(red: 0.27, green: 0.27, blue: 0.24).opacity(0.8),
        columnSelectionColor: Color(red: 0.35, green: 0.35, blue: 0.30).opacity(0.5),
        cursorColor: Color(red: 0.97, green: 0.97, blue: 0.95),
        currentLineHighlight: Color.white.opacity(0.04),
        lineNumberColor: Color(red: 0.55, green: 0.55, blue: 0.50),
        tokenColors: [
            .keyword: Color(red: 0.97, green: 0.15, blue: 0.45),
            .type: Color(red: 0.40, green: 0.85, blue: 0.94),
            .string: Color(red: 0.90, green: 0.86, blue: 0.45),
            .number: Color(red: 0.68, green: 0.51, blue: 1.00),
            .comment: Color(red: 0.46, green: 0.44, blue: 0.37),
            .preprocessor: Color(red: 0.97, green: 0.15, blue: 0.45),
            .operator: Color(red: 0.97, green: 0.15, blue: 0.45),
            .function: Color(red: 0.65, green: 0.89, blue: 0.18),
            .variable: Color(red: 0.97, green: 0.97, blue: 0.95),
            .constant: Color(red: 0.68, green: 0.51, blue: 1.00),
            .attribute: Color(red: 0.65, green: 0.89, blue: 0.18),
            .tag: Color(red: 0.97, green: 0.15, blue: 0.45),
            .tagAttribute: Color(red: 0.65, green: 0.89, blue: 0.18),
            .escape: Color(red: 0.68, green: 0.51, blue: 1.00),
            .regex: Color(red: 0.90, green: 0.86, blue: 0.45),
            .heading: Color(red: 0.65, green: 0.89, blue: 0.18),
            .link: Color(red: 0.40, green: 0.85, blue: 0.94),
            .bold: Color(red: 0.97, green: 0.15, blue: 0.45),
            .italic: Color(red: 0.40, green: 0.85, blue: 0.94),
            .plain: Color(red: 0.97, green: 0.97, blue: 0.95),
        ]
    )
    
    /// Solarized Dark theme
    static let solarizedDark = EditorTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        isDark: true,
        backgroundColor: Color(red: 0.00, green: 0.17, blue: 0.21),
        textColor: Color(red: 0.51, green: 0.58, blue: 0.59),
        gutterBackgroundColor: Color(red: 0.00, green: 0.15, blue: 0.19),
        gutterTextColor: Color(red: 0.35, green: 0.43, blue: 0.46),
        selectionColor: Color(red: 0.07, green: 0.26, blue: 0.30).opacity(0.8),
        columnSelectionColor: Color(red: 0.10, green: 0.30, blue: 0.35).opacity(0.5),
        cursorColor: Color(red: 0.51, green: 0.58, blue: 0.59),
        currentLineHighlight: Color.white.opacity(0.03),
        lineNumberColor: Color(red: 0.35, green: 0.43, blue: 0.46),
        tokenColors: [
            .keyword: Color(red: 0.52, green: 0.60, blue: 0.00),
            .type: Color(red: 0.71, green: 0.54, blue: 0.00),
            .string: Color(red: 0.16, green: 0.63, blue: 0.60),
            .number: Color(red: 0.83, green: 0.21, blue: 0.51),
            .comment: Color(red: 0.35, green: 0.43, blue: 0.46),
            .preprocessor: Color(red: 0.80, green: 0.29, blue: 0.09),
            .operator: Color(red: 0.52, green: 0.60, blue: 0.00),
            .function: Color(red: 0.15, green: 0.55, blue: 0.82),
            .variable: Color(red: 0.15, green: 0.55, blue: 0.82),
            .constant: Color(red: 0.83, green: 0.21, blue: 0.51),
            .attribute: Color(red: 0.71, green: 0.54, blue: 0.00),
            .tag: Color(red: 0.15, green: 0.55, blue: 0.82),
            .tagAttribute: Color(red: 0.71, green: 0.54, blue: 0.00),
            .escape: Color(red: 0.80, green: 0.29, blue: 0.09),
            .regex: Color(red: 0.16, green: 0.63, blue: 0.60),
            .heading: Color(red: 0.71, green: 0.54, blue: 0.00),
            .link: Color(red: 0.15, green: 0.55, blue: 0.82),
            .bold: Color(red: 0.52, green: 0.60, blue: 0.00),
            .italic: Color(red: 0.42, green: 0.44, blue: 0.77),
            .plain: Color(red: 0.51, green: 0.58, blue: 0.59),
        ]
    )
    
    /// All available themes
    static let allThemes: [EditorTheme] = [
        .defaultDark,
        .defaultLight,
        .monokai,
        .solarizedDark,
    ]
}
