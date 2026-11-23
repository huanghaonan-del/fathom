import SwiftUI
import UIKit

/// 一张句子卡的学习页。
///
/// 默认只显示英文——先自己想一遍，想不起来再点开。
/// 这是整个 App 的核心界面，所以只有一条竖线：原文 → 译文 → 结构 → 词 → 讲解。
struct CardDetailView: View {
    let store: VocabularyStore
    let entryID: UUID

    @State private var revealed: Bool?
    @State private var showLesson = false
    @State private var copied = false
    @State private var confirmDelete = false

    @Environment(\.dismiss) private var dismiss

    private var entry: VocabularyEntry? { store.entry(withID: entryID) }
    private var isRevealed: Bool { revealed ?? !AppSettings.collapseTranslation }

    var body: some View {
        Group {
            if let entry {
                content(entry)
            } else {
                Text("这条记录已经被删除了")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let entry {
                    Button {
                        store.toggleStar(id: entry.id)
                    } label: {
                        Image(systemName: entry.starred ? "star.fill" : "star")
                            .foregroundStyle(entry.starred ? Color.orange : Color.secondary)
                    }
                    .accessibilityLabel(entry.starred ? "取消收藏" : "收藏")

                    Menu {
                        Button {
                            store.toggleMastered(id: entry.id)
                        } label: {
                            Label(entry.mastered ? "标回未学" : "标记为已掌握",
                                  systemImage: entry.mastered ? "arrow.uturn.backward" : "checkmark.circle")
                        }
                        Button {
                            UIPasteboard.general.string = plainText(entry)
                            copied = true
                        } label: {
                            Label(copied ? "已复制" : "复制全文", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("删除这条", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多")
                }
            }
        }
        .confirmationDialog("删除这条记录？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                store.remove(id: entryID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("讲解也会一起删掉。")
        }
        .sheet(isPresented: $showLesson) {
            if let entry {
                LessonSheetView(text: entry.result.original,
                                kind: entry.kind,
                                store: store,
                                result: entry.result)
            }
        }
    }

    // MARK: - 内容

    private func content(_ entry: VocabularyEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                originalCard(entry)

                if isRevealed {
                    if let sentence = entry.result.sentence {
                        translationBlock(sentence)
                        if !sentence.nativeTake.isEmpty {
                            nativeTakeBlock(sentence.nativeTake)
                        }
                        if !sentence.structure.isEmpty {
                            structureBlock(sentence)
                        }
                        if !sentence.chunks.isEmpty {
                            chunksBlock(sentence)
                        }
                        if !sentence.grammarNotes.isEmpty {
                            grammarBlock(sentence)
                        }
                        if !sentence.keyVocabulary.isEmpty {
                            vocabularyBlock(sentence, original: entry.result.original)
                        }
                    } else if let word = entry.result.word {
                        wordDetail(word)
                    }
                    lessonButton(entry)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
    }

    private func originalCard(_ entry: VocabularyEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.result.original)
                .font(.title3)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                SpeakerButton(text: entry.result.original, compact: true)

                if !isRevealed {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealed = true }
                    } label: {
                        Text("看译文")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                } else if AppSettings.collapseTranslation {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { revealed = false }
                    } label: {
                        Text("收起")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if entry.mastered {
                    Label("已掌握", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func translationBlock(_ sentence: SentenceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sentence.translation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            if !sentence.difficulty.isEmpty {
                Text(sentence.difficulty)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.14), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func nativeTakeBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("母语者视角", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func structureBlock(_ sentence: SentenceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("主干与修饰", systemImage: "square.split.2x1")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sentence.structure.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.element.role)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(item.element.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    if !item.element.note.isEmpty {
                        Text(item.element.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chunksBlock(_ sentence: SentenceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("语块与地道表达", systemImage: "square.on.square.dashed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sentence.chunks.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.element.text)
                            .font(.callout.weight(.medium))
                        if !item.element.kind.isEmpty {
                            Text(item.element.kind)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.12), in: Capsule())
                                .foregroundStyle(.purple)
                        }
                        SpeakerButton(text: item.element.text, compact: true)
                    }
                    Text(item.element.meaning)
                        .font(.footnote)
                    if !item.element.note.isEmpty {
                        Text(item.element.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func grammarBlock(_ sentence: SentenceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("语法：为什么是这个形式", systemImage: "textformat")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sentence.grammarNotes.enumerated()), id: \.offset) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(item.offset + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.accentColor))
                    Text(item.element)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func vocabularyBlock(_ sentence: SentenceAnalysis, original: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("难点词", systemImage: "character.book.closed")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(sentence.keyVocabulary.enumerated()), id: \.offset) { item in
                WordRow(vocabulary: item.element, context: original)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func wordDetail(_ word: WordAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(word.headword)
                    .font(.largeTitle.weight(.semibold))
                SpeakerButton(text: word.headword, compact: true)
            }
            if !word.phonetic.isEmpty {
                Text(word.phonetic)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(word.meanings.enumerated()), id: \.offset) { item in
                Text("\(item.offset + 1). \(item.element)")
                    .font(.callout)
            }
            ForEach(Array(word.examples.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.element.en)
                        .font(.callout)
                    Text(item.element.zh)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func lessonButton(_ entry: VocabularyEntry) -> some View {
        Button {
            showLesson = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "graduationcap.fill")
                    .font(.subheadline)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.hasLesson ? "看讲解" : "讲深一点")
                        .font(.subheadline.weight(.semibold))
                    Text(entry.hasLesson ? "上次的讲解已经存下来了" : "拆开讲，含语法和母语者思路")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 复制

    private func plainText(_ entry: VocabularyEntry) -> String {
        var parts: [String] = [entry.result.original, ""]
        if let sentence = entry.result.sentence {
            if !sentence.translation.isEmpty {
                parts.append(sentence.translation)
                parts.append("")
            }
            if !sentence.keyVocabulary.isEmpty {
                let words = sentence.keyVocabulary.map { "\($0.word) \($0.phonetic) \($0.partOfSpeech) \($0.meaning)" }
                parts.append("难点词：")
                parts.append(contentsOf: words)
            }
        }
        if entry.hasLesson, let lesson = entry.lessonText {
            parts.append("")
            parts.append(lesson)
        }
        return parts.joined(separator: "\n")
    }
}
