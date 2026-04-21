import SwiftUI

struct FindBarView: View {
    @ObservedObject var document: Document
    @State private var query: String = ""
    @State private var replacement: String = ""
    @State private var caseSensitive = false
    @State private var wholeWord = false
    @State private var useRegex = false
    @State private var lastMatchEnd: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                TextField("Find", text: $query, onCommit: findNext)
                    .textFieldStyle(.roundedBorder)
                Button("Next", action: findNext)
                    .keyboardShortcut(.return, modifiers: [])
                Toggle("Aa",  isOn: $caseSensitive).toggleStyle(.button)
                Toggle("\\b", isOn: $wholeWord)    .toggleStyle(.button)
                Toggle(".*",  isOn: $useRegex)     .toggleStyle(.button)
            }
            HStack {
                TextField("Replace", text: $replacement)
                    .textFieldStyle(.roundedBorder)
                Button("Replace All", action: replaceAll)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var options: FindReplaceService.Options {
        FindReplaceService.Options(
            caseSensitive: caseSensitive,
            wholeWord: wholeWord,
            regex: useRegex
        )
    }

    private func findNext() {
        guard let range = FindReplaceService.find(query, in: document.text, options: options, from: lastMatchEnd) else {
            NSSound.beep()
            return
        }
        lastMatchEnd = range.location + range.length
        document.cursor = range.location
        document.selection = range
    }

    private func replaceAll() {
        let (newText, count) = FindReplaceService.replaceAll(query, with: replacement, in: document.text, options: options)
        if count > 0 {
            document.setText(newText)
        } else {
            NSSound.beep()
        }
    }
}
