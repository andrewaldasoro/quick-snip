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
}
