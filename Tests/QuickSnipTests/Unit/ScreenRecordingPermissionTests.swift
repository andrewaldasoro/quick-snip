import Testing
@testable import QuickSnip

@MainActor
struct ScreenRecordingPermissionTests {
    @Test func settingsURLTargetsScreenCapturePane() {
        #expect(ScreenRecordingPermission.settingsURL.scheme == "x-apple.systempreferences")
        #expect(ScreenRecordingPermission.settingsURL.absoluteString.hasSuffix("Privacy_ScreenCapture"))
    }

    @Test(arguments: [true, false])
    func initialStateComesFromPreflight(granted: Bool) {
        let access = FakeScreenCaptureAccess(granted: granted)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())
        #expect(permission.isGranted == granted)
        #expect(access.preflightCount == 1)
    }

    @Test func refreshPicksUpGrantAndRevocation() {
        let access = FakeScreenCaptureAccess(granted: false)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())

        access.granted = true
        permission.refresh()
        #expect(permission.isGranted)

        access.granted = false
        permission.refresh()
        #expect(!permission.isGranted)
    }

    @Test func requestUpdatesStateFromSystemResult() {
        let access = FakeScreenCaptureAccess(granted: false, grantOnRequest: true)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())

        permission.request()

        #expect(access.requestCount == 1)
        #expect(permission.isGranted)
    }

    @Test func requestDeniedStaysNotGranted() {
        let access = FakeScreenCaptureAccess(granted: false)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())

        permission.request()

        #expect(!permission.isGranted)
    }

    @Test func openSystemSettingsOpensScreenCapturePane() {
        let opener = SpyURLOpener()
        let permission = ScreenRecordingPermission(access: FakeScreenCaptureAccess(granted: false), urlOpener: opener)

        permission.openSystemSettings()

        #expect(opener.opened == [ScreenRecordingPermission.settingsURL])
    }
}
