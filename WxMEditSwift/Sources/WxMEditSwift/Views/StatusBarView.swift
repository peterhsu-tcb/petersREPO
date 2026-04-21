import SwiftUI

struct StatusBarView: View {
    var document: Document?

    var body: some View {
        HStack(spacing: 16) {
            if let doc = document {
                Text("Mode: \(doc.mode.rawValue)")
                Text("Encoding: \(doc.encoding.rawValue)")
                Text("EOL: \(doc.lineEnding.rawValue)")
                Text("Bytes: \(doc.bytes.count)")
                Spacer()
                Text("Pos: \(doc.cursor)")
            } else {
                Text("No document").foregroundColor(.secondary)
                Spacer()
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
