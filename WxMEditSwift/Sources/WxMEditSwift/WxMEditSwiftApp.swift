import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct WxMEditSwiftApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("WxMEditSwift") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") { state.newDocument() }
                    .keyboardShortcut("n")
                Button("Open…") { openFile() }
                    .keyboardShortcut("o")
                Button("Save") { saveActive(saveAs: false) }
                    .keyboardShortcut("s")
                    .disabled(state.activeDocument == nil)
                Button("Save As…") { saveActive(saveAs: true) }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(state.activeDocument == nil)
            }
            CommandMenu("Mode") {
                Button("Text Mode")   { state.activeDocument?.mode = .text   }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Column Mode") { state.activeDocument?.mode = .column }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Hex Mode")    { state.activeDocument?.mode = .hex    }
                    .keyboardShortcut("3", modifiers: [.command, .option])
            }
            CommandMenu("Search") {
                Button("Find…") { state.showFindBar.toggle() }
                    .keyboardShortcut("f")
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let doc = try FileService.open(url)
                state.addDocument(doc)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func saveActive(saveAs: Bool) {
        guard let doc = state.activeDocument else { return }
        if saveAs || doc.url == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = doc.displayName
            if panel.runModal() == .OK, let url = panel.url {
                do { try FileService.save(doc, to: url) } catch {
                    NSAlert(error: error).runModal()
                }
            }
        } else {
            do { try FileService.save(doc) } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
