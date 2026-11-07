import Foundation

struct AnalysisPrompt {
    let system: String
    let user: String
}

/// 提示词集中在这里，方便你按自己的口味调（例如换成更学术或更口语的解释）。
enum PromptBuilder {
    private static let systemMessage = """
    你是一名面向中文母语者的英语精读老师，熟悉 IPA 音标、英语语法体系（主谓宾、从句、非谓语等）和中英翻译。
    你的任务是把用户选中的英语内容解析成 JSON，供 iOS App 渲染。

    硬性要求：
    1. 只输出一个合法的 JSON 对象，不要输出 Markdown 代码块、解释文字或多余内容。
    2. 所有解释、翻译、备注一律使用简体中文；英语原文保持原样。
    3. 不要编造音标，不确定时留空字符串。
    4. 字段没有内容时用空字符串或空数组，不要输出 null。
    5. JSON 的 key 必须与示例完全一致，不要新增、改名或嵌套。
    """

    static func make(for request: AnalysisRequest) -> AnalysisPrompt {
        let kindLine: String
        let extra: String
        switch request.kind {
        case .word:
            kindLine = "解析类型：单词或短语。只输出 word 字段，不要输出 sentence 字段。"
            extra = """
            - meanings 给 2-4 条，第一条最贴合原文语境。
            - collocations 给 3-6 条，格式为“英文搭配（中文意思）”。
            - examples 给 1-2 条，必须同时有英文原句和中文翻译。
            - nuance 说明它和近义词的区别，一到两句即可。
            - memoryHook 给一个便于记住的联想或词根拆解。
            """
        case .sentence:
            kindLine = "解析类型：句子。只输出 sentence 字段，不要输出 word 字段。"
            extra = """
            - translation 要通顺、符合中文表达习惯，不要逐词硬翻。
            - structure 拆出主句主要成分，2-5 项；role 用“主语/谓语/宾语/表语/状语/补语”等中文术语。
            - clauses 只列真实存在的从句；没有就给空数组。
            - keyVocabulary 给 3-6 个真正影响理解的词。
            - grammarNotes 给 1-4 条，指出最容易卡住的地方。
            - difficulty 用 CEFR 等级填写（A1-C2）。
            """
        }

        let user = """
        \(kindLine)

        待解析的内容在 <text> 与 </text> 之间：
        <text>\(request.text)</text>

        输出 JSON 结构示例（字段含义见示例）：
        \(schema(for: request.kind))

        额外要求：
        \(extra)
        """

        return AnalysisPrompt(system: systemMessage, user: user)
    }

    /// 模型偶尔会多写解释文字，这时用一次很短的「修复」请求把内容压回 JSON。
    static func repair(rawOutput: String, request: AnalysisRequest) -> AnalysisPrompt {
        let system = """
        你是一个 JSON 修复器。把用户给出的模型原始输出整理成一个合法 JSON 对象，只输出 JSON 本身。
        不要添加原文没有的信息；缺失字段用空字符串或空数组补全；不要输出 Markdown 代码块。
        """
        let trimmed = String(rawOutput.prefix(6000))
        let user = """
        目标结构：
        \(schema(for: request.kind))

        原始输出在 <raw> 与 </raw> 之间：
        <raw>\(trimmed)</raw>
        """
        return AnalysisPrompt(system: system, user: user)
    }

    private static func schema(for kind: AnalysisKind) -> String {
        switch kind {
        case .word:
            return """
            {
              "kind": "word",
              "word": {
                "headword": "ephemeral",
                "phonetic": "/ɪˈfem.ər.əl/",
                "partOfSpeech": "adj.",
                "meanings": ["短暂的；转瞬即逝的", "（生命）朝生暮死的"],
                "collocations": ["ephemeral beauty（短暂的美）", "an ephemeral pleasure（短暂的快乐）"],
                "examples": [
                  {"en": "Fame in the internet age is often ephemeral.", "zh": "网络时代的名气往往转瞬即逝。"}
                ],
                "nuance": "比 temporary 更书面，强调美好事物存在时间极短。",
                "memoryHook": "epi（在…之上）+ hemera（一天）→ 只存在一天。"
              }
            }
            """
        case .sentence:
            return """
            {
              "kind": "sentence",
              "sentence": {
                "translation": "委员会经过数周商议，最终达成了一致，这让所有人都很意外。",
                "structure": [
                  {"role": "主语", "text": "The committee", "note": "名词短语作主语"},
                  {"role": "谓语", "text": "reached", "note": "一般过去时"},
                  {"role": "宾语", "text": "a consensus", "note": "名词短语作宾语"},
                  {"role": "状语", "text": "finally", "note": "副词作状语"}
                ],
                "clauses": [
                  {"type": "非限制性定语从句", "text": "which had been deliberating for weeks", "note": "补充说明 the committee，用逗号隔开"},
                  {"type": "定语从句", "text": "that surprised everyone", "note": "修饰 a consensus"}
                ],
                "keyVocabulary": [
                  {"word": "deliberate", "meaning": "v. 仔细考虑；商议", "note": "deliberate on / over sth."},
                  {"word": "consensus", "meaning": "n. 共识；一致意见", "note": "reach a consensus 达成共识"}
                ],
                "grammarNotes": ["主句是 The committee reached a consensus。", "两个从句分别修饰 committee 和 consensus。"],
                "difficulty": "B2"
              }
            }
            """
        }
    }
}
