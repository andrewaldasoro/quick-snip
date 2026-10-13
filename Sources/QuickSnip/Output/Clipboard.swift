import AppKit

@MainActor
protocol ClipboardWriting {
    func writePNG(_ data: Data)
    func writeText(_ text: String)
}

struct SystemClipboard: ClipboardWriting {
    func writePNG(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }

    func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
