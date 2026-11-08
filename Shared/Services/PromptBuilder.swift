import Foundation

struct AnalysisPrompt {
    let system: String
    let user: String
}

/// 提示词集中在这里，方便你按自己的口味调（例如换成更学术或更口语的解释）。
enum PromptBuilder {
    private static let systemMessage = """
    你是一名英语母语者，同时是给中文母语者做精读的老师。你要做的不是「翻译 + 讲语法」，而是让一个中国人真正明白：这句话母语者听到时脑子里发生了什么。
    你的任务是把用户选中的英语内容解析成 JSON，供 iOS App 渲染。

    硬性要求：
    1. 只输出一个合法的 JSON 对象，不要输出 Markdown 代码块、解释文字或多余内容。
    2. 所有解释、翻译、备注一律使用简体中文；英语原文保持原样。
    3. 不要编造音标，不确定时留空字符串。
    4. 字段没有内容时用空字符串或空数组，不要输出 null。
    5. JSON 的 key 必须与示例完全一致，不要新增、改名或嵌套。
    6. 中文要像中国人平时说话，严禁翻译腔（「对……的恐惧」「被……所」「进行……的」这类句式一律不用）。宁可拆成两句短句，也不要为了贴英文结构而写得别扭。
    7. 讲「为什么这么说」时，要给出母语者脑子里的画面、习惯或文化背景，不要用「很有力量」「很生动」「值得学习」这类空话敷衍。
    8. 讲语法时不许只报术语。要说清「为什么非得是这个形式、换成别的会变什么意思」，再用「美国小孩是怎么理解它的」这种方式讲一遍——小孩不背规则，他们记的是画面和感觉。
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
            - examples 给 1-2 条，必须同时有英文原句和中文翻译；中文翻译要用口语，不要翻译腔。
            - nuance 讲母语者在什么场合会用它、用了它显得怎么样（正式、随意、情绪重、带点轻蔑……），以及换成近义词后语气会怎么变；一到两句。
            - memoryHook 给一个便于记住的联想或词根拆解，可以用中文里的谐音、画面。
            """
        case .sentence:
            kindLine = "解析类型：句子。只输出 sentence 字段，不要输出 word 字段。"
            extra = """
            - translation 用地道的中文口语，读起来要像中国人本来就会这么说，而不是从英文「翻」过来的。
              保留原句的口气：口语、讽刺、委婉、正式都要对应；原句骂人、调侃、撒娇也要还原。
              可以拆句、可以补主语，必要时可以意译；不要逐词硬翻，不要出现翻译腔。
            - nativeTake 是这一整个功能的核心，要像「一个外国人认真给你解释中文里『老铁 666』是什么意思」那样写：
              先说这句话通常在什么场合、什么情绪下说，说话人真正想表达的是什么（潜台词）；
              再讲母语者为什么这么表达——背后的画面、习惯或文化背景，如果是梗、习语、固定说法，要讲清它的来历或结构；
              最后给中文里最接近的说法，并指出「如果直译成中文，中国人会怎么误解」。
              3-6 句，具体、有画面，不要空话。
            - chunks 给 3-6 条，是母语者会“整块记住”的片段：常见搭配、习语、口语说法、固定句式。
              kind 从「搭配 / 习语 / 口语 / 固定说法 / 语篇连接」里选一个；
              note 说明为什么母语者这么说、能不能换成别的说法、语气强弱或使用场合。
            - structure 讲“主干是怎么搭起来的”：role 用「主干-主语 / 主干-谓语 / 主干-宾语 / 修饰-状语 / 修饰-定语」这类写法，
              不要只堆术语；note 用大白话说这一块在干什么。
            - clauses 只列真实存在的从句；没有就给空数组。type 用中文，note 说明它在句子里起什么作用。
            - keyVocabulary 给 3-6 个真正卡住理解的词，note 写它在这句里的具体意思（不是词条义）。
            - grammarNotes 给 1-3 条，回答「为什么用这个形式而不是别的」（时态、单复数、三单、被动、分词、比较级），并顺口说一句「美国人小时候是怎么理解这个形式的」；
              不要只报「这叫什么句型」，也不要让人背规则。
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

    /// 「讲深一点」：不再返回卡片数据，而是写一节短课。
    ///
    /// 用户反馈过两轮：第一版太长（1200-2000 字）读着累，所以现在只挑真正读不出来的地方讲。
    static func makeLesson(for request: AnalysisRequest) -> AnalysisPrompt {
        let system = """
        你是一名在美国生活多年、专门带中国人读英文原著的老师。
        你在上一节五分钟的小课：只讲学生自己看不出来的东西，查词典就懂的，一律不讲。

