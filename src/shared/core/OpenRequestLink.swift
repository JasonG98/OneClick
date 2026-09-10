import Foundation

enum OpenRequestLink {
    static func make(requestID: UUID) -> URL {
        // The only interpolated value is a UUID, so this URL is always valid.
        URL(string: "oneclick://open?request=\(requestID.uuidString)")!
    }

    static func requestID(for url: URL) -> UUID? {
        guard url.scheme == "oneclick", url.host == "open",
              url.path.isEmpty, url.user == nil, url.password == nil, url.port == nil,
              url.fragment == nil,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "request",
              let rawID = items[0].value else { return nil }
        return UUID(uuidString: rawID)
    }
}
