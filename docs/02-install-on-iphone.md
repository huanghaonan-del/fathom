# 02 · 安装到 iPhone（Windows + AltStore）

> 目标：在不越狱、不花 99 美元的前提下，把 `Fathom-unsigned.ipa` 装进 iPhone 15 Pro。
> 我们用的是 **AltStore Classic**：它在 Windows 上跑一个「AltServer」，用你的**免费 Apple ID**
> 给 App 签名再装进手机，并且以后每次连着同一 Wi-Fi 会自动续签（免费证书 7 天过期）。

---

## 准备清单

- Windows 10 / 11
- iPhone 15 Pro + 数据线
- Apple ID（开了**双重认证**的普通账号即可）
- 第 01 步下载的 `Fathom-unsigned.ipa`
- 同一个 Wi-Fi（电脑和手机要在同一网络）

---

## 第 1 步：装「官网版」iTunes 和 iCloud

**这一步最容易踩坑**：Microsoft Store 里的 iTunes/iCloud 是精简版，**没有** AltServer 需要的
设备通信组件，装了也没用。

1. 先卸载：设置 → 应用 → 找到 `iTunes` / `iCloud` →（如果来源写着 Microsoft Store）卸载
2. 装官网 iTunes：<https://www.apple.com/itunes/download/win64>
3. 装官网 iCloud（苹果 CDN 直链，点开就开始下载 `iCloudSetup.exe`，约 200 MB）：
   <https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe>
   （Apple 官方支持页面的写法已失效，这个直链来自 AltStore 官方安装文档）
4. 装完**先各打开一次**，并用**同一个 Apple ID** 登录：
   iTunes → 账户 → 登录；iCloud → 登录。
5. 在 iTunes 里确认能识别到你的 iPhone（手机插上后点左上角的小手机图标），
   并在设备页 → 摘要 → 选项里勾上 **「通过 Wi-Fi 同步」**（7 天续签要用）。

> 如果 iTunes 里看不到设备：换一根**能传数据**的线（不是只能充电的那种），
> 手机上点「信任此电脑」，输入锁屏密码。

---

## 第 2 步：装 AltServer

1. 打开 <https://altstore.io/> → 下载 **AltServer (Windows)**
   （直接链接：<https://cdn.altstore.io/file/altstore/altinstaller.zip>）
2. 解压 → 右键 `Setup.exe` → **以管理员身份运行**
3. 装完在**开始菜单**搜 `AltServer` → 右键 → **以管理员身份运行**
4. Windows 防火墙弹窗：勾选 **专用网络** → 允许访问
   （不点允许的话，手机会连不上电脑，后面会报 `Could not find AltServer`）
5. 托盘区（右下角小箭头里）出现一个菱形图标 = 成功了

> 如果杀毒软件报毒：AltServer 因为要常驻后台，偶尔会被误报，加白名单即可。

---

## 第 3 步：打开 iPhone 的「开发者模式」

1. 用数据线把 iPhone 连到电脑，手机上点 **信任**，输入密码
2. iPhone：**设置 → 隐私与安全性 → 拉到最底 → 开发者模式** → 打开 → 重启手机
3. 重启后会弹窗再确认一次「打开开发者模式」→ 输入密码

> 如果「开发者模式」这一项**根本不存在**：说明手机还没被识别成开发设备。
> 保持插线、AltServer 在运行，重新打开 iTunes 等 10 秒，再回设置里看；
> 还是没有就拔插一次数据线。

---

## 第 4 步：装 AltStore 本体

1. 电脑托盘图标 → AltServer 图标 → **Install AltStore** → 选择你的 iPhone
2. 输入 **Apple ID 和密码**（只发给苹果的服务器，AltStore 不保存）
3. 如果开了双重认证，手机会弹 6 位验证码，填进去
4. 手机上出现 AltStore 图标后：**设置 → 通用 → VPN 与设备管理 → 开发者 App → 你的 Apple ID → 信任**
5. 打开 AltStore，允许通知

