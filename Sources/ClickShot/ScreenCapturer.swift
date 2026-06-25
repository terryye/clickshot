import AppKit
import ScreenCaptureKit

/// Captures a screen region using ScreenCaptureKit and crops it to the requested
/// rectangle, accounting for Retina scale and the Quartz/AppKit Y-axis flip.
final class ScreenCapturer {
    /// Captures the given rectangle (in AppKit global, bottom-left coordinates)
    /// and returns an `NSImage` sized in points. The completion runs on the main
    /// queue. `nil` indicates failure (e.g. missing permission).
    func capture(appKitRect rect: CGRect, completion: @escaping (NSImage?) -> Void) {
        guard let screen = SelectionRendering.targetScreen(for: rect),
              let displayID = screen.displayID else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let scale = screen.backingScaleFactor

        // Clamp the selection to the target display: a region spanning multiple
        // monitors is captured only from the display it overlaps most (the part on
        // other displays is dropped — spanning capture is a documented non-goal).
        let clamped = rect.intersection(screen.frame)
        guard !clamped.isNull, clamped.width >= 1, clamped.height >= 1 else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        Task {
            let image = await self.captureImage(displayID: displayID, screenFrame: screen.frame, selection: clamped, scale: scale)
            DispatchQueue.main.async { completion(image) }
        }
    }

    private func captureImage(displayID: CGDirectDisplayID, screenFrame: CGRect, selection: CGRect, scale: CGFloat) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * scale)
            config.height = Int(CGFloat(display.height) * scale)
            config.showsCursor = false
            config.captureResolution = .best

            let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            // Convert the selection into top-left pixel space within the display.
            let localX = selection.minX - screenFrame.minX
            let localYFromBottom = selection.minY - screenFrame.minY
            let localYFromTop = screenFrame.height - (localYFromBottom + selection.height)

            let cropRect = CGRect(
                x: (localX * scale).rounded(),
                y: (localYFromTop * scale).rounded(),
                width: (selection.width * scale).rounded(),
                height: (selection.height * scale).rounded()
            ).intersection(CGRect(x: 0, y: 0, width: fullImage.width, height: fullImage.height))

            guard !cropRect.isNull, cropRect.width >= 1, cropRect.height >= 1,
                  let cropped = fullImage.cropping(to: cropRect) else {
                return nil
            }

            return NSImage(cgImage: cropped, size: NSSize(width: selection.width, height: selection.height))
        } catch {
            NSLog("ClickShot: ScreenCaptureKit error: \(error)")
            return nil
        }
    }

}

private extension NSScreen {
    /// The Core Graphics display ID backing this screen, if available.
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID
    }
}
