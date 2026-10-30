/// The pages in the Settings sidebar, in order.
enum SettingsPage: String, CaseIterable, Identifiable, Sendable {
    case general, shortcuts, whatsNew, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .whatsNew: "What's New"
        case .about: "About & Updates"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "keyboard"
        case .whatsNew: "sparkles"
        case .about: "info.circle"
        }
    }
}
