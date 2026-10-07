import AppKit
import Testing
@testable import QuickSnip

struct OverlayKeyMapTests {
    private func command(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags = [], _ chars: String? = nil) -> OverlayCommand? {
        OverlayKeyMap.command(keyCode: keyCode, modifiers: modifiers, charactersIgnoringModifiers: chars)
    }

    @Test func escapeCancels() {
        #expect(command(OverlayKeyMap.escape) == .cancel)
    }

    @Test func returnAndEnterCopy() {
        #expect(command(OverlayKeyMap.returnKey) == .copy)
        #expect(command(OverlayKeyMap.enterKey, .numericPad) == .copy)
    }

    @Test func commandCCopies() {
        #expect(command(8, .command, "c") == .copy)
    }

    @Test func commandSSaves() {
        #expect(command(1, .command, "s") == .save)
    }

    @Test func capsLockDoesNotBreakShortcuts() {
        #expect(command(8, [.command, .capsLock], "C") == .copy)
        #expect(command(OverlayKeyMap.escape, .capsLock) == .cancel)
    }

    @Test(arguments: [
        (UInt16(8), NSEvent.ModifierFlags(), "c"),
        (UInt16(8), NSEvent.ModifierFlags([.command, .shift]), "c"),
        (UInt16(1), NSEvent.ModifierFlags([.command, .option]), "s"),
        (OverlayKeyMap.escape, NSEvent.ModifierFlags.command, nil),
        (UInt16(0), NSEvent.ModifierFlags.command, "a"),
    ] as [(UInt16, NSEvent.ModifierFlags, String?)])
    func otherKeysDoNothing(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, chars: String?) {
        #expect(command(keyCode, modifiers, chars) == nil)
    }

    @Test func eventWrapperReadsKeyDownEvents() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
            context: nil, characters: "s", charactersIgnoringModifiers: "s", isARepeat: false, keyCode: 1
        ))
        #expect(OverlayKeyMap.command(for: event) == .save)
    }

    @Test func eventWrapperIgnoresKeyUp() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53
        ))
        #expect(OverlayKeyMap.command(for: event) == nil)
    }
}

struct OverlayKeyMapEditingTests {
    private func command(_ keyCode: UInt16, _ modifiers: NSEvent.ModifierFlags = [], _ chars: String? = nil) -> OverlayCommand? {
        OverlayKeyMap.command(keyCode: keyCode, modifiers: modifiers, charactersIgnoringModifiers: chars)
    }

    @Test func commandZUndoes() {
        #expect(command(6, .command, "z") == .undo)
    }

    @Test func commandShiftZRedoes() {
        // charactersIgnoringModifiers keeps Shift, so it arrives as "Z".
        #expect(command(6, [.command, .shift], "Z") == .redo)
    }

    @Test func deleteKeysRemoveSelectedAnnotation() {
        #expect(command(OverlayKeyMap.deleteKey) == .deleteAnnotation)
        #expect(command(OverlayKeyMap.forwardDeleteKey, .function) == .deleteAnnotation)
    }

    @Test func modifiedDeleteDoesNothing() {
        #expect(command(OverlayKeyMap.deleteKey, .command) == nil)
    }
}
