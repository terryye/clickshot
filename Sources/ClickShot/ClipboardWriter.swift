import AppKit

/// Writes a captured image to the general pasteboard so it can be pasted anywhere.
enum ClipboardWriter {
    static func write(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var objects: [NSPasteboardWriting] = [image]
        // Also offer PNG data for apps that prefer it over TIFF.
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            objects = [item, image]
        }

        pasteboard.writeObjects(objects)
    }
}
