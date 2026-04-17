import SwiftUI

/// Line number gutter view
struct GutterView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var settings: EditorSettings
    
    var body: some View {
        let theme = settings.currentTheme
        let lineCount = document.lineCount
        let gutterWidth = calculateGutterWidth(lineCount: lineCount)
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(0..<lineCount, id: \.self) { lineIndex in
                    Text("\(lineIndex + 1)")
                        .font(.system(size: settings.fontSize, design: .monospaced))
                        .foregroundColor(
                            lineIndex == document.cursorPosition.line ?
                                theme.textColor : theme.gutterTextColor
                        )
                        .frame(height: settings.fontSize * settings.lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .background(
                            lineIndex == document.cursorPosition.line && settings.highlightCurrentLine ?
                                theme.currentLineHighlight : Color.clear
                        )
                }
                
                Spacer()
                    .frame(height: 200)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: gutterWidth)
        .background(theme.gutterBackgroundColor)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundColor(theme.gutterTextColor.opacity(0.2)),
            alignment: .trailing
        )
    }
    
    private func calculateGutterWidth(lineCount: Int) -> CGFloat {
        let digits = max(String(lineCount).count, 2)
        return CGFloat(digits) * settings.fontSize * 0.65 + 24
    }
}
