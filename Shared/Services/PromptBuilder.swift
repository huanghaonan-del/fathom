import Foundation

struct AnalysisPrompt {
    let system: String
    let user: String
}

/// 提示词集中在这里，方便你按自己的口味调（例如换成更学术或更口语的解释）。
enum PromptBuilder {
    private static let systemMessage = """
    你是一名英语母语者，同时是给中文母语者做精读的老师。你的解释要像母语者聊天那样直白，而不是像语法书。
    你的任务是把用户选中的英语内容解析成 JSON，供 iOS App 渲染。

    硬性要求：
    1. 只输出一个合法的 JSON 对象，不要输出 Markdown 代码块、解释文字或多余内容。
    2. 所有解释、翻译、备注一律使用简体中文；英语原文保持原样。
    3. 不要编造音标，不确定时留空字符串。
    4. 字段没有内容时用空字符串或空数组，不要输出 null。
    5. JSON 的 key 必须与示例完全一致，不要新增、改名或嵌套。
    6. 站在母语者的角度说话：多讲“为什么会这么说”“母语者脑子里想的是什么”，少背术语。
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
            - translation 用地道中文，保留原句的口气；原句若口语、讽刺、委婉、正式，译文也要对应。不要逐词硬翻。
            - nativeTake 写母语者读完这句的第一反应（1-3 句）：什么口气、什么态度、有没有言外之意、通常在什么场合说。
            - chunks 给 3-6 条，是母语者会“整块记住”的片段：常见搭配、习语、口语说法、固定句式。
              kind 从「搭配 / 习语 / 口语 / 固定说法 / 语篇连接」里选一个；
              note 说明为什么母语者这么说、能不能换成别的说法、语气强弱或使用场合。
            - structure 讲“主干是怎么搭起来的”：role 用「主干-主语 / 主干-谓语 / 主干-宾语 / 修饰-状语 / 修饰-定语」这类写法，
              不要只堆术语；note 用大白话说这一块在干什么。
            - clauses 只列真实存在的从句；没有就给空数组。type 用中文，note 说明它在句子里起什么作用。
            - keyVocabulary 给 3-6 个真正卡住理解的词，note 写它在这句里的具体意思（不是词条义）。
            - grammarNotes 给 1-4 条，回答“作者为什么这么写”，而不是“这叫什么句型”。
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
                "translation": "委员会商议了数周，总算达成了一致。",
                "nativeTake": "这是很典型的正式书面语，像新闻稿或会议纪要。finally 带一点「总算熬出来了」的口气，说明过程拖得久、大家都有点疲惫。",
                "chunks": [
                  {"text": "reach a consensus", "meaning": "达成一致", "kind": "搭配", "note": "consensus 习惯和 reach / build / forge 搭配，不说 arrive a consensus；日常口语更常说 come to an agreement。"},
                  {"text": "after weeks of deliberation", "meaning": "经过数周商议", "kind": "固定说法", "note": "deliberation 很正式，常见于议会、陪审团、董事会；口语里会说 after weeks of talking it over。"}
                ],
                "structure": [
                  {"role": "主干-主语", "text": "The committee", "note": "谁在做这件事；这个群体作为一个整体，谓语用单数"},
                  {"role": "主干-谓语", "text": "reached", "note": "把「达成」这个动作说出来"},
                  {"role": "主干-宾语", "text": "a consensus", "note": "达成的结果是什么"},
                  {"role": "修饰-状语", "text": "after weeks of deliberation", "note": "补时间：拖了数周才成"}
                ],
                "clauses": [
                  {"type": "时间状语（介词短语）", "text": "after weeks of deliberation", "note": "不是从句，只是介词短语；如实标注，不要硬说成从句"}
                ],
                "keyVocabulary": [
                  {"word": "consensus", "meaning": "n. 一致意见", "note": "这句里指全体都能接受的结果"},
                  {"word": "deliberation", "meaning": "n. 商议；审议", "note": "正式词，强调反复讨论"}
                ],
                "grammarNotes": ["把时间状语挪到句末，重点就落在 reached a consensus 上，作者想让「终于达成」先被看到。", "committee 这类集体名词当作一个整体时，谓语用单数。"],
                "difficulty": "B2"
              }
            }
            """
        }
    }
}
