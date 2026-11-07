# 05 · 故障排查

> 按「你现在卡在哪一步」找对应小节。每条都给了「怎么确认」和「怎么办」。
> 如果最后还是要找人，**把报错原文（红字部分）复制给我**，比描述现象有用得多。

---

## A. GitHub 编译失败

### A1. Actions 页面空空如也，没有运行记录
- 检查仓库里有没有 `.github/workflows/build-ipa.yml`（网页上传常漏）
- 有文件但没跑：Actions 标签 → 黄色提示条 → **I understand my workflows, go ahead and enable them** → **Run workflow**

### A2. 报 `xcodegen: command not found`
流水线里 `brew install xcodegen` 失败（网络抖动）。在 Actions 页面点 **Re-run all jobs**。

### A3. 报 `error: no such module 'Translation'`
`Translation` framework 需要 iOS 18 SDK。流水线用的是 macos-15 + Xcode 16，正常不会出现；
出现说明 runner 镜像变了。把日志发我，我改 `runs-on` 或降级 API。

### A4. 报某个文件 `cannot find 'XXX' in scope`
九成是上传不全（少了 `Shared/` 里的某个文件）。对比仓库里的目录结构和本文档 [项目结构](../README.md#项目结构)。

### A5. 报 `Fathom.app/PlugIns/FathomAction.appex` 不存在
扩展 target 没编出来。看日志里 FathomAction 那段的第一条 `error:`。

### A6. Actions 页面完全没有运行记录，或者报「仓库里找不到 project.yml」
最可能的原因：**整个工程被套了一层文件夹**（仓库根目录只有一个 `fathom-ios/`）。

GitHub 只认仓库根目录下的 `.github/workflows/`，套了一层之后它连流水线都找不到，
所以不是"编译失败"，而是"根本没跑"。

修法：让仓库根目录直接看到这些——`project.yml`、`Fathom/`、`FathomAction/`、`Shared/`、
`docs/`、`scripts/`、`.github/`、`README.md`。在 GitHub Desktop 里把 `fathom-ios` 里面的
**内容**（不是文件夹本身）拖到仓库根目录，提交，然后去 Actions 页面刷新。

流水线开头也内置了一个「自愈」步骤，能处理两种边缘情况（根目录传了 `.zip`、或者 `.github`
在根目录但其余文件套在子目录里）；主路径仍然是上面这条。

判断自己上传对没对，最快的办法：打开仓库首页，地址栏是 `github.com/你的名字/fathom`，
页面上**应该直接列出 `Fathom` 文件夹和 `project.yml`**，而不是只有一个 `fathom-ios` 文件夹。

### A7. 报 `'TranslationSession' is unavailable in application extensions`
苹果不允许分享扩展里直接调用 Translation framework（离线翻译）。**这条需要我改代码**：
把报错原文贴给我，我会把离线兜底从扩展 target 里摘出去，并给扩展补一个「不显示离线区块」的空壳，
主 App 里的离线翻译照常可用。在线解析（DeepSeek）完全不受影响。

---

## B. AltStore 安装失败

| 报错 | 原因 | 处理 |
| --- | --- | --- |
| `Could not find AltServer` | 手机连不上电脑 | AltServer 以管理员运行；防火墙允许专用网络；同一 Wi-Fi；iTunes 勾「通过 Wi-Fi 同步」 |
| `NP_E_CONN_FAILED` / `AFC_E_MUX_ERROR` | 装的是 Microsoft Store 版 iTunes | 卸载后装官网 iTunes + iCloud |
| `Failed to fetch app IDs` / `1009` / `3013` | 本周 10 个 App ID 用完 | 等 7 天 / 换 Apple ID |
| `2009` | 同时 3 个侧载 App 已满 | 删掉一个 |
| `3014` / `3015` app group invalid | 免费证书没有这个 App Group | 不影响：本项目已内置「无 App Group」兜底，继续装，装完在 App 里填 Key |
| `The provided archive is invalid` | IPA 下坏了 / 少了 `Payload` | 重新下载 Artifacts；解压后确认 `Payload/Fathom.app` 存在 |
| 安装后图标点开闪退 | 证书过期 / 未信任 | 设置 → 通用 → VPN 与设备管理 → 信任；或 AltStore 里 Refresh |
| 双击 ipa 没反应 | 文件被 Windows 锁定 | 右键 → 属性 → 解除锁定 |

---

## C. 分享菜单里看不到 Fathom

**逐条确认：**

1. **是不是真的装上了扩展？** 主屏幕有 Fathom 图标 ≠ 扩展已登记。
   重启一次手机，再试。
2. **手动打开开关**：任意 App 里选中文字 → 分享 → 滑到最右 **更多** → **编辑操作** →
   在「Fathom」右侧打开开关（它可能被归在很下面）。还可以长按拖动排到前面。
3. **在 Safari 里**：选中文字后先点「分享」，如果菜单里没有，点「拷贝」旁边的 `>` 展开更多。
4. **在 Books 里**：只有「选中文字 → 分享」才带文本；分享整本书/PDF 文件时带的是文件，扩展不会出现。
5. **在 X 里**：X 经常只传链接不传文字，这是 X 的行为，不是本 App 的问题——用「解析」页粘贴。

> 扩展出现在分享面板的**操作行（第二行）**，不是第一行的 App 图标行。滑一下就能看到。

---

## C2. 在扩展里点「存入生词本」，没跳回 App

少数宿主不允许扩展唤起其它 App。此时扩展会：

1. 把一条「保存链接」复制到剪贴板；
2. 弹窗提示「已复制保存链接」。

回到 Fathom → **生词本**页左上角**剪贴板图标** → 这条结果直接入册（不会重新请求模型）。
在「解析」页粘这条链接并点「开始解析」也能识别（会弹「已存入生词本」）。

如果连剪贴板按钮都没存进去：说明剪贴板被别的 App 覆盖了，重新在扩展里点一次「存入生词本」即可。

---

## D. 扩展打开了，但显示「没有收到文字」

- 说明宿主 App 没有把纯文本交给扩展。换一个 App 试试（Safari / 备忘录最稳）。
- Books 里请确认是**选中文字后**分享，而不是在书架上分享书。
- 如果显示的是「**这个 App 只分享了链接**」：宿主只给了 URL（X、Instagram 常见）。
  这不是故障，扩展会主动拦下来，避免拿网址去问模型。按提示复制文字后用「解析」页粘贴即可。
- 万能兜底：复制那段文字 → 打开 Fathom → **解析** 标签 → **粘贴**。

---

## E. 解析报错

| 提示 | 原因 | 处理 |
| --- | --- | --- |
| `缺少 API Key` | 没填 / 填在别的地方 | 设置里粘贴 `sk-...`，点测试连接 |
| `401 Unauthorized` | Key 错误、多了空格、已删除 | 重新创建 Key，复制时不要带换行 |
| `402 Insufficient Balance` | 余额不足 | 去 platform.deepseek.com 充值 |
| `429 Too Many Requests` | 请求太快 | 等一下重试 |
| `500` / `503` | 服务商侧故障 | 稍后重试；换模型试试 |
| `网络错误` | 无网 / 代理拦截 | 关掉代理试试；DeepSeek 国内可直连 |
| `模型返回的内容无法解析` | 模型没按 JSON 输出 | App 会自动重发一次；仍失败就重试，或换模型 |
| `返回内容为空` | JSON 模式把非 JSON 内容替换成空白 | 已内置重发一次；连续出现请换模型 |
| 一直转圈超过 45 秒 | 请求超时 | 点「取消」重试；检查网络 |
| `收到的是一条链接，不是文字` | 该 App 分享时只给了 URL（X、Instagram 常见） | 见 [03 使用说明](03-usage.md) 的「X」一节：复制文字后用「解析」页粘贴 |

### 想自己看请求细节

设置 → 关于 里有服务商与模型信息。更细的排查可以在 Mac 上用 Xcode 连真机看控制台，
或在 iPhone 上装 Apple 的 **Console**（需要额外工具），一般不需要。

---

## F. 生词本 / 导出

- **只存了扩展里查的，主 App 生词本没有？**
  免费账号拿不到 App Group 时，两边各存各的。在结果页点**书签按钮**会把结果通过 URL 回传主 App
  （会短暂切到主 App，这是正常现象）。
- **导出的 CSV 用 Excel 打开是乱码？** 用「数据 → 从文本/CSV」导入，编码选 UTF-8；
  或直接用 Numbers / WPS 打开（我们已写 BOM，正常不会乱码）。
- **Anki 导入后没有格式？** 导入时确认分隔符选 **Tab**、勾选「允许 HTML」。
- **清空后能恢复吗？** 不能。数据只存在手机本地，没有任何云端备份。
  重要的话定期导出 CSV。

---

## G. 离线翻译不出现

1. 设置里确认「离线兜底翻译」是开的
2. 系统：设置 → 通用 → 语言与地区 → **翻译语言** → 添加「英语→简体中文」，下载语言包
3. 主 App 里解析一次，让系统准备好会话；扩展里无法弹下载框，语言包没装就不会显示
4. 仍然没有：说明主服务其实成功了（兜底只在失败时显示）

---

## H. App 打不开 / 打开就闪退

**99% 是免费证书 7 天到期。** 处理：

1. 电脑上以管理员运行 AltServer，手机同一 Wi-Fi
2. 打开 AltStore → My Apps → 下拉刷新 → Fathom 那一行 **Refresh**
3. 还是闪退：删除 App 重新安装（**生词本会丢**，先导出 CSV）

---

## I. 手机存储 / 性能

- Action 扩展有约 120 MB 内存上限，超了会被系统直接杀掉（表现为「卡片闪一下就消失」）。
  本项目只做网络请求 + 文本渲染，正常不会超；如果解析超长文本时闪退，请把文本截短到 1200 字符以内。
- 生词本数据是单个 JSON 文件，几千条也只有几 MB。
