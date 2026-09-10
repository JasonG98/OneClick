import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @State private var showsDirectories = false

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                Section {
                    ForEach(model.settings.targets) { target in
                        ApplicationRow(target: target,
                            enabled: Binding(get: { target.isEnabled }, set: { model.setEnabled(target.id, $0) }),
                            available: model.availableApplications[target.id] != nil,
                            moveUp: { model.move(target.id, by: -1) },
                            moveDown: { model.move(target.id, by: 1) },
                            remove: { model.remove(target.id) })
                    }
                    .onMove(perform: model.move)
                } header: {
                    HStack {
                        Text("在应用中打开")
                        Spacer()
                        Text("\(model.availableCount) 个已启用").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("拖动调整顺序，或右键上移、下移。文件夹会直接交给选定应用。")
                }

                Section {
                    Toggle(isOn: Binding(get: { model.settings.copiesPaths }, set: { model.settings.copiesPaths = $0; model.save() })) {
                        Label("复制绝对路径", systemImage: "doc.on.doc")
                    }
                    .toggleStyle(.switch).controlSize(.small)
                    .padding(.vertical, 5)
                } footer: {
                    Text("多选时每行一个路径。右键文件夹空白处，可复制当前目录。")
                }

                Section {
                    LabeledContent("Claude Code 启动终端", value: "自动")
                    Text("沿用 Claude Code 最近使用的终端。要更换终端，请先在目标终端中运行一次 Claude Code。")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let target = model.settings.targets.first(where: { $0.kind == .claude }), model.availableApplications[target.id] == nil {
                        Text("先安装 Claude Code，并在交互会话中发送首个提示以注册深链接。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section {
                    DisclosureGroup("覆盖目录 · \(model.settings.directories.count)", isExpanded: $showsDirectories) {
                        ForEach(model.settings.directories, id: \.self) { directory in
                            HStack {
                                Image(systemName: "folder").foregroundStyle(.secondary)
                                Text(directory.path).font(.callout).lineLimit(1).truncationMode(.middle).help(directory.path)
                                Spacer()
                                Button("移除目录", systemImage: "minus.circle") { model.removeDirectory(directory) }
                                    .labelStyle(.iconOnly).buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                        Button("添加目录…", systemImage: "plus") { model.addDirectory() }
                        Text("包含子文件夹。iCloud 等特殊目录的菜单可用性由 Finder 决定。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .disabled(!model.configurationAvailable)

            HStack {
                Text("配置自动保存").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Text("OneClick 0.1 · Apple Silicon").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 570, minHeight: 630)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加应用", systemImage: "plus") { model.addApplication() }
                    .disabled(!model.configurationAvailable)
                    .help("添加应用到右键菜单")
            }
            ToolbarItem(placement: .automatic) {
                Button("刷新状态", systemImage: "arrow.clockwise") { model.refresh() }
            }
        }
        .alert("操作未完成", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 29, weight: .medium))
                    .frame(width: 62, height: 62)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("OneClick").font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text("常用操作，就在右键。").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 12) {
                    Label(model.extensionEnabled ? "Finder 扩展已启用" : "Finder 扩展未启用", systemImage: model.extensionEnabled ? "checkmark.circle.fill" : "puzzlepiece.extension")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(model.extensionEnabled ? Color.green : Color.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                    Button(model.extensionEnabled ? "管理扩展" : "启用扩展") { model.showExtensionSettings() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 14)
    }
}
