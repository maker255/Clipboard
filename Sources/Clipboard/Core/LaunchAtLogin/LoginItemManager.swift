import Foundation
import ServiceManagement

/// macOS 13+ launch-at-login via `SMAppService.mainApp`.
public final class LoginItemManager {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// `notFound` on a fresh install is normal — it means "never registered".
    /// UI should render that as "off".
    public var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    public var lastRegisterError: String? {
        switch status {
        case .notRegistered: return "Not registered."
        case .enabled:       return nil
        case .requiresApproval:
            return "Launch-at-login requires approval in System Settings > General > Login Items."
        case .notFound:
            return "Clipboard.app must be in /Applications for launch-at-login to work reliably. Move the app and try again."
        @unknown default:
            return "Unknown status."
        }
    }
}
