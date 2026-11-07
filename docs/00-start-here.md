# 从零到能用：照着一格格点

> 这份是**唯一需要从头读到尾**的文档。全程不需要写代码，只需要点按钮、复制粘贴。
> 界面文字会随软件版本略有变化，看到意思相近的按钮就对应着点。
> 中途卡住：先看本文最后的「卡点速查」，再看 [05 故障排查](05-troubleshooting.md)。

**准备清单**（缺一样都会卡住）

- [ ] Windows 10 / 11 电脑（64 位）
- [ ] iPhone 15 Pro，系统 iOS 26.3（iOS 18 及以上都行）
- [ ] 一根能传数据的 Lightning / USB-C 线（只能充电的线不行）
- [ ] 你自己的 Apple ID（免费账号，不需要 99 美元开发者账号）
- [ ] 一个能收邮件的邮箱（注册 GitHub 用）
- [ ] 支付宝/微信里准备 1 元人民币（DeepSeek 充值）

**时间预期**：第一次做完整套约 40–60 分钟，其中真正要你动手的约 20 分钟，
剩下是等编译（约 8 分钟）和下载安装（约 10 分钟）。第二次重装只要 5 分钟。

---

## 第 0 步：先花 2 分钟搞清楚这三样东西

| 东西 | 它干什么 | 为什么非它不可 |
| --- | --- | --- |
| **GitHub** | 免费借一台苹果电脑给你编译 | 打 iOS 安装包必须有 macOS + Xcode，Windows 做不到 |
| **IPA 文件** | 就是安装包（相当于安卓的 APK） | 装到 iPhone 上的东西 |
| **AltStore** | 用你的免费 Apple ID 给 IPA 签名并安装 | 苹果不允许装没签名的 App |

整个流程就是：**代码 → GitHub 编译 → 拿到 IPA → AltStore 签名安装 → 用**。
后面 14 步全部围绕这条线，没有任何分叉。

---

## 第 1 步：注册 GitHub（约 5 分钟）

1. 浏览器打开 <https://github.com/signup>
2. 依次填：邮箱 → 密码（至少 8 位，含数字）→ 用户名
   - 用户名只能用英文、数字、短横线，例如 `xiaoming-fathom`
   - **记下来**，后面仓库地址里会用到
3. 收邮件，把 6 位验证码填进去
4. 如果问「How many team members will you be working with?」→ 选 **Just me**
5. 如果问选哪个计划 → 选 **Free**（0 美元，不是 4 美元那个）

---

## 第 2 步：新建一个仓库（约 2 分钟）

仓库（repository）就是「放代码的网盘文件夹」。

1. 登录后点右上角 **+** → **New repository**
2. **Repository name** 填 `fathom`
3. 下面选 **Public**（公开。里面没有任何隐私信息，只是代码）
4. **不要**勾「Add a README file」「Add .gitignore」——勾了后面会多一次冲突
5. 点绿色 **Create repository**
6. 新页面会显示一个地址，形如 `https://github.com/你的用户名/fathom.git`，**复制下来**

---

## 第 3 步：装 GitHub Desktop（约 5 分钟）

用它上传文件，能保证 `.github` 这种隐藏文件夹不会被漏掉——网页上传最容易在这里翻车。

1. 打开 <https://desktop.github.com/download/> → **Download for Windows**
2. 双击下载的 `GitHubDesktopSetup-x64.exe`，一路下一步，装完会自动打开
3. 点 **Sign in to GitHub.com** → 浏览器里点 **Authorize desktop** → 回到软件
4. 填 Name（随便）和 Email（你的邮箱）→ **Finish**

---

## 第 4 步：把工程解压到电脑上（约 1 分钟）

1. 右键 `fathom-ios.zip` → **全部解压**（不要直接双击进去拖，会丢隐藏文件）
2. 得到 `fathom-ios` 文件夹，里面应该看到这些：

```
README.md   project.yml   docs   scripts
Fathom      FathomAction  Shared   .github
```

3. **看不到 `.github`？** 资源管理器顶部 → **查看** → **显示** → 勾上 **隐藏的项目**

---

## 第 5 步：把工程传上去（约 5 分钟）

