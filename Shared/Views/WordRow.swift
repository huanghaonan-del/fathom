import SwiftUI
import UIKit

/// 卡片里的一个难点词。点一下弹一张词典式的小卡，不跳页、不另开词表。
struct WordRow: View {
    let vocabulary: KeyVocabulary
    /// 这个词所在的原句，复制的时候一起带走。
    var context: String = ""

    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            HStack(spacing: 8) {
                Text(vocabulary.word)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                if !vocabulary.partOfSpeech.isEmpty {
                    Text(vocabulary.partOfSpeech)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Text(vocabulary.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            WordInfoSheet(vocabulary: vocabulary, context: context)
        }
    }
}

/// 单词的词典式详情：音标、词性、释义、这句话里的意思、另一条例句。
struct WordInfoSheet: View {
    let vocabulary: KeyVocabulary
    var context: String = ""

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if !vocabulary.meaning.isEmpty {
                        section("意思", body: vocabulary.meaning)
                    }
                    if !vocabulary.note.isEmpty {
                        section("在这里的用法", body: vocabulary.note)
                    }
                    if !vocabulary.example.en.isEmpty {
                        exampleBlock
                    }
                    if !context.isEmpty {
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = plainText
                        copied = true
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel("复制")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(vocabulary.word)
                    .font(.largeTitle.weight(.semibold))
                SpeakerButton(text: vocabulary.word, compact: true)
            }
            HStack(spacing: 8) {
                if !vocabulary.phonetic.isEmpty {
                    Text(vocabulary.phonetic)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if !vocabulary.partOfSpeech.isEmpty {
                    Text(vocabulary.partOfSpeech)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func section(_ title: String, body text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var exampleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("例句")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Text(vocabulary.example.en)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                SpeakerButton(text: vocabulary.example.en, compact: true)
            }
            if !vocabulary.example.zh.isEmpty {
                Text(vocabulary.example.zh)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var plainText: String {
        var lines = [vocabulary.word]
        if !vocabulary.phonetic.isEmpty { lines.append(vocabulary.phonetic) }
        if !vocabulary.partOfSpeech.isEmpty { lines.append(vocabulary.partOfSpeech) }
        if !vocabulary.meaning.isEmpty { lines.append(vocabulary.meaning) }
        if !vocabulary.note.isEmpty { lines.append(vocabulary.note) }
        if !vocabulary.example.en.isEmpty {
            lines.append(vocabulary.example.en)
            if !vocabulary.example.zh.isEmpty { lines.append(vocabulary.example.zh) }
        }
        return lines.joined(separator: "\n")
    }
}
