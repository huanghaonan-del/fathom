# 06 · 二次开发

> 这一页给「想改点东西」的时候用。不需要读也能正常用 App。

---

## 一、工程是怎么生成出来的

仓库里**没有** `.xcodeproj`——它是从 `project.yml` 生成出来的（避免 `.pbxproj` 冲突）。

- 云端：`.github/workflows/build-ipa.yml` 里跑 `xcodegen generate`
- 本地（有 Mac 时），一条命令：

```bash
bash scripts/build-mac.sh
```

它等价于下面这三步，只是顺手检查了 XcodeGen 有没有装：

```bash
brew install xcodegen
xcodegen generate
open Fathom.xcodeproj
```

Xcode 里选 `Fathom` scheme → 你的 iPhone → Run。
第一次要在 target 的 **Signing & Capabilities** 里选自己的 Team（免费账号用个人 Team）。

> 想改 bundle id / App Group：改 `project.yml` 里的 `PRODUCT_BUNDLE_IDENTIFIER`、
> 两个 `.entitlements` 里的 group 名、以及 `Shared/Storage/SharedStorage.swift` 里的
> `AppConfig.appGroupID`，三处必须一致。

---

## 二、改提示词（最常改的地方）

`Shared/Services/PromptBuilder.swift`

| 你想改的 | 改哪里 |
| --- | --- |
| 让解析更简洁 / 更详细 | `make(for:)` 里 word / sentence 那两段要求（「2-4 条」这种数字） |
| 换成别的语言讲解（如日文） | `systemMessage` 里「用中文解释」 |
| 增加字段（如「词源」「同义词」） | ① `schema(for:)` 的 JSON 样例 ② `WordAnalysis` 结构体加属性 ③ 结果界面加一张卡片 |
| 让模型别给记忆钩子 | `schema` 里保留字段但要求返回空数组；或直接删字段并同步模型 |

⚠️ 三条硬约束（踩了就会解析失败）：

1. **prompt 里必须出现 "json" 字样**（DeepSeek JSON 模式的硬要求）
2. **schema 样例必须是合法 JSON**，别加注释、别用尾逗号
3. **字段名要和 `AnalysisModels.swift` 里的 `CodingKeys` 对齐**

改完记得同步三处：`schema(for:)`、`AnalysisModels.swift`、`AnalysisResultView.swift`。

---

## 三、换默认模型 / 服务商

`Shared/Storage/SettingsStore.swift` 的 `enum LLMProvider`：

```swift
case .deepSeek:
    return "deepseek-flash"          // 默认模型
    return "https://api.deepseek.com" // 默认 Base URL
```

用户已经存过设置的话，旧值还在 UserDefaults 里——**升级后要提醒用户在设置里点「恢复默认」**
（`SettingsStore.reset()`）。

---

## 四、数据结构

```swift
WordAnalysis   { headword, phonetic, partOfSpeech, meanings[], collocations[], examples[{en,zh}], nuance, memoryHook }
SentenceAnalysis{ translation, structure[{role,text,note}], clauses[{type,text,note}], keyVocabulary[{word,meaning,note}], grammarNotes[], difficulty }
AnalysisResult { id, original, kind, word?, sentence?, engine, createdAt }
VocabularyEntry{ id, term, kind, result, createdAt }
```

所有模型都用**自定义 `init(from:)`** 容错：字段缺失 / 类型不对都退回默认值，不会因为模型少给一个 key 就整条解析失败。
新增字段时也请照这个模式加，否则老数据（旧 JSON）会解码失败、生词本直接消失。

存储位置：

```
<App Group 容器>/FathomShared/vocabulary.json   // 生词本
<App Group 容器>/Library/Preferences/group.com.fathomapp.fathom.plist  // 设置
```

没有 App Group 时降级到各自的 `Application Support/FathomShared/`。

---

## 五、界面

| 文件 | 内容 |
| --- | --- |
| `Shared/Views/AnalysisFlowView.swift` | 解析流程（选中卡片 + 类型切换 + 底部按钮 + toast） |
| `Shared/Views/AnalysisResultView.swift` | 结果卡片（单词 / 句子两套布局） |
| `Shared/Views/ExtensionSetupView.swift` | 扩展里的「填 Key」界面 |
| `Fathom/Features/Library/LibraryView.swift` | 生词本列表 + 导出菜单 |
| `Fathom/Features/QuickInput/QuickInputView.swift` | 手动输入页 |

配色只用 `Color.accentColor`（在 `Assets.xcassets/AccentColor` 里改一处，全局生效）。

---

## 六、图标

```bash
# 需要 Python + Pillow
python scripts/make_icon.py
```

脚本会以 4 倍超采样画一张 1024×1024 的图，输出到
`Fathom/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`。
只声明了 1024 单尺寸，Xcode 会自动生成其余尺寸。

---

## 七、版本号与发版

- `project.yml`：`MARKETING_VERSION`（用户看到的版本）/ `CURRENT_PROJECT_VERSION`（内部 build 号）
- 每次发版把 build 号 +1，否则 TestFlight / 侧载可能认为没变化
- 推送到 `main` 会自动编译并产出新 IPA

---

## 八、自己加单元测试

目前没有测试。想加的话在 `project.yml` 里加一个 `FathomTests` target（type: bundle.unit-test），
优先测这几处纯逻辑：

- `ModelOutputParser.candidates/decode`（各种脏 JSON）
- `TextNormalizer.guessKind`
- `ExportService` 的 CSV 转义与 Anki 首行
- `DeepLinkCodec` 编解码往返