1. GitHub Desktop → 菜单 **File** → **Clone repository** → 切到 **URL** 标签
2. 粘贴第 2 步复制的地址 → **Local path** 选一个好找的位置（例如 `D:\GitHub\fathom`）→ **Clone**
3. 打开这个 `fathom` 文件夹（现在是空的，只有一个隐藏的 `.git`）
4. 回到解压出来的 `fathom-ios` 文件夹，**全选里面的所有内容**（Ctrl+A），复制
5. 粘贴到刚才的 `fathom` 文件夹里（覆盖粘贴，提示合并就选「是」）
6. 回到 GitHub Desktop：左边 **Changes** 应该出现 **40 多个文件**
   - 如果只有几个或 0 个，说明你拖进了外层文件夹，检查是不是变成了 `fathom\fathom-ios\README.md`
7. 左下 Summary 填 `first commit` → 点 **Commit to main**
8. 点右上 **Publish repository**（或 **Push origin**）
9. 浏览器打开 `https://github.com/你的用户名/fathom` 刷新，能看到 README 和 `.github` 就成功了

---

## 第 6 步：等云端编译出 IPA（约 8 分钟）

1. 仓库页面顶部点 **Actions**
2. 应该已经有一条正在跑的任务：黄色圆点 = 进行中，绿色对勾 = 成功，红色叉 = 失败
3. 等 5–10 分钟，变成绿色对勾后点进那次运行
4. 页面下方 **Artifacts** → 点 **Fathom-unsigned-ipa** 下载
5. 解压下载的 zip，里面就是 `Fathom-unsigned.ipa`（约 1–2 MB）

> **如果出现红色叉**：点进运行记录，页面顶部有个「编译错误摘要」框，
> 把那一框截图/复制发给我，我改完代码你重新上传一次即可。
> 第一次没跑通很正常，绝大多数是某个 API 写法过时，改一行就好。

---

## 第 7 步：在 Windows 装 iTunes 和 iCloud（约 10 分钟）

⚠️ 必须装**苹果官网版**。微软商店（Microsoft Store）里的版本**缺组件，AltStore 一定连不上手机**。

1. iTunes：打开 <https://www.apple.com/cn/itunes/download/win64/> 下载并安装
   （页面若提示商店版，选「仍要下载 Windows 版」）
2. iCloud：打开 <https://support.apple.com/zh-cn/106446> 下载 Windows 版并安装
3. 依次打开 iTunes 和 iCloud，各登录一次你的 Apple ID，然后可以关掉
4. iTunes 里：**编辑 → 偏好设置 → 设备** → 勾选 **防止 iPod、iPhone 和 iPad 自动同步**

---

## 第 8 步：装 AltStore（约 5 分钟）

1. 打开 <https://altstore.io/> → **Download AltServer for Windows**
2. 解压 → 右键 `AltServer.exe` → **以管理员身份运行**（必须管理员，否则连不上手机）
3. 它会缩到右下角托盘，图标是一个菱形
4. 首次弹「Windows 安全中心防火墙」→ 勾**专用网络** → 允许访问
5. 用数据线连上 iPhone，手机上点 **信任** → 输入锁屏密码
6. 托盘右键 AltServer → **Install AltStore** → 选你的 iPhone
7. 弹出登录框：填 Apple ID 和密码
   - 这里只是让苹果给你发一张 7 天有效的签名证书，密码不会存在别的服务器
   - 如果开了双重认证，可能要填一次手机收到的验证码
8. 手机上出现 AltStore 图标即成功

---

## 第 9 步：打开 iPhone 的「开发者模式」（约 3 分钟，必做）

1. iPhone → **设置 → 隐私与安全性** → 滑到最底 **开发者模式** → 打开
2. 系统要求重启 → 重启
3. 重启后弹「要打开开发者模式吗？」→ **打开** → 输入锁屏密码

> 找不到「开发者模式」这一项？说明手机还没被电脑识别过。
> 先完成第 8 步连线，再回来看。

---

## 第 10 步：信任证书 + 登录 AltStore

1. iPhone → **设置 → 通用 → VPN 与设备管理** → **开发者 App** → 点你的 Apple ID → **信任**
2. 打开 AltStore → 右上/设置里登录同一个 Apple ID（保持登录，否则 7 天后无法续签）

---

## 第 11 步：安装 Fathom（约 3 分钟）

