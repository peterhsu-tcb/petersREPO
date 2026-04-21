import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()
            Divider()
            if let doc = state.activeDocument {
                if state.showFindBar {
                    FindBarView(document: doc)
                    Divider()
                }
                EditorContainerView(document: doc)
                    .environmentObject(state)
            } else {
                Text("No document open")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            StatusBarView(document: state.activeDocument)
        }
    }
}

struct TabBarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(state.documents) { doc in
                    HStack(spacing: 6) {
                        Text(doc.displayName + (doc.isDirty ? " •" : ""))
                            .lineLimit(1)
                        Button(action: { state.closeDocument(doc.id) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(state.activeDocumentID == doc.id ? Color.accentColor.opacity(0.2) : Color.clear)
                    .onTapGesture { state.activeDocumentID = doc.id }
                }
            }
        }
        .frame(height: 28)
    }
}

struct EditorContainerView: View {
    @ObservedObject var document: Document
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch document.mode {
            case .text, .column:
                TextEditorView(document: document, state: state)
            case .hex:
                HexEditorView(document: document, state: state)
            }
        }
    }
}
