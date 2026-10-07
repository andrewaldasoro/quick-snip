import OSLog

@MainActor
protocol OnboardingPresenting: AnyObject {
    func show()
}

/// Routes launch and capture requests: onboarding when Screen Recording is missing,
/// otherwise the capture flow.
@MainActor
final class CaptureCoordinator {
    private let logger = Logger(subsystem: Log.subsystem, category: "capture")
    private let permission: ScreenRecordingPermission
    private let onboarding: any OnboardingPresenting
    private let startCapture: @MainActor () -> Void

    init(
        permission: ScreenRecordingPermission,
        onboarding: any OnboardingPresenting,
        startCapture: @escaping @MainActor () -> Void
    ) {
        self.permission = permission
        self.onboarding = onboarding
        self.startCapture = startCapture
    }

    func appDidLaunch() {
        if !permission.isGranted {
            onboarding.show()
        }
    }

    func captureRequested() {
        permission.refresh()
        guard permission.isGranted else {
            logger.notice("Capture requested without Screen Recording permission")
            onboarding.show()
            return
        }
        logger.info("Capture requested")
        startCapture()
    }
}
