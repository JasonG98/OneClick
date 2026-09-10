import Foundation

struct OpenRequest: Codable, Equatable, Sendable {
    let targetID: String
    let urls: [URL]
    let createdAt: Date
}

struct OpenRequestRepository: Sendable {
    private static let maximumRequestSize = 1_048_576
    private static let maximumAge: TimeInterval = 120
    private static let futureTolerance: TimeInterval = 5

    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    func enqueue(
        targetID: String,
        urls: [URL],
        now: Date = .now
    ) throws -> UUID {
        guard directory.isLocalFileURL else {
            throw OneClickCoreError.invalidOpenRequest("请求目录必须是本地绝对路径。")
        }

        let id = UUID()
        let request = OpenRequest(targetID: targetID, urls: urls, createdAt: now)
        try validate(request, now: now, checksAge: false)

        let data: Data
        do {
            data = try JSONEncoder().encode(request)
        } catch {
            throw OneClickCoreError.cannotStoreOpenRequest
        }
        guard data.count <= Self.maximumRequestSize else {
            throw OneClickCoreError.openRequestTooLarge
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try removeStaleRequests(now: now)
            try data.write(to: fileURL(for: id), options: .atomic)
        } catch let error as OneClickCoreError {
            throw error
        } catch {
            throw OneClickCoreError.cannotStoreOpenRequest
        }
        return id
    }

    func consume(id: UUID, now: Date = .now) throws -> OpenRequest {
        guard directory.isLocalFileURL else {
            throw OneClickCoreError.invalidOpenRequest("请求目录必须是本地绝对路径。")
        }

        let url = fileURL(for: id)
        let size: Int
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        } catch {
            throw OneClickCoreError.openRequestUnavailable
        }

        if size > Self.maximumRequestSize {
            try removeConsumedFile(at: url)
            throw OneClickCoreError.openRequestTooLarge
        }

        let data: Data
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            data = try handle.read(upToCount: Self.maximumRequestSize + 1) ?? Data()
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw OneClickCoreError.cannotConsumeOpenRequest
        }

        try removeConsumedFile(at: url)
        guard data.count <= Self.maximumRequestSize else {
            throw OneClickCoreError.openRequestTooLarge
        }

        let request: OpenRequest
        do {
            request = try JSONDecoder().decode(OpenRequest.self, from: data)
        } catch {
            throw OneClickCoreError.invalidOpenRequest("请求内容已损坏。")
        }
        try validate(request, now: now, checksAge: true)
        return request
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("open-\(id.uuidString).json")
    }

    private func validate(_ request: OpenRequest, now: Date, checksAge: Bool) throws {
        guard !request.targetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OneClickCoreError.invalidOpenRequest("目标标识不能为空。")
        }
        guard !request.urls.isEmpty else {
            throw OneClickCoreError.invalidOpenRequest("至少需要一个文件或文件夹。")
        }
        guard request.urls.allSatisfy(\.isLocalFileURL) else {
            throw OneClickCoreError.invalidOpenRequest("仅支持本地绝对路径。")
        }

        if checksAge {
            let age = now.timeIntervalSince(request.createdAt)
            guard age >= -Self.futureTolerance, age <= Self.maximumAge else {
                throw OneClickCoreError.openRequestExpired
            }
        }
    }

    private func removeStaleRequests(now: Date) throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        for url in contents where isOwnedRequestFilename(url.lastPathComponent) {
            let values = try url.resourceValues(
                forKeys: [.contentModificationDateKey, .isRegularFileKey]
            )
            guard values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) > Self.maximumAge else {
                continue
            }
            try FileManager.default.removeItem(at: url)
        }
    }

    private func isOwnedRequestFilename(_ filename: String) -> Bool {
        let prefix = "open-"
        let suffix = ".json"
        guard filename.hasPrefix(prefix), filename.hasSuffix(suffix) else { return false }
        let start = filename.index(filename.startIndex, offsetBy: prefix.count)
        let end = filename.index(filename.endIndex, offsetBy: -suffix.count)
        return UUID(uuidString: String(filename[start..<end])) != nil
    }

    private func removeConsumedFile(at url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw OneClickCoreError.cannotConsumeOpenRequest
        }
    }
}
