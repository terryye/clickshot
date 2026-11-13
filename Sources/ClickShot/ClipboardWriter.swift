import AppKit

/// Writes a captured image to the general pasteboard so it can be pasted anywhere.
enum ClipboardWriter {
    /// Writes a **single** pasteboard item carrying both PNG and TIFF. Writing
    /// them as separate items makes apps that accept multiple items (Slack, Notes,
    /// browsers, …) paste the screenshot twice.
    static func write(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation else { return }

        let item = NSPasteboardItem()
        // PNG first: types are ordered by fidelity/preference.
        if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            item.setData(png, forType: .png)
        }
        item.setData(tiff, forType: .tiff)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
