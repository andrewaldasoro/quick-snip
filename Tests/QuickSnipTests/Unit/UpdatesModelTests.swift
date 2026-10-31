import Testing

@testable import QuickSnip

@MainActor
struct UpdatesModelTests {
    @Test func readsTheUpdaterSetting() {
        let model = UpdatesModel(updater: FakeUpdater(automaticallyChecksForUpdates: true), activation: SpyAppActivation())
        #expect(model.checksAutomatically)
    }

    @Test func toggleChangesTheUpdaterSetting() {
        let updater = FakeUpdater(automaticallyChecksForUpdates: false)
        let model = UpdatesModel(updater: updater, activation: SpyAppActivation())

        model.checksAutomatically = true

        #expect(updater.automaticallyChecksForUpdates)
    }

    /// Sparkle's window would otherwise open behind the frontmost app (QuickSnip has no Dock icon).
    @Test func checkNowActivatesTheAppThenChecks() {
        let updater = FakeUpdater()
        let activation = SpyAppActivation()
        let model = UpdatesModel(updater: updater, activation: activation)

        model.checkNow()

        #expect(activation.activateCount == 1)
        #expect(updater.checkCount == 1)
    }

    @Test func aFoundUpdateShowsTheCardWithItsNotes() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater, activation: SpyAppActivation())
        #expect(!model.showsUpdateCard)

        updater.onCheckFinished?((version: "1.1.0", notesHTML: "<ul><li>Fonts</li></ul>"))

        #expect(model.availableUpdate == AvailableUpdate(version: "1.1.0", notes: [.init(title: "", items: ["Fonts"])]))
        #expect(model.showsUpdateCard)
    }

    @Test func anUpdateWithoutNotesHasNoLines() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater, activation: SpyAppActivation())
        updater.onCheckFinished?((version: "1.1.0", notesHTML: nil))
        #expect(model.availableUpdate?.notes.isEmpty == true)
    }

    @Test func dismissingHidesTheCardUntilANewerVersion() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater, activation: SpyAppActivation())
        updater.onCheckFinished?((version: "1.1.0", notesHTML: nil))

        model.dismissUpdateCard()
        #expect(!model.showsUpdateCard)
        updater.onCheckFinished?((version: "1.1.0", notesHTML: nil))
        #expect(!model.showsUpdateCard)

        updater.onCheckFinished?((version: "1.2.0", notesHTML: nil))
        #expect(model.showsUpdateCard)
    }

    @Test func upToDateClearsTheUpdate() {
        let updater = FakeUpdater()
        let model = UpdatesModel(updater: updater, activation: SpyAppActivation())
        updater.onCheckFinished?((version: "1.1.0", notesHTML: nil))

        updater.onCheckFinished?(nil)

        #expect(model.availableUpdate == nil)
        #expect(!model.showsUpdateCard)
    }
}
