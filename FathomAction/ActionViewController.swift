import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Action Extension 的宿主控制器：取出选中文本 → 挂上 SwiftUI 界面。
final class ActionViewController: UIViewController {
    private let store = VocabularyStore()
    private var hostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        // iOS 26 的分享扩展以可调整大小的表单呈现，这里给一个舒服的初始高度。
        preferredContentSize = CGSize(width: 0, height: 520)

        showLoading()
        extractText()
    }

    // MARK: - 取文本

    private func extractText() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        Task { @MainActor in
            var pieces: [String] = []
            for provider in providers {
                if let text = await loadText(from: provider) {
                    pieces.append(text)
                }
            }

            var combined = pieces
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            // 兜底：有些 App 把文字塞进 NSExtensionItem.attributedContentText。
            if combined.isEmpty {
                let attributeText = items
                    .compactMap { $0.attributedContentText?.string }
                    .joined(separator: "\n")
                combined = attributeText
            }

            install(text: TextNormalizer.normalize(combined))
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let identifiers = [
            UTType.plainText.identifier,
            UTType.utf8PlainText.identifier,
            UTType.text.identifier,
            UTType.url.identifier
        ]

        for identifier in identifiers where provider.hasItemConformingToTypeIdentifier(identifier) {
            let loaded: String? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                    if let string = item as? String {
                        continuation.resume(returning: string)
                    } else if let data = item as? Data {
                        continuation.resume(returning: String(data: data, encoding: .utf8))
                    } else if let url = item as? URL {
                        continuation.resume(returning: url.absoluteString)
                    } else if let attributed = item as? NSAttributedString {
                        continuation.resume(returning: attributed.string)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            if let loaded, !loaded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return loaded
            }
        }

        return nil
    }

    // MARK: - 界面

    private func showLoading() {
        let loading = UIHostingController(rootView: LoadingView())
        embed(loading)
    }

    private func install(text: String) {
        let root = ActionRootView(
            text: text,
            store: store,
            onClose: { [weak self] in
                self?.close()
            },
            openURL: { [weak self] url in
                self?.open(url)
            }
        )
        let controller = UIHostingController(rootView: root)
        embed(controller)
    }

    /// 打开 fathom://（把结果交给主 App 保存）或外部网址。
    /// 打开完就结束扩展，避免用户看到两个 App 抢焦点。
    private func open(_ url: URL) {
        extensionContext?.open(url) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else { return }
                if success {
                    self.close()
                } else {
                    // 少数宿主不允许扩展唤起其它 App：把「保存链接」放进剪贴板，
                    // 用户回到 App 点一下粘贴即可入库（比让他复制整段结果再解析靠谱）。
                    UIPasteboard.general.string = url.absoluteString
                    let alert = UIAlertController(
                        title: "已复制保存链接",
                        message: "这台设备不允许扩展直接打开 Fathom。请回到桌面打开 Fathom →「生词本」页左上角的剪贴板按钮，即可把这条结果存进生词本。",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "好", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func embed(_ controller: UIViewController) {
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        controller.didMove(toParent: self)
        hostingController = controller
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在读取选中的文字…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
