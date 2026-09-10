import SwiftUI

struct DirectoryRow: View {
    let directory: URL
    let homeDirectory: URL
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)

            path
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(directory.path)

            Spacer(minLength: 12)

            Button("移除目录", systemImage: "minus.circle", action: remove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("移除该覆盖目录")
        }
        .padding(.vertical, 4)
    }

    /// The leaf name carries the row; the parent path stays quiet so a list of
    /// long home-relative paths is still scannable.
    private var path: Text {
        let abbreviated = abbreviatedPath
        guard let separator = abbreviated.lastIndex(of: "/"), separator != abbreviated.startIndex else {
            return Text(abbreviated).foregroundStyle(.primary)
        }
        let parent = abbreviated[..<separator] + "/"
        let leaf = abbreviated[abbreviated.index(after: separator)...]
        return Text(parent).foregroundStyle(.secondary) + Text(leaf).foregroundStyle(.primary)
    }

    private var abbreviatedPath: String {
        let path = directory.path
        let home = homeDirectory.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
