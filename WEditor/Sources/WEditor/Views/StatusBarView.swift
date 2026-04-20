import SwiftUI

/// Status bar at the bottom of the editor
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        let theme = settings.currentTheme
        
        HStack(spacing: 16) {
            // Cursor position
            if let doc = appState.activeDocument {
                HStack(spacing: 4) {
                    Text("Ln \(doc.cursorPosition.line + 1)")
                    Text("Col \(doc.cursorPosition.column + 1)")
                }
                
                Divider().frame(height: 14)
                
                // Selection info
                if let colSel = doc.columnSelection {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.3x1")
                            .font(.system(size: 10))
                        Text("\(colSel.lineCount) lines × \(colSel.width) cols")
                    }
                    .foregroundColor(.accentColor)
                    
                    Divider().frame(height: 14)
                }
                
                // Line count
                Text("\(doc.lineCount) lines")
                
                Divider().frame(height: 14)
                
                // Language
                Menu {
                    ForEach(SyntaxLanguage.allCases) { lang in
                        Button(lang.rawValue) {
                            doc.language = lang
                        }
                    }
                } label: {
                    Text(doc.language.rawValue)
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 120)
                
                Divider().frame(height: 14)
                
                // Encoding
                Text(encodingName(doc.encoding))
                
                Divider().frame(height: 14)
                
                // Line ending
                Text(doc.lineEnding.rawValue)
                
                Divider().frame(height: 14)
                
                // Column mode indicator
                if appState.isColumnEditMode {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.3x1")
                        Text("COL")
                    }
                    .foregroundColor(.accentColor)
                    
                    Divider().frame(height: 14)
                }
                
                // HTML edit mode indicator
                if doc.isHTML {
                    Menu {
                        ForEach(HTMLEditMode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) {
                                doc.htmlEditMode = mode
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: doc.htmlEditMode == .source ? "chevron.left.forwardslash.chevron.right" : "globe")
                                .font(.system(size: 10))
                            Text("HTML: \(doc.htmlEditMode.rawValue)")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 120)
                    
                    Divider().frame(height: 14)
                }
            }
            
            Spacer()
            
            // Theme selector
            Menu {
                ForEach(EditorTheme.allThemes, id: \.id) { theme in
                    Button(theme.name) {
                        settings.selectedThemeId = theme.id
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: theme.isDark ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 10))
                    Text(theme.name)
                        .font(.system(size: 11))
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 140)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(theme.textColor.opacity(0.7))
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(theme.gutterBackgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(theme.gutterTextColor.opacity(0.2)),
            alignment: .top
        )
    }
    
    private func encodingName(_ encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO-8859-1"
        case .windowsCP1252: return "Windows-1252"
        case .japaneseEUC: return "EUC-JP"
        case .shiftJIS: return "Shift-JIS"
        default: return "UTF-8"
        }
    }
}