        硬性要求：
        1. 只输出一个合法的 JSON 对象，不要输出 Markdown 代码块或任何解释文字。
        2. text 与 zh 字段里不要出现 Markdown 符号（#、*、-、>、`），要写成正常人说话的中文/英文。
        3. 中文要口语、具体，像老师当面讲；严禁翻译腔，严禁「很有力量」「值得学习」这类空话。
        4. 只讲这段文字里真实存在的东西，不要扯无关的背景知识。
        5. JSON 的 key 必须与示例完全一致。
        6. 短。整节课 500-900 个中文字。写不出新东西的段落就一句话带过，不许凑字数。
        """

        let kindLine: String
        switch request.kind {
        case .sentence:
            kindLine = "这次要讲的是一整句话。"
        case .word:
            kindLine = "这次要讲的是一个单词或短语。"
        }

        let user = """
        \(kindLine)

        待讲解的内容在 <text> 与 </text> 之间：
        <text>\(request.text)</text>

        输出 JSON 示例（结构必须完全一致）：
        {
          "title": "prized 不是 important",
          "blocks": [
            {"kind": "h2", "text": "一、这句话什么意思", "zh": "", "note": ""},
            {"kind": "p", "text": "我已经学会不拿自己最在乎的那点自主权去换东西了——不为了整天连轴转，也不为了客户提什么就答应什么。", "zh": "", "note": ""},
            {"kind": "h2", "text": "二、拆开看", "zh": "", "note": ""},
            {"kind": "step", "text": "1. my prized autonomy", "zh": "最容易读平的地方", "note": ""},
            {"kind": "bullet", "text": "prized", "zh": "珍视的，带感情", "note": ""},
            {"kind": "bullet", "text": "autonomy", "zh": "自主权：自己说了算", "note": ""},
            {"kind": "p", "text": "prized 不是 important。important 是「这件事重要」，客观；prized 是「我珍视、不愿意失去」，必须是「我的」。autonomy 也不等于 freedom：freedom 是不被管，autonomy 是「我自己决定」。", "zh": "", "note": ""},
            {"kind": "example", "text": "My freedom is something I truly prize.", "zh": "自由是我真正珍视的东西。", "note": ""},
            {"kind": "step", "text": "2. by working … by saying yes to …", "zh": "两个 by 并列", "note": ""},
            {"kind": "p", "text": "by + doing 是「靠……的方式」，不是「正在」。作者用它把「牺牲」和「怎么牺牲的」放进同一句，比另起一句更紧。读成「正在工作」是最常见的错。", "zh": "", "note": ""},
            {"kind": "h2", "text": "三、结构", "zh": "", "note": ""},
            {"kind": "rowhead", "text": "英语部分", "zh": "作用", "note": "中文意思"},
            {"kind": "row", "text": "I've learned", "zh": "主句", "note": "我已经明白了"},
            {"kind": "row", "text": "not to sacrifice", "zh": "核心", "note": "不去牺牲"},
            {"kind": "row", "text": "my prized autonomy", "zh": "牺牲什么", "note": "我珍视的自主权"},
            {"kind": "row", "text": "by working / by saying yes…", "zh": "方式", "note": "靠连轴转、靠有求必应"},
            {"kind": "p", "text": "英语先给结论，再用 by doing 补做法，所以听着像「先表态，再解释」。", "zh": "", "note": ""},
            {"kind": "h2", "text": "四、母语者怎么想", "zh": "", "note": ""},
            {"kind": "p", "text": "英语讲改变喜欢落在个人选择上：I've learned、I don't want to。潜台词是「我以前随叫随到，现在不干了」，体面，但很硬。中文同样意思常说「我想通了」——他们落在自律，我们落在认识。", "zh": "", "note": ""},
            {"kind": "h2", "text": "五、为什么长这样", "zh": "", "note": ""},
            {"kind": "step", "text": "I've learned", "zh": "现在完成时", "note": ""},
            {"kind": "p", "text": "美国人不会背「have/has + 过去分词」。小孩的理解是：这事发生在以前，但我关心的不是「哪年哪月」，而是「它现在在我身上留下了结果」，所以用 have；learned 是那个已经装进抽屉的结果。换成 I learned，听着就是「那年我学过」，跟现在没关系了。", "zh": "", "note": ""},
            {"kind": "example", "text": "I've lost my keys.", "zh": "我钥匙丢了（现在还进不了门）。", "note": ""},
            {"kind": "step", "text": "by working / by saying yes", "zh": "介词后面为什么加 ing", "note": ""},
            {"kind": "p", "text": "by 是介词，介词后面得放「一样东西」，动词要变成「动作这件事」才放得进去，所以加 ing。小孩的理解是：by 后面跟的是「办法」，办法是个名词似的东西，所以 work 变成 working，而不是 work。", "zh": "", "note": ""},
            {"kind": "h2", "text": "六、能直接套用", "zh": "", "note": ""},
            {"kind": "example", "text": "I've learned not to say yes just because someone asks.", "zh": "我学会了不因为别人开口就答应。", "note": ""},
            {"kind": "example", "text": "I don't want to sacrifice my weekends for work anymore.", "zh": "我不想再为工作牺牲周末了。", "note": ""}
          ]
        }

