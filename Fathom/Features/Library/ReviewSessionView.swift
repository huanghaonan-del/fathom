import SwiftUI

/// 复习：一屏一张，先看英文自己想，想不起来再翻答案。
///
/// 这是整个 App 唯一「必须动脑」的地方，所以界面尽量空：
/// 顶部进度、中间卡片、底部一个按钮。
struct ReviewSessionView: View {
    let store: VocabularyStore
    let limit: Int

    @Environment(\.dismiss) private var dismiss

    @State private var cards: [VocabularyEntry] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var remembered = 0
    @State private var finished = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if cards.isEmpty {
                    emptyView
                } else if finished {
                    summaryView
                } else {
                    sessionView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(finished ? "完成" : "复习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard !loaded else { return }
                cards = store.reviewBatch(limit: limit)
                loaded = true
            }
        }
    }

    // MARK: - 空

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("没有要复习的")
                .font(.headline)
            Text("你查过的句子都在「库」里，等有新卡片了再来。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("关闭") { dismiss() }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 复习中

    private var current: VocabularyEntry? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    private var sessionView: some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let entry = current {
                        sentenceCard(entry)
                        if revealed {
                            answerContent(entry)
                        }
                    }
                }
                .padding(16)
            }
            bottomBar
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(min(index + 1, cards.count)) / \(cards.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("记住 \(remembered)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(index), total: Double(max(cards.count, 1)))
                .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func sentenceCard(_ entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.result.original)
                .font(.title3)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                SpeakerButton(text: entry.result.original, compact: true)
                Spacer()
                if entry.starred {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func answerContent(_ entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sentence = entry.result.sentence {
                if !sentence.translation.isEmpty {
                    Text(sentence.translation)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !sentence.structure.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主干")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(sentence.structure.enumerated()), id: \.offset) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.element.role)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 62, alignment: .leading)
                                Text(item.element.text)
                                    .font(.caption)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !sentence.keyVocabulary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("难点词")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(sentence.keyVocabulary.enumerated()), id: \.offset) { item in
                            WordRow(vocabulary: item.element, context: entry.result.original)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.opacity)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if revealed {
                HStack(spacing: 10) {
                    Button {
                        advance(remembered: false)
                    } label: {
                        Text("再放放")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(uiColor: .tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        advance(remembered: true)
                    } label: {
                        Text("记住了")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { revealed = true }
                } label: {
                    Text("看答案")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.bar)
    }

    // MARK: - 完成

    private var summaryView: some View {
        VStack(spacing: 14) {
            Image(systemName: "flag.checkered")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("这轮看完了 \(cards.count) 张")
                .font(.headline)
            Text("记住 \(remembered) 张，剩下 \(cards.count - remembered) 张下次还会出现。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    restart()
                } label: {
                    Text("再来一轮")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button("完成") { dismiss() }
                    .font(.subheadline)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 动作

    private func advance(remembered didRemember: Bool) {
        if let entry = current, didRemember {
            store.markReviewed(id: entry.id, mastered: true)
            remembered += 1
        } else if let entry = current {
            store.markReviewed(id: entry.id, mastered: false)
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            revealed = false
            if index + 1 < cards.count {
                index += 1
            } else {
                finished = true
            }
        }
    }

    private func restart() {
        cards = store.reviewBatch(limit: limit)
        index = 0
        revealed = false
        remembered = 0
        finished = false
    }
}
