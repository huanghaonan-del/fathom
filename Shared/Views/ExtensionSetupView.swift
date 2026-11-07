import SwiftUI

/// 在扩展里填一次 API Key。
///
/// 有 App Group 时，扩展能直接读到主 App 填好的 Key，这个界面不会出现；
/// 免费账号拿不到 App Group 时，扩展只能自己存一份，所以需要在这里补一次。
@MainActor
struct ExtensionSetupView: View {
    /// 是否允许跳转浏览器（由扩展传入，拿不到就只显示网址）。
    var openURL: ((URL) -> Void)?
    let onDone: () -> Void

    @State private var provider: LLMProvider = SettingsStore.load().provider
    @State private var apiKey: String = SettingsStore.load().apiKey
    @State private var model: String = SettingsStore.load().model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("先填一次 API Key")
                        .font(.title3.weight(.semibold))
                    Text("扩展需要联网调用你选的解析服务。填好后会存在扩展自己的沙盒里，以后不用再填。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Picker("服务商", selection: $provider) {
                    ForEach(LLMProvider.allCases.filter { $0.supportsStructuredAnalysis }) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: provider) {
                    model = ""
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(provider.apiKeyPlaceholder)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if provider == .deepSeek {
                    Button {
                        if let url = URL(string: "https://platform.deepseek.com/api_keys") {
                            openURL?(url)
                        }
                    } label: {
                        Label("去 DeepSeek 创建 Key", systemImage: "safari")
                            .font(.footnote)
                    }
                }

                Button {
                    save()
                } label: {
                    Text("保存并开始解析")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let warning = SharedStorage.storageWarning {
                    Text(warning)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(18)
        }
    }

    private func save() {
        var settings = SettingsStore.load()
        settings.provider = provider
        settings.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        SettingsStore.save(settings)
        onDone()
    }
}
