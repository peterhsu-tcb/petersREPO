import SwiftUI

/// Mini map view showing document overview
struct MiniMapView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    
    private let miniMapWidth: CGFloat = 80
    private let miniMapFontSize: CGFloat = 2
    
    var body: some View {
        let theme = settings.currentTheme
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(document.lines.enumerated()), id: \.offset) { index, line in
                    Text(line.isEmpty ? " " : String(line.prefix(120)))
                        .font(.system(size: miniMapFontSize, design: .monospaced))
                        .foregroundColor(theme.textColor.opacity(0.6))
                        .lineLimit(1)
                        .frame(height: miniMapFontSize * 1.5)
                        .background(
                            index == document.cursorPosition.line ?
                                theme.currentLineHighlight.opacity(0.8) : Color.clear
                        )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .frame(width: miniMapWidth)
        .background(theme.gutterBackgroundColor.opacity(0.5))
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(theme.gutterTextColor.opacity(0.1)),
            alignment: .leading
        )
    }
}
