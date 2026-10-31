import Foundation
import Testing

@testable import QuickSnip

@MainActor
struct AppSettingsTests {
    private let fallback = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)

    @Test func defaultsWhenNothingStored() {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(settings.saveDirectory == fallback)
        #expect(settings.imageFormat == .png)
        #expect(settings.showThumbnail)
        #expect(settings.showMenuBarIcon)
        #expect(settings.textFont == .system)
        #expect(settings.textSize == TextSize.default)
    }

    @Test func textFontAndSizePersist() {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        settings.textFont = .family("Avenir Next")
        settings.textSize = 48

        let reloaded = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(reloaded.textFont == .family("Avenir Next"))
        #expect(reloaded.textSize == 48)
    }

    @Test func storedTextValuesOutOfRangeOrUnknownAreRepaired() {
        let store = TestDefaults()
        store.defaults.set("comic", forKey: AppSettings.Key.textFont)
        store.defaults.set(5000.0, forKey: AppSettings.Key.textSize)

        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(settings.textFont == .system)
        #expect(settings.textSize == TextSize.range.upperBound)
    }

    @Test func changesPersistAcrossInstances() {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        settings.saveDirectory = URL(fileURLWithPath: "/Users/test/Shots", isDirectory: true)
        settings.imageFormat = .jpeg
        settings.showThumbnail = false
        settings.showMenuBarIcon = false

        let reloaded = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(reloaded.saveDirectory.path == "/Users/test/Shots")
        #expect(reloaded.imageFormat == .jpeg)
        #expect(!reloaded.showThumbnail)
        #expect(!reloaded.showMenuBarIcon)
    }

    @Test func shapeAndArrowHeadsPersistAndDefaultToRectangleAndOneHead() {
        let store = TestDefaults()
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(settings.shape == .rectangle)
        #expect(settings.arrowHeads == .end)
        settings.shape = .oval
        settings.arrowHeads = .both

        let reloaded = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(reloaded.shape == .oval)
        #expect(reloaded.arrowHeads == .both)
    }

    @Test func unknownStoredShapeFallsBack() {
        let store = TestDefaults()
        store.defaults.set("star", forKey: AppSettings.Key.shape)
        store.defaults.set("three", forKey: AppSettings.Key.arrowHeads)
        let settings = AppSettings(defaults: store.defaults, defaultDirectory: fallback)
        #expect(settings.shape == .rectangle)
        #expect(settings.arrowHeads == .end)
    }

    @Test func unknownStoredFormatFallsBackToPNG() {
        let store = TestDefaults()
        store.defaults.set("webp", forKey: AppSettings.Key.imageFormat)
        #expect(AppSettings(defaults: store.defaults, defaultDirectory: fallback).imageFormat == .png)
    }

    @Test func displayPathAbbreviatesHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(GeneralSettingsPage.displayPath(home.appendingPathComponent("Desktop")) == "~/Desktop")
    }
}

@MainActor
struct LaunchAtLoginModelTests {
    struct RegistrationError: LocalizedError {
        var errorDescription: String? { "Needs approval in System Settings" }
    }

    @Test func reflectsServiceStateOnInit() {
        let service = FakeLoginItemService()
        service.isEnabled = true
        #expect(LaunchAtLoginModel(service: service).isEnabled)
    }

    @Test func enablingRegisters() {
        let service = FakeLoginItemService()
        let model = LaunchAtLoginModel(service: service)
        model.setEnabled(true)
        #expect(service.requests == [true])
        #expect(model.isEnabled)
        #expect(model.errorMessage == nil)
    }

    @Test func failureKeepsRealStateAndShowsError() {
        let service = FakeLoginItemService()
        service.error = RegistrationError()
        let model = LaunchAtLoginModel(service: service)
        model.setEnabled(true)
        #expect(!model.isEnabled)
        #expect(model.errorMessage == "Needs approval in System Settings")
    }

    @Test func successClearsPreviousError() {
        let service = FakeLoginItemService()
        service.error = RegistrationError()
        let model = LaunchAtLoginModel(service: service)
        model.setEnabled(true)
        service.error = nil
        model.setEnabled(true)
        #expect(model.errorMessage == nil)
        #expect(model.isEnabled)
    }
}
