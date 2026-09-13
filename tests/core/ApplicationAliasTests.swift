import Foundation
import Testing
@testable import OneClickCore

/// 别名命中的那一个目标，几个断言都用它。
private let vsCode = OpenTarget(
    id: "editor",
    name: "Visual Studio Code",
    kind: .application,
    bundleIdentifier: "com.microsoft.VSCode",
    applicationURL: nil,
    isEnabled: true
)

/// 别名表要解决的原始问题：`用 Visual Studio Code 打开` 太长。
@Test func knownApplicationsGetAShortMenuName() {
    #expect(ApplicationAlias.shortName(forBundleIdentifier: "com.microsoft.VSCode") == "VS Code")

    #expect(vsCode.menuName == "VS Code")
    // 身份不能被别名改写：设置窗口和报错文案用的仍是全名。
    #expect(vsCode.name == "Visual Studio Code")
}

@Test func applicationsWithoutAnAliasKeepTheirOwnName() {
    #expect(ApplicationAlias.shortName(forBundleIdentifier: "com.example.unknown") == nil)
    #expect(ApplicationAlias.shortName(forBundleIdentifier: nil) == nil)

    let importedWithoutIdentifier = OpenTarget(
        id: "unknown",
        name: "My Editor",
        kind: .application,
        bundleIdentifier: nil,
        applicationURL: URL(fileURLWithPath: "/Applications/My Editor.app"),
        isEnabled: true
    )
    #expect(importedWithoutIdentifier.menuName == "My Editor")

    let terminal = OpenTarget.builtIns[0]
    #expect(terminal.kind == .terminal)
    #expect(terminal.menuName == "Terminal")
}

/// 别名是派生的，不是配置的一部分：写进 settings.json 就意味着要做迁移，
/// 而这张表随时可能加条目。这条断言保证两者不会悄悄勾连上。
@Test func aliasesAreNeverPersisted() throws {
    let data = try JSONEncoder().encode(vsCode)
    let json = try #require(String(data: data, encoding: .utf8))
    #expect(!json.contains("VS Code"))

    let decoded = try JSONDecoder().decode(OpenTarget.self, from: data)
    #expect(decoded.name == "Visual Studio Code")
    #expect(decoded.menuName == "VS Code")
}

/// 表自身的规矩。加一条别名时这些断言就是检查清单：短名必须真的更短，
/// 否则"别名"只是给菜单换了个同样长的名字。
@Test func aliasTableEntriesAreWellFormed() {
    var seen = Set<String>()
    for entry in ApplicationAlias.entries {
        #expect(!entry.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(entry.bundleIdentifier.contains("."))
        #expect(seen.insert(entry.bundleIdentifier).inserted)
        #expect(!entry.applicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(entry.applicationName == entry.applicationName.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(!entry.shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(entry.shortName == entry.shortName.trimmingCharacters(in: .whitespacesAndNewlines))
        #expect(entry.shortName.count < entry.applicationName.count)
        #expect(entry.shortName.count <= 16)
    }
}
