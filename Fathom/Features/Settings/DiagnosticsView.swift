import SwiftUI

/// 「设置 → 关于 → 诊断分享扩展」。
///
/// 侧载安装后如果分享面板里一直看不到 Fathom，问题通常出在扩展包有没有被
/// 原样装进 App 里。这一页把判断依据直接列出来，截图就能定位。
struct DiagnosticsView: View {
    struct Row: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        var isBad: Bool = false
    }

    @State private var rows: [Row] = []

    var body: some View {
        List {
            Section {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.callout.weight(.semibold))
                        Text(row.value)
                            .font(.footnote)
                            .foregroundStyle(row.isBad ? Color.orange : Color.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("把这一页截图发给开发者，可以直接看出分享扩展为什么没出现。")
            }

            Section {
                Button("重新检查") { refresh() }
            }
        }
        .navigationTitle("诊断")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        rows = Self.collect()
    }

    static func collect() -> [Row] {
        var rows: [Row] = []

        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        rows.append(Row(title: "版本", value: "\(short) (\(build))"))
        rows.append(Row(title: "App 路径", value: Bundle.main.bundleURL.path))

        let plugins = Bundle.main.bundleURL.appendingPathComponent("PlugIns")
        let fm = FileManager.default
        let pluginsExist = fm.fileExists(atPath: plugins.path)
        rows.append(Row(
            title: "PlugIns 目录",
            value: pluginsExist ? "存在" : "不存在 —— 扩展根本没被装进 App",
            isBad: !pluginsExist
        ))

        var names: [String] = []
        if let items = try? fm.contentsOfDirectory(atPath: plugins.path) {
            names = items
        }
        rows.append(Row(
            title: "PlugIns 内容",
            value: names.isEmpty ? "空" : names.joined(separator: ", "),
            isBad: names.isEmpty
        ))

        for name in names where name.hasSuffix(".appex") {
            let bundleURL = plugins.appendingPathComponent(name)
            let plistURL = bundleURL.appendingPathComponent("Info.plist")
            let exists = fm.fileExists(atPath: plistURL.path)
            var identifier = "读不到 Info.plist"
            var hasExtensionPoint = false

            if exists,
               let data = try? Data(contentsOf: plistURL),
               let object = try? PropertyListSerialization.propertyList(from: data, format: nil),
               let dictionary = object as? [String: Any] {
                identifier = dictionary["CFBundleIdentifier"] as? String ?? "缺 CFBundleIdentifier"
                if let extensionDictionary = dictionary["NSExtension"] as? [String: Any],
                   let point = extensionDictionary["NSExtensionPointIdentifier"] as? String {
                    hasExtensionPoint = true
                    identifier += "（\(point)）"
                }
            }

            let loadable = Bundle(url: bundleURL) != nil
            rows.append(Row(
                title: name,
                value: "Info.plist=\(exists ? "在" : "缺")｜id=\(identifier)｜可加载=\(loadable ? "是" : "否")",
                isBad: !exists || !loadable || !hasExtensionPoint
            ))
        }

        rows.append(Row(
            title: "App Group",
            value: SharedStorage.isUsingAppGroup ? "可用（主 App 与扩展共享数据）" : "不可用（免费签名属正常，扩展需单独填 Key）"
        ))
        rows.append(Row(title: "数据目录", value: SharedStorage.dataDirectory.path))

        return rows
    }
}
