import AppKit
import SwiftUI

struct ApplicationRow: View {
    let target: OpenTarget
    let enabled: Binding<Bool>
    let available: Bool
    let icon: NSImage?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            IconTile(
                image: icon,
                fallbackSymbol: target.kind == .terminal ? "terminal" : "app.dashed",
                isDimmed: !target.isEnabled || !available
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(target.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(target.isEnabled && available ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    availabilityChip
                }
                supportingText
            }

            Spacer(minLength: 12)

            Toggle("在右键菜单中显示 \(target.name)", isOn: enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!available)
                .help(available ? "控制该应用是否出现在 Finder 右键菜单" : "应用不可用")
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: target.isEnabled)
        .animation(.easeInOut(duration: 0.2), value: available)
        .help("拖动排序；右键可上移、下移或移除")
        .contextMenu {
            Button("上移", systemImage: "arrow.up", action: moveUp)
                .disabled(!canMoveUp)
            Button("下移", systemImage: "arrow.down", action: moveDown)
                .disabled(!canMoveDown)
            if !OpenTarget.builtIns.contains(where: { $0.id == target.id }) {
                Divider()
                Button("移除", systemImage: "minus.circle", role: .destructive, action: remove)
            }
        }
    }

    @ViewBuilder
    private var availabilityChip: some View {
        if !available {
            StatusChip(text: "未安装", symbol: "exclamationmark.triangle.fill")
        }
    }

    /// One line of context per row, so the list explains itself instead of
    /// leaving the user to guess what each target will do.
    @ViewBuilder
    private var supportingText: some View {
        switch target.kind {
        case .terminal:
            Text("以所选文件夹为工作目录")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .application:
            Text(target.bundleIdentifier ?? "由系统按文件类型打开")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