> 报错 `Could not find AltServer`：确认 AltServer 以管理员运行、防火墙允许专用网络、
> 手机和电脑在同一 Wi-Fi、iTunes 勾了「通过 Wi-Fi 同步」（iTunes → 设备页 → 摘要 → 选项）。

---

## 第 5 步：把 Fathom 装进去

1. 把 `Fathom-unsigned.ipa` 放到电脑上一个好找的位置
2. iPhone 打开 **AltStore** → 底部 **My Apps** → 右上角 **+**
3. 选 `Fathom-unsigned.ipa`（如果文件在电脑上：AltStore 2.3 起可以通过 AltServer 传文件；
   更简单的方式是把 ipa 用微信/QQ/网盘发到手机，存到「文件」App，再在 AltStore 里选它）
4. 输入同一个 Apple ID 签名 → 等 1–2 分钟
5. 主屏幕出现 **Fathom** 图标 ✔

> 安装时如果提示 **「未受信任的开发者」**：设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID。

---

## 第 6 步：7 天续签（重要）

免费证书 **7 天**过期，过期后图标还在但点开闪退。续签方法：

- **自动**：iPhone 和电脑在同一 Wi-Fi，AltServer 在托盘运行着，
  AltStore 后台刷新打开（设置 → AltStore → Background Refresh），
  它会在到期前自动续签。电脑关机/不在同一网络时不会续。
- **手动**：AltStore → My Apps → 下拉刷新，或在 Fathom 那一行点 **Refresh**。

> 换手机、重装系统、取消 AltServer 后，App 需要重新安装一次。
> 免费账号同时最多 **3 个** 侧载 App，每 7 天最多注册 **10 个** App ID。

---

## 关于「分享菜单扩展」会不会一起装上

会。这个 IPA 里包含主 App（`Fathom.app`）和扩展（`PlugIns/FathomAction.appex`），
**但扩展必须在系统里被登记**，否则分享菜单里看不到它。安装完成后：

1. 随便打开一个能选字的 App（例如 Safari 或备忘录）
2. 长按选中一句英文 → 点 **分享** → 面板底部滑到最右 → **更多**
3. 找到 **Fathom**，打开开关，还可以拖到靠前的位置
4. 之后每次选中文字，分享面板里就有 Fathom

> 如果列表里完全没有 Fathom：重启一次手机再看；仍然没有说明扩展没装进 App
> （回到第 01 步确认 Artifacts 里的 IPA 是完整的，或者看 [故障排查](05-troubleshooting.md)）。

---

## 常见错误码

| 提示 | 含义 | 怎么办 |
| --- | --- | --- |
| `1009` / `3013` | 本周 10 个 App ID 用完了 | 等 7 天，或换一个 Apple ID |
| `2009` | 同时安装的 App 超过 3 个 | 删掉一个不用的侧载 App |
| `3014` / `3015` | App Group 无效 / 不存在 | 本项目已做兜底，不影响使用；装完在 App 里正常填 Key 即可 |
| `1012` | AltStore 自己的共享容器打不开 | 重启手机，重开 AltStore |
| `Could not find AltServer` | 电脑与手机没连上 | 见第 2 步的防火墙 / Wi-Fi 检查 |
| `NP_E_CONN_FAILED` / `AFC_E_MUX_ERROR` | iTunes 不是官网版 | 重装官网 iTunes + iCloud |

更多见 <https://faq.altstore.io/altstore-classic/error-codes>

---

## 懒人替代方案

- **iloader**（<https://iloader.app>）：图形界面点「Import any IPA」即可，步骤比 AltStore 少，
  但**不会自动续签**，7 天后要手动重装一次。适合「先试试看」。
- **Sideloadly**：一键安装，但对「带扩展的 IPA」成功率最低，不推荐。
- 想彻底摆脱 7 天限制：99 美元/年开发者账号 → TestFlight。需要时告诉我，我给你写上传步骤。
