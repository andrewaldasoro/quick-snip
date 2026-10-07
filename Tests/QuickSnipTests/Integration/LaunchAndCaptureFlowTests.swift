import Testing
@testable import QuickSnip

/// Common use cases end to end through the real permission + coordinator wiring,
/// with only the OS seams (TCC, URL opening, onboarding window) faked.
@MainActor
@Suite("Launch and capture flow")
struct LaunchAndCaptureFlowTests {
    @Test func firstLaunchGrantThenCapture() async {
        let access = FakeScreenCaptureAccess(granted: false, grantOnRequest: true)
        let opener = SpyURLOpener()
        let permission = ScreenRecordingPermission(access: access, urlOpener: opener)
        let onboarding = SpyOnboarding()
        var captures = 0
        let coordinator = CaptureCoordinator(permission: permission, onboarding: onboarding) { captures += 1 }

        // Launch: no permission → onboarding.
        coordinator.appDidLaunch()
        #expect(onboarding.showCount == 1)

        // Onboarding "Open System Settings" button.
        permission.request()
        permission.openSystemSettings()
        #expect(opener.opened == [ScreenRecordingPermission.settingsURL])
        #expect(permission.isGranted)

        // Hotkey → capture.
        await coordinator.captureRequested()
        #expect(captures == 1)
        #expect(onboarding.showCount == 1)
    }

    @Test func permissionRevokedWhileRunningRoutesBackToOnboarding() async {
        let access = FakeScreenCaptureAccess(granted: true)
        let permission = ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener())
        let onboarding = SpyOnboarding()
        var captures = 0
        let coordinator = CaptureCoordinator(permission: permission, onboarding: onboarding) { captures += 1 }

        coordinator.appDidLaunch()
        await coordinator.captureRequested()
        #expect(captures == 1)

        access.granted = false
        await coordinator.captureRequested()

        #expect(captures == 1)
        #expect(onboarding.showCount == 1)
        #expect(!permission.isGranted)
    }
}
