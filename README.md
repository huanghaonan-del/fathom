# Fathom · iOS 划词解析

在 iPhone 上选中任何一段英文 —— Apple Books、Safari、X（Twitter）、PDF、邮件 —— 点「分享」→「Fathom」，
立刻得到中文解析：

- **单词**：音标、词性、中文释义、常见搭配、例句、语义辨析、记忆钩子
- **句子**：整句翻译、主谓宾结构、从句拆解、难点词汇、语法要点、CEFR 难度
- 结果可一键复制，自动存进**生词本**，可导出 **CSV / Anki**

![App 图标](Fathom/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)

---

## 你需要准备什么

| 需要 | 说明 |
| --- | --- |
| 一台 **Windows** 电脑 | 用来跑 AltStore、把 App 装进手机（不需要 Mac） |
| iPhone 15 Pro（iOS 26.3） | 目标设备 |
| 一个 **Apple ID** | 免费账号即可，不用 99 美元开发者账号 |
| 一个 **DeepSeek API Key** | 注册充值 1 元就能用很久，见 [引擎与费用](docs/04-engines-and-cost.md) |
| 一个 **GitHub 账号** | 用来「借用」苹果电脑编译出 IPA（免费，注册 1 分钟） |

> 为什么需要 GitHub？打 iOS 安装包必须有 macOS + Xcode。
> 本项目配好了云端编译流水线，你只要把代码传上去，GitHub 会免费给你一台 Mac 编译，
> 5 分钟后产出一个可以安装的 `.ipa` 文件。你全程不碰任何代码。

---

> 👉 **第一次来，别从这份 README 开始。** 直接看
> **[从零到能用：照着一格格点](docs/00-start-here.md)** —— 14 个步骤，每一步点哪里、看到什么、
> 卡住了怎么办都写清楚了。下面这份是给你了解原理和查资料用的。

---

## 四步装到手机上

1. **[把代码传到 GitHub](docs/01-build-ipa.md)** —— 建仓库、拖文件夹上传
2. **等云端编译** —— 自动开始，约 5–10 分钟，产出一个 `Fathom-unsigned.ipa` 压缩包
3. **[装 AltStore](docs/02-install-on-iphone.md)** —— Windows 上装一次，之后每 7 天自动续签
4. **[填 API Key、开始用](docs/03-usage.md)** —— 在 App 设置里粘贴 Key，然后在别的 App 里选中文字分享给 Fathom

每一步都写了截图级的文字步骤和常见报错处理，遇到问题先看 [故障排查](docs/05-troubleshooting.md)。

> 免费 Apple ID 的签名 **7 天过期**，过期后 App 打不开。AltStore 会在你连着同一个 Wi-Fi 时自动续签；
> 如果嫌麻烦，可以升级 99 美元/年的开发者账号，走 TestFlight，一次安装一年有效。

---

## 三个入口，覆盖所有阅读场景

| 入口 | 怎么用 | 适合 |
| --- | --- | --- |
| **分享菜单**（Action Extension） | 长按选中 → 分享 → Fathom | Apple Books、Safari、PDF、备忘录、邮件 |
| **解析页** | App 第二个标签，粘贴或手打一段英文 | X 这类分享菜单拿不到文字的 App；精读长句 |
| **剪贴板** | 生词本页面左上角剪贴板图标 | 已在别处复制好的内容 |

选中文字后如果「分享」面板里没看到 Fathom，点最右边的 **「更多」→「编辑操作」** 把它打开一次即可。

---

## 项目结构

```
fathom-ios/
├── project.yml                    # XcodeGen 工程描述（.xcodeproj 由它生成）
├── Fathom/                        # 主 App
│   ├── App/                       # 入口、Tab、深链
│   ├── Features/Library/          # 生词本、详情、导出
│   ├── Features/QuickInput/       # 手动输入解析页
│   ├── Features/Settings/         # 服务商 / Key / 模型 / 离线开关
│   ├── Assets.xcassets/           # App 图标与主题色
│   ├── Info.plist                 # 注册 fathom:// URL Scheme
│   └── Fathom.entitlements        # App Group
├── FathomAction/                  # 分享菜单扩展
│   ├── ActionViewController.swift # 取选中文字 → 挂 SwiftUI
│   ├── ActionRootView.swift       # 没 Key 时先要求填 Key
│   └── Info.plist                 # NSExtensionActivationSupportsText
├── Shared/                        # 主 App 与扩展共用
│   ├── Models/                    # 数据结构（容错解码）
│   ├── Services/                  # LLMClient / AnalysisService / PromptBuilder
│   ├── Storage/                   # App Group 存储、设置、生词本
│   └── Views/                     # 解析结果界面（两边复用）
├── scripts/make_icon.py           # 用 Pillow 生成 App 图标
├── scripts/build-mac.sh           # 有 Mac 时一条命令生成工程并打开 Xcode
└── .github/workflows/build-ipa.yml # 云端编译流水线
```

技术要点：

- **Swift + SwiftUI**，最低 iOS 18（用到 `@Observable`、`Translation` framework、`PasteButton`）
- 主 App 与扩展共用 `Shared/` 源码，通过 **App Group**（`group.com.fathomapp.fathom`）共享设置与生词本
- **没有 App Group 时自动降级**：扩展在自己的沙盒里存一份配置，解析完用
  `fathom://save?data=<base64>` 把结果回传给主 App 保存。免费账号侧载经常拿不到 App Group，
  这条兜底链路保证「就算共享失效，功能也完整」
- 模型输出做了三层容错：JSON 代码块 / 前后废话 / 尾逗号；仍失败会发一次「修复请求」

---

## 文档

| 文档 | 内容 |
| --- | --- |
| **[00 从零到能用](docs/00-start-here.md)** | **14 步全流程，第一次装只看这一份** |
| [01 云端编译出 IPA](docs/01-build-ipa.md) | 注册 GitHub、上传代码、触发编译、下载产物 |
| [02 安装到 iPhone](docs/02-install-on-iphone.md) | AltStore 在 Windows 上的完整安装与签名流程 |
| [03 使用说明](docs/03-usage.md) | 填 Key、在 Books / Safari / X 里划词、生词本与导出 |
| [04 引擎与费用](docs/04-engines-and-cost.md) | DeepSeek / OpenAI / Claude / DeepL / 苹果原生，成本与效果对比 |
| [05 故障排查](docs/05-troubleshooting.md) | 编译失败、扩展不出现、7 天过期、报错码 |
| [06 二次开发](docs/06-development.md) | 改提示词、换模型、加功能；有 Mac 时的本地构建 |
| [07 常见问题](docs/07-faq.md) | 一定要 GitHub 吗、能不能给朋友装、7 天限制、数据存哪 |

---

## 已知限制（先看这里，避免白折腾）

- **X（Twitter）里选中文字分享**：X 的分享菜单通常只给帖子链接、不给选中的文字。若只收到链接，
  扩展会提示「这个 App 只分享了链接」而不是去解析一个网址。请用「解析页」粘贴，或先在 X 里复制。
- **免费账号 7 天有效期**：必须在 AltStore 里续签，且「同时最多 3 个 App」。
- **App Group 在侧载后可能失效**：功能不受影响（有兜底），但扩展与主 App 的生词本会各存各的，主 App 收不到扩展的结果时以回传按钮为准。
- **离线兜底**是苹果原生翻译，只能给「整句译文」，没有语法解析，且需要先在系统里下载英中语言包。
