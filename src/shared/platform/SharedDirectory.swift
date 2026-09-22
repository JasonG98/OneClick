import Darwin
import Foundation

enum SharedDirectory {
    // Foundation's default home and HOME may point into the extension sandbox.
    // The account database gives both processes the same real home directory.
    static let accountHome: String? = {
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        return buffer.withUnsafeMutableBufferPointer { storage in
            guard getpwuid_r(getuid(), &entry, storage.baseAddress, storage.count, &result) == 0,
                  result != nil, let home = entry.pw_dir else { return nil }
            return String(cString: home)
        }
    }()

    static func prepare(homePath: String? = accountHome) throws -> URL {
        guard let homePath, homePath.hasPrefix("/"), homePath != "/",
              !homePath.split(separator: "/").contains("..") else {
            throw PlatformError.sharedDirectoryUnavailable
        }
        let directory = URL(fileURLWithPath: homePath, isDirectory: true)
            .appendingPathComponent("Library/Application Support/OneClick", isDirectory: true)
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
            // Serialize first-run ownership marker creation across app and extension.
            // O_NOFOLLOW also prevents adopting a directory symlink as our data.
            let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            guard descriptor >= 0 else { throw PlatformError.sharedDirectoryUnavailable }
            defer { close(descriptor) }
            guard flock(descriptor, LOCK_EX) == 0 else { throw PlatformError.sharedDirectoryUnavailable }
            defer { flock(descriptor, LOCK_UN) }

            let marker = directory.appendingPathComponent(".oneclick-owner.plist")
            if manager.fileExists(atPath: marker.path) {
                let values = try marker.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
                guard values.isSymbolicLink == false, values.isRegularFile == true,
                      (values.fileSize ?? Int.max) <= 4096,
                      let owner = try PropertyListSerialization.propertyList(from: Data(contentsOf: marker), format: nil) as? [String: String],
                      owner["CFBundleIdentifier"] == SharedEnvironment.appIdentifier else {
                    throw PlatformError.sharedDirectoryUnavailable
                }
            } else {
                guard try manager.contentsOfDirectory(atPath: directory.path).isEmpty else {
                    throw PlatformError.sharedDirectoryUnavailable
                }
                let data = try PropertyListSerialization.data(
                    fromPropertyList: ["CFBundleIdentifier": SharedEnvironment.appIdentifier], format: .xml, options: 0)
                try data.write(to: marker, options: .atomic)
            }
            return directory
        } catch {
            throw PlatformError.sharedDirectoryUnavailable
        }
    }
}
