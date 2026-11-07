import SwiftUI

// MARK: - 通用容器

/// 每块结果共用的卡片样式。
struct ResultCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 小标签，用于词性、CEFR 等级等。
struct TagLabel: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

// MARK: - 结果视图

struct AnalysisResultView: View {
    let result: AnalysisResult
    let showOfflineFallback: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result.kind {
            case .word:
                if let word = result.word {
                    WordResultView(word: word)
                }
            case .sentence:
                if let sentence = result.sentence {
                    SentenceResultView(sentence: sentence)
                }
            }

            if showOfflineFallback {
                OfflineTranslationSection(text: result.original)
            }

            Text("生成方式：\(result.engine)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - 单词

struct WordResultView: View {
    let word: WordAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.headword.isEmpty ? "单词" : word.headword)
                        .font(.title2.bold())
                    if !word.partOfSpeech.isEmpty {
                        TagLabel(text: word.partOfSpeech)
                    }
                }
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if !word.meanings.isEmpty {
                ResultCard(title: "释义", systemImage: "text.book.closed") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(word.meanings.enumerated()), id: \.offset) { index, meaning in
                            HStack(alignment: .top, spacing: 6) {
                                Text("\(index + 1).")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(meaning)
                                    .font(.callout)
                            }
                        }
                    }
                }
            }

            if !word.collocations.isEmpty {
                ResultCard(title: "常见搭配", systemImage: "link") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(word.collocations, id: \.self) { item in
                            Text(item)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !word.examples.isEmpty {
                ResultCard(title: "例句", systemImage: "quote.opening") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(word.examples.enumerated()), id: \.offset) { _, example in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(example.en)
                                    .font(.callout)
                                    .textSelection(.enabled)
                                if !example.zh.isEmpty {
                                    Text(example.zh)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !word.nuance.isEmpty {
                ResultCard(title: "语义辨析", systemImage: "arrow.left.arrow.right") {
                    Text(word.nuance)
                        .font(.callout)
                }
            }

            if !word.memoryHook.isEmpty {
                ResultCard(title: "记忆钩子", systemImage: "lightbulb") {
                    Text(word.memoryHook)
                        .font(.callout)
                }
            }
        }
    }
}

// MARK: - 句子

struct SentenceResultView: View {
    let sentence: SentenceAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !sentence.translation.isEmpty {
                ResultCard(title: "整句翻译", systemImage: "character.bubble") {
                    HStack(alignment: .top, spacing: 10) {
                        Text(sentence.translation)
                            .font(.body)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                        if !sentence.difficulty.isEmpty {
                            TagLabel(text: sentence.difficulty, tint: .orange)
                        }
                    }
                }
            }

            if !sentence.nativeTake.isEmpty {
                ResultCard(title: "母语者视角", systemImage: "text.bubble") {
                    Text(sentence.nativeTake)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            if !sentence.chunks.isEmpty {
                ResultCard(title: "语块与地道表达", systemImage: "square.on.square.dashed") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sentence.chunks.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(item.text)
                                        .font(.callout.weight(.semibold))
                                        .textSelection(.enabled)
                                    if !item.kind.isEmpty {
                                        TagLabel(text: item.kind, tint: .purple)
                                    }
                                }
                                if !item.meaning.isEmpty {
                                    Text(item.meaning)
                                        .font(.callout)
                                }
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !sentence.structure.isEmpty {
                ResultCard(title: "主干与修饰", systemImage: "square.stack.3d.up") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(sentence.structure.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Text(item.role)
                                    .font(.caption.weight(.semibold))
                                    .frame(minWidth: 48, alignment: .leading)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.text)
                                        .font(.callout)
                                        .textSelection(.enabled)
                                    if !item.note.isEmpty {
                                        Text(item.note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !sentence.clauses.isEmpty {
                ResultCard(title: "从句拆解", systemImage: "curlybraces") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(sentence.clauses.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.type)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                                Text(item.text)
                                    .font(.callout)
                                    .textSelection(.enabled)
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !sentence.keyVocabulary.isEmpty {
                ResultCard(title: "难点词汇", systemImage: "bookmark") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(sentence.keyVocabulary.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.word)
                                        .font(.callout.weight(.semibold))
                                        .textSelection(.enabled)
                                    if !item.meaning.isEmpty {
                                        Text(item.meaning)
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if !item.note.isEmpty {
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if !sentence.grammarNotes.isEmpty {
                ResultCard(title: "语法要点", systemImage: "graduationcap") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sentence.grammarNotes, id: \.self) { note in
                            Text("· \(note)")
                                .font(.callout)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 加载与错误

struct LoadingPlaceholder: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("解析失败", systemImage: "exclamationmark.triangle")
                .font(.callout.weight(.semibold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("重试", action: onRetry)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
