/// Every keyboard shortcut, grouped for display. Capture keys come from `OverlayKeyMap`,
/// so the list always matches what the keys really do.
struct ShortcutCheatsheet: Equatable, Sendable {
    struct Entry: Hashable, Sendable {
        let action: String
        let keys: [String]
    }

    struct Section: Equatable, Identifiable, Sendable {
        let title: String
        let entries: [Entry]
        var note: String?

        var id: String { title }
    }

    static let notSet = "Not set"

    /// Capture keys in the order they're listed.
    static let captureCommands: [OverlayCommand] = [.copy, .readText, .save, .cancel, .undo, .redo, .deleteAnnotation, .toggleCheatsheet]

    let sections: [Section]

    /// Everything, for Settings and the Keyboard Shortcuts window.
    init(captureShortcut: String?) {
        let global = Section(title: "Anywhere", entries: [Entry(action: "Capture area", keys: [captureShortcut ?? Self.notSet])])
        sections = [global] + Self.captureSections
    }

    private init(sections: [Section]) {
        self.sections = sections
    }

    /// Only what works during a capture, for the overlay.
    static let overlay = ShortcutCheatsheet(sections: captureSections)

    private static let captureSections: [Section] = [
        Section(title: "While capturing", entries: entries(for: captureCommands), note: "Click a window to select it."),
        Section(
            title: "Tools",
            entries: entries(for: AnnotationTool.allCases.map(OverlayCommand.selectTool)),
            note: "Press the key again to move annotations."
        ),
        Section(title: "Colors", entries: entries(for: AnnotationColor.allCases.map(OverlayCommand.selectColor))),
        // Typing happens in the text editor, not through `OverlayKeyMap`.
        Section(
            title: "Text",
            entries: [
                Entry(action: "Start a new line", keys: ["Return"]),
                Entry(action: "Finish typing", keys: ["Esc", "⌘Return"]),
                Entry(action: "Edit placed text", keys: ["Double-click"]),
            ],
            note: "Drag with the Text tool for a box that wraps. Delete all of the text to remove it."
        ),
    ]

    private static func entries(for commands: [OverlayCommand]) -> [Entry] {
        commands.map { Entry(action: action(for: $0), keys: OverlayKeyMap.keys(for: $0)) }
    }

    static func action(for command: OverlayCommand) -> String {
        switch command {
        case .copy: "Copy to the clipboard"
        case .readText: "Read the text in the selection"
        case .save: "Save to the save folder"
        case .cancel: "Cancel the capture"
        case .undo: "Undo"
        case .redo: "Redo"
        case .deleteAnnotation: "Delete the selected annotation"
        case .toggleCheatsheet: "Show or hide these shortcuts"
        case .selectTool(let tool): tool.displayName
        case .selectColor(let color): color.displayName
        }
    }
}