1. 手机插在电脑上，`AltServer.exe` 保持在托盘运行
2. 打开手机上的 AltStore → 底部 **My Apps** → 左上角 **+**
3. 选你解压出来的 `Fathom-unsigned.ipa`
4. 等 1–2 分钟，桌面出现 **Fathom** 图标
5. 第一次打开若提示「不受信任的开发者」→ 回第 10 步再信任一次

> 装完可以拔线。但**每 7 天**需要电脑 + 同一 Wi-Fi 续签一次（见第 14 步）。

---

## 第 12 步：填 DeepSeek 的 API Key（约 5 分钟）

1. 电脑浏览器打开 <https://platform.deepseek.com> → 注册/登录
2. 左侧 **充值** → 充 1 元（够用几千次）
3. 左侧 **API keys** → **创建 API key** → 名字随便 → 复制那串 `sk-` 开头的字符
   - 只显示一次，先粘到记事本
4. 手机打开 Fathom → 底部 **设置** → 服务商选 **DeepSeek**
5. 把 Key 粘进输入框 → 点 **测试连接** → 显示成功即可
6. 切到 **解析** 标签，粘一句英文 → **开始解析**

> 扩展（分享菜单）第一次用时会让你再填一次 Key —— 这是免费账号的正常现象，
> 因为扩展和主 App 的数据没有共享容器。填一次就不用了。

---

## 第 13 步：把 Fathom 加进分享菜单（约 2 分钟）

1. 打开 Safari，随便长按选中一段英文 → **分享**
2. 分享面板滑到最右 → **更多** → **编辑操作**
3. 在「操作」列表里找到 **Fathom**，把开关打开 → **完成**
4. 以后在任何 App 里：长按选中 → 分享 → **Fathom**

> Apple Books 里要先「高亮/摘录」再分享，才能拿到文字。

---

## 第 14 步：7 天续签（之后每 7 天一次）

**自动**（推荐）：iPhone 和电脑连同一个 Wi-Fi，电脑上 AltServer 在运行，
AltStore 设置里打开「Background Refresh」→ 到期前会自动续签。

**手动**：手机连电脑 → AltStore → My Apps → 下拉刷新。

> 超过 7 天没续签，Fathom 会点不开。**不用慌，重新装一次就行，生词本数据不会丢。**

---

## 卡点速查

| 你看到的 | 原因 | 怎么办 |
| --- | --- | --- |
| Actions 里红色叉 | 代码编译错误 | 复制「编译错误摘要」发我，改完重传 |
| GitHub Desktop 里 Changes 是 0 | 文件放错层级 | 确认路径是 `fathom\README.md` 而不是 `fathom\fathom-ios\README.md` |
| GitHub 上看不到 `.github` | 上传时漏了隐藏文件夹 | 重新按第 5 步拖一次 |
| AltServer 提示 `NP_E_CONN_FAILED` | 装的是商店版 iTunes | 卸载，改官网版（第 7 步） |
| AltServer 找不到设备 | 数据线/信任/驱动 | 换线、重新点「信任」、重启 Apple Mobile Device Service |
| `1009` / `3013` | 这个 Apple ID 的 App ID 用完了（每周 10 个） | 等 7 天，或换个 Apple ID |
| `2009` | 同时最多 3 个自签 App | 在 AltStore 里删掉一个不用的 |
| `3014` / `3015` | App Group 无效 | 不影响使用，本项目已内置无 App Group 兜底，继续装 |
| Fathom 打不开、闪退 | 证书过期（超过 7 天） | 按第 14 步续签 |
| 设置里「测试连接」失败 401 | Key 错了或过期 | 重新复制 Key，注意别带空格 |
| 设置里失败 402 | 余额不足 | 充 1 元 |
| 分享面板里没有 Fathom | 扩展没被启用 | 第 13 步手动打开开关 |
| 解析结果一直是「空内容」 | 模型返回被截断 | 点「重新解析」；仍不行换 `deepseek-v4-pro` 试试 |

---

## 接下来读什么

- 想调提示词、换模型、改 bundle id → [06 二次开发](06-development.md)
- 想知道各家引擎的价钱差别 → [04 引擎与费用](04-engines-and-cost.md)
- 更多报错细节 → [05 故障排查](05-troubleshooting.md)
- 「一定要 GitHub 吗 / 能不能给朋友装 / 数据存哪」→ [07 常见问题](07-faq.md)
