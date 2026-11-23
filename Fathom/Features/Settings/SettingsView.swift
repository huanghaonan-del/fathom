import SwiftUI
import AVFoundation

struct SettingsView: View {
    let store: VocabularyStore

    @State private var settings = SettingsStore.load()
    @State private var speech = SpeechSettings.load()
    @State private var testState: ConnectionTestState = .idle
    @State private var exportItem: ExportItem?
    @State private var exportError: String?
    @State private var showClearConfirm = false
    @State private var batchSize = AppSettings.reviewBatchSize
    @State private var collapseTranslation = AppSettings.collapseTranslation

    private enum ConnectionTestState: Equatable {
        case idle
        case running
        case success(String)
        case failure(String)
    }

    private struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            Form {
                serviceSection
                modelSection
                studySection
                fallbackSection
                speechSection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: settings) {
                SettingsStore.save(settings)
            }
            .onChange(of: speech) {
                SpeechSettings.save(speech)
            }
            .sheet(item: $exportItem) { item in
                ShareFileSheet(url: item.url)
                    .presentationDetents([.medium, .large])
            }
            .alert("导出失败", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("好", role: .cancel) { exportError = nil }
            } message: {
                Text(exportError ?? "")
            }
            .confirmationDialog("确定清空生词本？", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空 \(store.entries.count) 条记录", role: .destructive) {
                    store.removeAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("清空后无法恢复。建议先导出备份。")
            }
        }
    }

    // MARK: - 服务

    private var serviceSection: some View {
        Section {
            Picker("服务商", selection: $settings.provider) {
                ForEach(LLMProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .onChange(of: settings.provider) {
                settings.model = ""
                settings.baseURL = ""
                testState = .idle
            }

            if settings.requiresAPIKey {
                SecureField("API Key", text: $settings.apiKey, prompt: Text(settings.provider.apiKeyPlaceholder))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.footnote, design: .monospaced))
            }

            Button {
                Task { await testConnection() }
            } label: {
                HStack {
                    Text("测试连接")
                    Spacer()
                    switch testState {
                    case .idle:
                        Image(systemName: "bolt.horizontal")
                            .foregroundStyle(.secondary)
                    case .running:
                        ProgressView()
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(testState == .running || rawKeyIsMissing && settings.requiresAPIKey)

            switch testState {
            case .success(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failure(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            case .idle, .running:
                EmptyView()
            }
        } header: {
            Text("解析服务")
        } footer: {
            Text(settings.provider.notes)
        }
    }

    private var rawKeyIsMissing: Bool {
        settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var modelSection: some View {
        Section {
            TextField("模型", text: $settings.model, prompt: Text(settings.resolvedModel))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.footnote, design: .monospaced))

            TextField("Base URL", text: $settings.baseURL, prompt: Text(settings.provider.defaultBaseURL))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.system(.footnote, design: .monospaced))

            Button("恢复该服务商的默认值") {
                settings.model = ""
                settings.baseURL = ""
            }
            .font(.footnote)
            .disabled(settings.model.isEmpty && settings.baseURL.isEmpty)
        } header: {
            Text("进阶")
        } footer: {
            Text("留空即使用默认值。模型名填错时接口会报 400/404，照着下面这行换一个即可：\n\(settings.provider.modelHint)\n换用自建服务（Ollama、LM Studio、通义、Kimi 等）时，把 Base URL 填成兼容 OpenAI 的 /v1 地址。")
        }
    }

    // MARK: - 复习

    private var studySection: some View {
        Section {
            Picker("一次复习", selection: $batchSize) {
                Text("5 张").tag(5)
                Text("10 张").tag(10)
                Text("20 张").tag(20)
            }
            .onChange(of: batchSize) {
                AppSettings.reviewBatchSize = batchSize
            }

            Toggle("先藏起译文", isOn: $collapseTranslation)
                .onChange(of: collapseTranslation) {
                    AppSettings.collapseTranslation = collapseTranslation
                }
        } header: {
            Text("复习")
        } footer: {
            Text("打开卡片时先只显示英文，自己回想一遍再点「看译文」——这个动作才是记忆生效的地方。关掉则一进来就全摊开。")
        }
    }

    // MARK: - 离线

    private var fallbackSection: some View {
        Section {
            Toggle("提供离线翻译按钮", isOn: $settings.offlineFallbackEnabled)
        } header: {
            Text("离线兜底")
        } footer: {
            Text("开启后，网络失败时结果页会多出一个「离线翻译」按钮，调用 iPhone 本地 Translation 框架，只给译文。需要 iOS 18 以上且语言包已下载。")
        }
    }

    // MARK: - 朗读

    private var speechSection: some View {
        Section {
            Picker("声音", selection: $speech.voiceIdentifier) {
                Text("自动（挑最好的）").tag("")
                ForEach(SpeechService.americanVoices(), id: \.identifier) { voice in
                    Text(SpeechService.displayName(voice)).tag(voice.identifier)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("语速")
                    Spacer()
                    Text(rateLabel)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $speech.rate, in: 0.35...0.55, step: 0.01)
            }

            Button {
                SpeechService.speak("Here's the thing about sounding natural. It's not about the words. It's about the music behind them.")
            } label: {
                Label("试听一句", systemImage: "speaker.wave.2")
            }
        } header: {
            Text("朗读")
        } footer: {
            Text("想听到更像真人的美式英语：去「设置 → 辅助功能 → 朗读内容 → 声音 → 英语（美国）」，下载 Ava 或 Samantha 的「高级」版（约 300 MB），回来在这里选中它。系统自带的「标准」声音就是机器人味。")
        }
    }

    private var rateLabel: String {
        switch speech.rate {
        case ..<0.42: return "慢"
        case ..<0.50: return "正常"
        default: return "稍快"
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section {
            LabeledContent("已收录", value: "\(store.entries.count) 条")
            if let warning = SharedStorage.storageWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                LabeledContent("共享容器", value: "正常")
            }

            Button {
                export(.csv)
            } label: {
                Label("导出 CSV", systemImage: "tablecells")
            }
            Button {
                export(.anki)
            } label: {
                Label("导出 Anki 卡片", systemImage: "rectangle.stack")
            }

            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("清空生词本", systemImage: "trash")
            }
            .disabled(store.entries.isEmpty)
        } header: {
            Text("生词本数据")
        } footer: {
            Text("CSV 可用 Excel / Numbers / WPS 打开；Anki 文件在 Anki 里导入时把字段分隔符设为 Tab。")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("版本", value: appVersion)
            NavigationLink {
                DiagnosticsView()
            } label: {
                Label("诊断分享扩展", systemImage: "stethoscope")
            }
            Link(destination: URL(string: "https://platform.deepseek.com/api_keys")!) {
                Label("获取 DeepSeek API Key", systemImage: "safari")
            }
            Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                Label("获取 OpenAI API Key", systemImage: "safari")
            }
        } header: {
            Text("关于")
        } footer: {
            Text("API Key 只保存在本机（App 自己的 UserDefaults），不会上传到任何第三方服务器。\n免费开发者账号构建的 App 有效期为 7 天，到期需用 AltStore 重新签名安装。")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - 行为

    @MainActor
    private func testConnection() async {
        testState = .running
        let started = Date()
        let request = AnalysisRequest(
            text: "The committee reached a consensus after weeks of deliberation.",
            kind: .sentence
        )
        do {
            let result = try await AnalysisService(settings: settings).analyze(request)
            let elapsed = Date().timeIntervalSince(started)
            let preview = result.summaryText.prefix(40)
            testState = .success(String(format: "连接正常，耗时 %.1f 秒。返回：%@", elapsed, String(preview)))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            testState = .failure(message)
        }
    }

    private func export(_ format: ExportFormat) {
        do {
            let url = try ExportService.makeFile(entries: store.entries, format: format)
            exportItem = ExportItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }
}
