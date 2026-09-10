import AppKit
import FinderSync
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class SettingsModel {
    var settings = Settings()
    var extensionEnabled = false
    var errorMessage: String?
    var availableApplications: [String: URL] = [:]
    var configurationAvailable = false
    private var repository: SettingsRepository?
    private var notificationTokens: [NSObjectProtocol] = []

    init() {
        do {
            let repository = try SharedEnvironment.repository()
            self.repository = repository
            let url = try SharedEnvironment.containerURL().appendingPathComponent("settings.json")
            if FileManager.default.fileExists(atPath: url.path) {
                settings = try repository.load()
            } else {
                settings = Settings.initial(home: FileManager.default.homeDirectoryForCurrentUser)
                try repository.save(settings)
            }
            configurationAvailable = true
        } catch { errorMessage = error.localizedDescription }
        refresh()
        notificationTokens.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        notificationTokens.append(DistributedNotificationCenter.default().addObserver(forName: SharedEnvironment.errorOccurred, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readActionError() }
        })
    }

    var availableCount: Int {
        settings.targets.filter { $0.isEnabled && availableApplications[$0.id] != nil }.count
    }

    func refresh() {
        extensionEnabled = FIFinderSyncController.isExtensionEnabled
        let resolver = ApplicationResolver()
        availableApplications = Dictionary(uniqueKeysWithValues: settings.targets.compactMap { target in
            resolver.applicationURL(for: target).map { (target.id, $0) }
        })
        readActionError()
    }

    func readActionError() {
        if let message = SharedEnvironment.takeError() {
            errorMessage = message
            NSApp.activate()
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
    }

    func save() {
        guard configurationAvailable, let repository else { return }
        do {
            try repository.save(settings)
            DistributedNotificationCenter.default().postNotificationName(SharedEnvironment.settingsChanged, object: nil, userInfo: nil, deliverImmediately: true)
        } catch { errorMessage = error.localizedDescription }
    }

    func setEnabled(_ id: String, _ enabled: Bool) {
        guard let index = settings.targets.firstIndex(where: { $0.id == id }) else { return }
        settings.targets[index].isEnabled = enabled
        save()
    }

    func move(from indices: IndexSet, to destination: Int) {
        settings.targets.move(fromOffsets: indices, toOffset: destination)
        save()
    }

    func move(_ id: String, by offset: Int) {
        guard let index = settings.targets.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard settings.targets.indices.contains(destination) else { return }
        settings.targets.swapAt(index, destination)
        save()
    }

    func remove(_ id: String) {
        settings.targets.removeAll { $0.id == id }
        save()
    }

    func addApplication() {
        let panel = NSOpenPanel()
        panel.title = "添加到右键菜单"
        panel.message = "选择用来打开文件或文件夹的应用。"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { continue }
            guard !settings.targets.contains(where: { $0.bundleIdentifier == identifier }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            settings.targets.append(OpenTarget(id: UUID().uuidString, name: name, kind: .application, bundleIdentifier: identifier, applicationURL: url, isEnabled: true))
        }
        save()
        refresh()
    }

    func addDirectory() {
        let panel = NSOpenPanel()
        panel.title = "添加右键菜单覆盖目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !settings.directories.contains(url) {
            settings.directories.append(url)
        }
        save()
    }

    func removeDirectory(_ url: URL) {
        settings.directories.removeAll { $0 == url }
        save()
    }

    func showExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
