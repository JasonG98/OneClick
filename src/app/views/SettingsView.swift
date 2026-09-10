import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @State private var selection: Page? = .apps
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    enum Page: String, Hashable, CaseIterable, Identifiable {
        case apps
        case directories
        case about

        var id: Self { self }

        var title: String {
            switch self {
            case .apps: "应用"
            case .directories: "覆盖目录"
            case .about: "关于"
            }
        }

        var symbol: String {
            switch self {
            case .apps: "square.grid.2x2"
            case .directories: "folder"
            case .about: "info.circle"
            }
        }

        var footerText: String {
            switch self {
            case .apps: "拖动调整顺序；右键可上移、下移或移除"
            case .directories: "覆盖目录包含其所有子文件夹"
            case .about: "macOS 26+ · Apple Silicon · Swift 6 · SwiftUI"
            }
        }
    }

    /// Rows are a fixed height so the list card can hug its content. A list that
    /// stretches to the window floor strands two rows above an empty pane.
    private static let applicationRowHeight: CGFloat = 52
    private static let directoryRowHeight: CGFloat = 46
    private static let listHeightCap: CGFloat = 380
    /// An inset list reserves breathing room above and below its rows; the slack
    /// keeps the card from landing exactly on its content height, which would
    /// flash a scroll indicator over a list that has nothing to scroll.
    private static let listVerticalPadding: CGFloat = 30

    private static func listHeight(rows: Int, rowHeight: CGFloat) -> CGFloat {
        min(CGFloat(rows) * rowHeight + listVerticalPadding, listHeightCap)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 660, minHeight: 400)
        .alert("操作未完成", isPresented: errorBinding) {
            Button("好", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }


    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(Page.allCases) { page in
                Label {
                    Text(page.title)
                } icon: {
                    Image(systemName: page.symbol).frame(width: 18)
                }
                .badge(badge(for: page))
                .tag(page)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ExtensionStatusCard(
                availability: model.extensionAvailability,
                isReloading: model.reloadingExtension,
                openSettings: { model.showExtensionSettings() },
                reload: { model.reloadExtension() }
            )
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 202, max: 250)
    }

    private func badge(for page: Page) -> Text? {
        switch page {
        case .apps:
            guard !model.settings.targets.isEmpty else { return nil }
            return Text(verbatim: "\(model.availableCount)/\(model.settings.targets.count)")
        case .directories:
            guard !model.settings.directories.isEmpty else { return nil }
            return Text(verbatim: "\(model.settings.directories.count)")
        case .about:
            return nil
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        let page = selection ?? .apps
        Group {
            switch page {
            case .apps: appsPage
            case .directories: directoriesPage
            case .about: aboutPage
            }
        }
        .navigationSubtitle(page.title)
        .toolbar { toolbar(for: page) }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer(for: page) }
    }

    /// Every pane ends on the same quiet footer bar, which anchors a window that
    /// is mostly empty and keeps the tip visible while a long list scrolls.
    private func footer(for page: Page) -> some View {
        VStack(spacing: 0) {
            Divider()
            PanelFooterHint(text: footerText(for: page))
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
        }
        .background(.bar)
    }

    /// The list tips only hold while there is a list; an empty pane says
    /// something true instead of telling the user to drag rows that are not
    /// there.
    private func footerText(for page: Page) -> String {
        switch page {
        case .apps where model.settings.targets.isEmpty,
             .directories where model.settings.directories.isEmpty:
            "配置会自动保存"
        default:
            page.footerText
        }
    }

    @ToolbarContentBuilder
    private func toolbar(for page: Page) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            switch page {
            case .apps:
                Button {
                    model.addApplication()
                } label: {
                    Label("添加应用", systemImage: "plus")
                }
                .help("选择 .app 添加到右键菜单")
                .disabled(!model.configurationAvailable)

                refreshButton
            case .directories:
                Button {
                    model.addDirectory()
                } label: {
                    Label("添加目录", systemImage: "plus")
                }
                .help("添加需要右键菜单覆盖的目录")
                .disabled(!model.configurationAvailable)

                // Only while the shipped default is actually missing, so it
                // stays out of the way for anyone who removed it on purpose.
                if !model.isDefaultDirectoryConfigured {
                    Button {
                        model.restoreDefaultDirectory()
                    } label: {
                        Label("恢复默认主目录", systemImage: "house")
                    }
                    .help("把用户主目录加回覆盖范围")
                    .disabled(!model.configurationAvailable)
                }

                refreshButton
            case .about:
                EmptyView()
            }
        }
    }

    private var refreshButton: some View {
        Button {
            model.refresh()
        } label: {
            Label("重新检测", systemImage: "arrow.clockwise")
        }
        .help("重新检测应用安装状态")
        .disabled(!model.configurationAvailable)
    }

    // MARK: - Pages

    private var appsPage: some View {
        VStack(spacing: 10) {
            PanelSectionLabel(
                title: "已启用",
                metric: model.settings.targets.isEmpty
                    ? nil
                    : "\(model.availableCount) / \(model.settings.targets.count)"
            )
            if model.settings.targets.isEmpty {
                emptyState(
                    symbol: "plus.app",
                    title: "还没有添加应用",
                    message: "添加常用编辑器后，它们会出现在 Finder 的右键菜单里。"
                ) {
                    Button {
                        model.addApplication()
                    } label: {
                        Label("添加应用", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            } else {
                targetList
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var targetList: some View {
        List {
            ForEach(Array(model.settings.targets.enumerated()), id: \.element.id) { index, target in
                ApplicationRow(
                    target: target,
                    enabled: Binding(get: { target.isEnabled }, set: { model.setEnabled(target.id, $0) }),
                    available: model.availableApplications[target.id] != nil,
                    icon: model.applicationIcons[target.id],
                    canMoveUp: index > 0,
                    canMoveDown: index < model.settings.targets.count - 1,
                    moveUp: { model.move(target.id, by: -1) },
                    moveDown: { model.move(target.id, by: 1) },
                    remove: { model.remove(target.id) }
                )
            }
            .onMove(perform: model.move)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .panelSurface()
        .environment(\.defaultMinListRowHeight, Self.applicationRowHeight)
        .frame(maxHeight: Self.listHeight(rows: model.settings.targets.count, rowHeight: Self.applicationRowHeight))
        .disabled(!model.configurationAvailable)
    }

    private var directoriesPage: some View {
        VStack(spacing: 10) {
            PanelSectionLabel(
                title: "覆盖目录",
                metric: model.settings.directories.isEmpty
                    ? nil
                    : "\(model.settings.directories.count)"
            )
            if model.settings.directories.isEmpty {
                emptyState(
                    symbol: "folder.badge.plus",
                    title: "还没有覆盖目录",
                    message: "没有覆盖目录时 Finder 不会显示 OneClick 菜单。先添加一个，或恢复默认的主目录。"
                ) {
                    Button {
                        model.addDirectory()
                    } label: {
                        Label("添加目录", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        model.restoreDefaultDirectory()
                    } label: {
                        Label("恢复默认主目录", systemImage: "house")
                    }
                    .buttonStyle(.glass)
                }
            } else {
                directoryList
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var directoryList: some View {
        List {
            ForEach(model.settings.directories, id: \.self) { directory in
                DirectoryRow(directory: directory, homeDirectory: model.homeDirectory) {
                    model.removeDirectory(directory)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .panelSurface()
        .environment(\.defaultMinListRowHeight, Self.directoryRowHeight)
        .frame(maxHeight: Self.listHeight(rows: model.settings.directories.count, rowHeight: Self.directoryRowHeight))
        .disabled(!model.configurationAvailable)
    }

    private var aboutPage: some View {
        VStack(spacing: 13) {
            Spacer(minLength: 20)
            heroMark
            VStack(spacing: 4) {
                Text("OneClick")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Text("常用操作，就在右键。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(verbatim: "版本 \(appVersion)")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.quaternary))
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heroMark: some View {
        Image(systemName: "cursorarrow.click.2")
            .font(.system(size: 34, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 80, height: 80)
            .panelSurface(cornerRadius: 20, fill: AnyShapeStyle(.quaternary))
            .accessibilityHidden(true)
    }

    /// Uses the system empty-state view.
    ///
    /// A hand-built stack here is what broke the window: with no scroll view or
    /// list left in the detail column, the split view laid the entire window out
    /// from its top edge, so the sidebar rows climbed over the traffic lights and
    /// the pane footer fell out of view. `ContentUnavailableView` is the shape
    /// the framework expects inside a split view.
    private func emptyState<Actions: View>(
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            HStack(spacing: 10) {
                actions()
            }
            .disabled(!model.configurationAvailable)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }
}

/// Floating status card at the foot of the sidebar.
///
/// This is the one custom interaction surface in the window, so it is the one
/// place that asks for Liquid Glass directly; the system draws the toolbar and
/// the list surfaces. Reduce Transparency swaps in an opaque card.
private struct ExtensionStatusCard: View {
    let availability: ExtensionAvailability
    let isReloading: Bool
    let openSettings: () -> Void
    let reload: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                card.panelSurface(cornerRadius: 10, fill: AnyShapeStyle(.quaternary))
            } else {
                GlassEffectContainer(spacing: 8) {
                    card.glassEffect(.regular, in: .rect(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .help(helpText)
    }

    /// The system toggle stays on after the extension process exits — which is
    /// exactly what a rebuild causes, because it replaces the `.appex`
    /// underneath the running process — and Finder never starts it again on its
    /// own. A green "已启用" in that state is what made a working toggle look
    /// like a broken product, so the card reports the process too.
    private var helpText: String {
        switch availability {
        case .disabled: "在系统设置的「通用 → 登录项与扩展 → 文件提供程序」中启用 OneClick"
        case .enabled: "Finder 扩展已启用，右键菜单随时可用"
        case .enabledNotRunning: "扩展已在系统设置中启用，但进程没有运行，右键菜单现在不会出现。点按重新加载，不必重启 Finder。"
        }
    }

    @ViewBuilder
    private var card: some View {
        switch availability {
        case .disabled:
            Button(action: openSettings) { content }
                .buttonStyle(.plain)
        case .enabled:
            content
        case .enabledNotRunning:
            Button(action: reload) { content }
                .buttonStyle(.plain)
                .disabled(isReloading)
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicator)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                // Name the exact System Settings location: the enabling switch is
                // buried under File Providers, and "前往系统设置" alone leaves the
                // user hunting for it.
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var indicator: Color {
        switch availability {
        case .disabled: .orange
        case .enabled: .green
        case .enabledNotRunning: .yellow
        }
    }

    private var title: String {
        switch availability {
        case .disabled: "Finder 扩展未启用"
        case .enabled: "Finder 扩展已启用"
        case .enabledNotRunning: isReloading ? "正在重新加载…" : "Finder 扩展未在运行"
        }
    }

    private var subtitle: String {
        switch availability {
        case .disabled: "点按打开「登录项与扩展」"
        case .enabled: "右键菜单随时可用"
        case .enabledNotRunning: isReloading ? "正在重启扩展进程" : "点按重新加载，无需重启 Finder"
        }
    }

    private var symbol: String? {
        switch availability {
        case .disabled: "chevron.right"
        case .enabled: nil
        case .enabledNotRunning: "arrow.clockwise"
        }
    }
}
