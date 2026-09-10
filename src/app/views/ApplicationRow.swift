import SwiftUI

struct ApplicationRow: View {
    let target: OpenTarget
    let enabled: Binding<Bool>
    let available: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = ApplicationResolver().icon(for: target) {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: target.kind == .claude ? "terminal" : "app.dashed")
                        .resizable().scaledToFit().padding(5).foregroundStyle(.tertiary)
                }
            }
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(target.name).font(.body.weight(.medium))
                if !available {
                    Text(target.kind == .claude ? "需要注册 Claude Code 深链接" : "尚未安装")
                        .font(.caption).foregroundStyle(.secondary)
                } else if target.kind == .claude {
                    Text("在选中目录开始会话").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("在右键菜单中显示 \(target.name)", isOn: enabled)
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                .disabled(!available)
        }
        .padding(.vertical, 5)
        .contextMenu {
            Button("上移", systemImage: "arrow.up", action: moveUp)
            Button("下移", systemImage: "arrow.down", action: moveDown)
            if !OpenTarget.builtIns.contains(where: { $0.id == target.id }) {
                Divider()
                Button("移除", systemImage: "minus.circle", role: .destructive, action: remove)
            }
        }
    }
}
