import Foundation
import Sparkle

/// Sparkle, reading the appcast attached to the latest GitHub release once a day. Updates download
/// in the background; once one is ready the menu shows "Restart to Update". Local builds
/// (bundle.sh) have no feed URL and never update.
@Observable
final class Updater: NSObject {
    let isEnabled: Bool
    /// A downloaded update waiting for a restart, or (with automatic updates off) one a scheduled
    /// check found. Shown in the menu.
    private(set) var pendingUpdate: PendingUpdate?

    struct PendingUpdate: Equatable {
        let version: String
        /// Downloaded; `installNow()` relaunches into it. Otherwise `checkForUpdates()` shows it.
        let readyToInstall: Bool
    }

    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var installHandler: (() -> Void)?

    override init() {
        isEnabled = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: isEnabled, updaterDelegate: self, userDriverDelegate: self
        )
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// One switch for both: checking without downloading would leave updates waiting on a prompt.
    var automaticUpdates: Bool {
        get {
            access(keyPath: \.automaticUpdates)
            return controller.updater.automaticallyChecksForUpdates && controller.updater.automaticallyDownloadsUpdates
        }
        set {
            withMutation(keyPath: \.automaticUpdates) {
                controller.updater.automaticallyChecksForUpdates = newValue
                controller.updater.automaticallyDownloadsUpdates = newValue
            }
        }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    /// Installs the downloaded update and relaunches. Without one ready, opens the update window.
    func installNow() {
        if let installHandler { installHandler() } else { checkForUpdates() }
    }
}

extension Updater: SPUUpdaterDelegate {
    /// Sparkle downloaded an update and would install it on quit. A menu bar app rarely quits, so
    /// take over and offer "Restart to Update" in the menu instead.
    func updater(
        _ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        installHandler = immediateInstallHandler
        pendingUpdate = PendingUpdate(version: item.displayVersionString, readyToInstall: true)
        return true
    }
}

/// Gentle reminders: a scheduled check that finds an update while the app is in the background
/// shows up in the menu instead of an update window popping up over whatever the user is doing.
extension Updater: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate, pendingUpdate?.readyToInstall != true else { return }
        pendingUpdate = PendingUpdate(version: update.displayVersionString, readyToInstall: false)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        clearReminder()
    }

    func standardUserDriverWillFinishUpdateSession() {
        clearReminder()
    }

    /// A downloaded update stays flagged until it's installed; only the gentle reminder clears.
    private func clearReminder() {
        if pendingUpdate?.readyToInstall == false { pendingUpdate = nil }
    }
}
