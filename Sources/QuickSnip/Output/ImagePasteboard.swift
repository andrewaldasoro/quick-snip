import AppKit

@MainActor
protocol ImagePasteboard {
    func writePNG(_ data: Data)
}

struct SystemImagePasteboard: ImagePasteboard {
    func writePNG(_ data: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .png)
    }
}
