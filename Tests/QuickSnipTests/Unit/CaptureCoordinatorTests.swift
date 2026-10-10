import Testing

@testable import QuickSnip

@MainActor
struct CaptureCoordinatorTests {
    private func makeCoordinator(granted: Bool) -> (CaptureCoordinator, FakeScreenCaptureAccess, SpyOnboarding, () -> Int) {
        let access = FakeScreenCaptureAccess(granted: granted)
        let onboarding = SpyOnboarding()
        var captures = 0
        let coordinator = CaptureCoordinator(
            permission: ScreenRecordingPermission(access: access, urlOpener: SpyURLOpener()),
            onboarding: onboarding,
            startCapture: { captures += 1 }
        )
        return (coordinator, access, onboarding, { captures })
    }

    @Test func launchWithoutPermissionShowsOnboarding() {
        let (coordinator, _, onboarding, captures) = makeCoordinator(granted: false)
        coordinator.appDidLaunch()
        #expect(onboarding.showCount == 1)
        #expect(captures() == 0)
    }

    @Test func launchWithPermissionSkipsOnboarding() {
        let (coordinator, _, onboarding, _) = makeCoordinator(granted: true)
        coordinator.appDidLaunch()
        #expect(onboarding.showCount == 0)
    }

    @Test func captureWithPermissionStartsCapture() async {
        let (coordinator, _, onboarding, captures) = makeCoordinator(granted: true)
        await coordinator.captureRequested()
        #expect(captures() == 1)
        #expect(onboarding.showCount == 0)
    }

    @Test func captureWithoutPermissionShowsOnboardingInstead() async {
        let (coordinator, _, onboarding, captures) = makeCoordinator(granted: false)
        await coordinator.captureRequested()
        #expect(captures() == 0)
        #expect(onboarding.showCount == 1)
    }

    @Test func captureRechecksPermissionEachTime() async {
        let (coordinator, access, _, _) = makeCoordinator(granted: true)
        let before = access.preflightCount
        await coordinator.captureRequested()
        await coordinator.captureRequested()
        #expect(access.preflightCount == before + 2)
    }
}
