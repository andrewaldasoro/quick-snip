import Observation
import ServiceManagement

@MainActor
protocol LoginItemService {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLoginItemService: LoginItemService {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Launch-at-login toggle state for Settings, surfacing registration errors.
@MainActor
@Observable
final class LaunchAtLoginModel {
    @ObservationIgnored private let service: any LoginItemService
    private(set) var isEnabled: Bool
    private(set) var errorMessage: String?

    init(service: any LoginItemService = SystemLoginItemService()) {
        self.service = service
        isEnabled = service.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            try service.setEnabled(enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = service.isEnabled
    }
}
