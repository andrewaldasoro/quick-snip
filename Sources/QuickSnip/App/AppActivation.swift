import AppKit

/// Makes QuickSnip the active app so its windows get keyboard focus.
@MainActor
protocol AppActivating: AnyObject {
    func activate()
}

@MainActor
final class SystemAppActivation: AppActivating {
    /// QuickSnip has no Dock icon (`LSUIElement`), and macOS 14+ treats `NSApp.activate()`
    /// as a request the frontmost app can decline. Opened from the menu bar, Settings then
    /// showed up unfocused. `activate(ignoringOtherApps:)` still forces it; it's deprecated,
    /// so it's called through `ForcedActivating` to keep the build free of warnings.
    func activate() {
        (NSApp as any ForcedActivating).activate(ignoringOtherApps: true)
    }
}

@MainActor
private protocol ForcedActivating {
    func activate(ignoringOtherApps flag: Bool)
}

extension NSApplication: ForcedActivating {}
