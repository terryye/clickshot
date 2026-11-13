import Foundation

/// Lets this app change the cursor while it is **not** the active app.
///
/// AppKit normally ignores `NSCursor.set()` from a background app (the app that
/// owns the pointer wins). The middle-button drag must show a crosshair without
/// activating ClickShot, because activation steals focus from the user's window.
/// The window server's private `SetsCursorInBackground` connection property lifts
/// that restriction. Symbols are resolved at runtime so a future OS that drops
/// them degrades to "no crosshair" rather than failing to launch.
enum BackgroundCursor {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias SetPropertyFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    static func enable() {
        let handle = dlopen(nil, RTLD_NOW)
        guard let connSym = dlsym(handle, "CGSMainConnectionID"),
              let setSym = dlsym(handle, "CGSSetConnectionProperty") else {
            NSLog("ClickShot: background cursor API unavailable")
            return
        }
        let connection = unsafeBitCast(connSym, to: ConnectionFn.self)()
        let setProperty = unsafeBitCast(setSym, to: SetPropertyFn.self)
        let status = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        if status != 0 {
            NSLog("ClickShot: SetsCursorInBackground failed (\(status))")
        }
    }
}
