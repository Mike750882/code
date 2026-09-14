import CoreData
import SwiftData
import Combine

/// Surfaces CloudKit sync status for the Settings screen's Sync row.
///
/// SwiftData's `cloudKitDatabase: .automatic` sync runs on Core Data's
/// `NSPersistentCloudKitContainer` under the hood, which posts
/// `.eventChangedNotification` for every import/export/setup activity --
/// that's public and observable even though SwiftData doesn't expose the
/// container itself. There's no public API to force CloudKit to pull
/// changes on demand; "Sync now" saves any pending local edits, which
/// queues them for export right away instead of waiting for the next
/// system-scheduled opportunity.
@MainActor
final class CloudSyncMonitor: ObservableObject {
    enum Status: Equatable {
        case idle
        case syncing
        case upToDate(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                self?.handle(notification)
            }
    }

    func requestSync(modelContext: ModelContext) {
        status = .syncing
        do {
            try modelContext.save()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event else { return }

        guard event.endDate != nil else {
            status = .syncing
            return
        }
        if let error = event.error {
            status = .failed(error.localizedDescription)
        } else {
            status = .upToDate(event.endDate ?? Date())
        }
    }
}