        写作要求：
        1. 六个部分按顺序，小标题用「一、」「二、」编号，每部分之间只用一个 h2。
        2. 第一部分：只给 1-2 句人话译文，不要加「这句话很值得学」之类的评论。
        3. 第二部分是重点，但只挑 1-3 个中国人容易读错或读漏的地方（词义差别、搭配、时态、从句、省略）。每个地方一个 step：
           只有必须逐词解释时才用 bullet，而且只列关键词，不要列 the / a / my 这种一看就懂的小词；
           讲解放一段 p，2-3 句，讲清「为什么这么用」「最容易误解成什么」；
           example 最多 1 条。
           整节课只讲 1 个地方也可以，不要为了凑满三段而讲废话。
        4. 第三部分必须是 rowhead 一行 + 3-5 行 row：text 写英语片段，zh 写它在句中的「作用」，note 写中文意思；最后用 1 句 p 点出结构规律。
        5. 第四部分：2-3 句，讲潜台词、说话人的态度，或中英表达习惯的差别。确实没什么可说时就只写 1 句，不要硬编。
        6. 第五部分「为什么长这样」：挑 1-2 个这句里真实出现的形式变化（三单 -s、过去式 -ed、进行 -ing、have/has been、being、被动、分词、比较级、冠词、复数），
           先讲「为什么非得是这个形式、换成别的会变什么意思」，再讲「美国小孩是怎么理解它的」——小孩不背规则，他们记的是画面和感觉，
           所以要用具体的比喻或场景，不要堆术语，也不要写「记住某某公式」。
           这句里没有值得讲的形式时，整节省略（不输出这个 h2 及其块），不要硬凑。
        7. 第六部分：2 条能直接套用的例句（text 英文、zh 中文）。
        8. 所有中文都要像人说话，严禁翻译腔。
        9. 不要给练习、作业，不要让读者自己翻译。
        10. 总长度 600-1000 个中文字。宁可少讲一个词，也不要注水。
        11. blocks 里只允许这 7 种 kind：h2、p、step、bullet、example、rowhead、row，不要自创。zh 与 note 没有内容时写空字符串。
        """

        return AnalysisPrompt(system: system, user: user)
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
                "translation": "他这人吧，脑子不太够用。",
                "nativeTake": "这句话一般是背后议论人时说的，带点调侃，也带点损，当面说会很冒犯人。英语里特别喜欢拿日常物件打比方：sharpest tool 是「最锋利的那件工具」，潜台词是「别人都还挺行，就他钝」，所以他们用「不锋利」来表示「不聪明」，跟你听到「他不是最亮的那盏灯泡」是同一个思路。中文最贴近的说法是「他脑子不太够用」「他缺根弦」；要是直译成「他不是棚子里最锋利的工具」，中国人第一反应会以为在聊五金店，因为我们的比喻习惯用脑子、弦、灯，不用工具。",
                "chunks": [
                  {"text": "not the sharpest tool in the shed", "meaning": "不太聪明（带调侃）", "kind": "习语", "note": "完整说法是 he's not the sharpest tool in the shed。同类还有 not the sharpest knife in the drawer、a few sandwiches short of a picnic，都是「缺点什么」的思路，语气轻，属于玩笑式贬低，正式场合别用。"},
                  {"text": "sharp", "meaning": "（人）机灵、反应快", "kind": "搭配", "note": "sharp 形容人是「聪明、敏锐」，不是「锋利」：a sharp mind、sharp as a tack 都是这个意思。正因为原义是「锋利」，才能顺势引申成「不聪明」。"}
                ],
                "structure": [
                  {"role": "主干-主语", "text": "He", "note": "被评价的那个人"},
                  {"role": "主干-谓语", "text": "is not", "note": "否定判断，但话没说死"},
                  {"role": "主干-表语", "text": "the sharpest tool in the shed", "note": "用一个比喻代替「笨」这个字，损人但不撕破脸"},
                  {"role": "修饰-定语", "text": "in the shed", "note": "把范围限定在「这个棚子里」，画面感全在这里"}
                ],
                "clauses": [],
                "keyVocabulary": [
                  {"word": "sharp", "meaning": "adj. 机灵的；敏锐的", "note": "这里不是「锋利」，是形容脑子快"},
                  {"word": "tool", "meaning": "n. 工具", "note": "整句的比喻对象"},
                  {"word": "shed", "meaning": "n. 棚子；工具棚", "note": "英式口语里很常见的词，院里放杂物的小屋"}
                ],
                "grammarNotes": ["故意用最高级 the sharpest：假装在做一个客观比较，实际是委婉损人，比直接说 he is stupid 轻得多。", "整句没出现一个「笨」字，靠比喻让听的人自己得出结论，这是英语评价人时很常见的留白。"],
                "difficulty": "B2"
              }
            }
            """
        }
    }
}
