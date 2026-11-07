# 01 · 用 GitHub 云端编译出 IPA

> 你没有 Mac，所以「编译」这一步交给 GitHub 的免费 macOS 服务器。
> 你要做的只有两件事：**把代码传上去**，**把产物下载下来**。
> 全程大约 10 分钟，其中 5 分钟是在等编译。
>
> 💡 这是详细参考版。想要「按顺序一路点下去」的版本，看
> [00 从零到能用](00-start-here.md)。

---

## 0. 先看这张流程图

```
你的 Windows                     GitHub（免费）                   你的 iPhone
─────────────                    ──────────────                   ───────────
上传代码  ───────────────────▶   macOS 服务器执行 xcodebuild
                                        │
下载 Fathom-unsigned.ipa ◀──────────────┘
        │
        └──▶ AltStore 签名安装 ────────────────────────────────▶  Fathom
```

---

## 1. 注册 GitHub（已有账号跳到第 2 步）

1. 打开 <https://github.com/signup>
2. 填邮箱 → 设密码 → 起用户名（英文数字，例如 `haonan-dev`）
3. 邮箱收验证码，填进去
4. 完成人机验证，选 **Free** 计划

> 国内访问 GitHub 有时很慢或打不开，你的代理开着就行。
> 如果网页能开但 `git` 推送失败，用下面的 **GitHub Desktop** 方式通常更稳。

---

## 2. 建一个仓库

1. 右上角 **+** → **New repository**
2. **Repository name** 填 `fathom-ios`
3. 选 **Public**（推荐：公开仓库的编译时长完全免费、不限量；私有仓库每月只有约 200 分钟 macOS 额度，也够用）
4. 下面三个勾（Add README / .gitignore / license）**都不要勾**
5. 点 **Create repository**

创建后页面会显示一个空仓库，中间有 `uploading an existing file` 的链接。

---

## 3. 把代码传上去

### 方式 A：GitHub Desktop（推荐，最不容易出错）

网页上传有个坑：浏览器往往**不会上传 `.github` 这种以点开头的隐藏文件夹**，
而这个文件夹里正好是编译流水线。用桌面客户端可以避免。

1. 下载安装 [GitHub Desktop](https://desktop.github.com/)（Windows 版）
2. 打开 → **Sign in to GitHub.com** → 浏览器里授权
3. 菜单 **File → Clone repository** → 选你刚建的 `fathom-ios` → **Clone**
4. 记下它克隆到的本地路径（例如 `C:\Users\你\Documents\GitHub\fathom-ios`）
5. 把本项目压缩包解压，**把 `fathom-ios` 文件夹里的所有内容**（不是文件夹本身）
   复制到这个本地路径，覆盖过去。复制完应该长这样：

   ```
   C:\Users\你\Documents\GitHub\fathom-ios\
   ├── README.md
   ├── project.yml
   ├── Fathom\
   ├── FathomAction\
   ├── Shared\
   ├── docs\
   ├── scripts\
   └── .github\workflows\build-ipa.yml
   ```

6. 回到 GitHub Desktop，左下角 **Summary** 填 `init`，点 **Commit to main**
7. 点右上 **Push origin**

### 方式 B：网页拖拽（快，但要检查两步）

1. 在仓库页面点 **uploading an existing file**
2. 打开解压后的 `fathom-ios` 文件夹，全选里面的内容，拖进浏览器
3. 等文件列表走完，**Summary** 填 `init` → **Commit changes**

传完请检查两件事：

- 仓库首页能看到 `project.yml`、`Fathom`、`Shared` 等
- 仓库里存在 `.github/workflows/build-ipa.yml`。**如果没有**：
  点 **Add file → Create new file**，文件名填 `.github/workflows/build-ipa.yml`
  （输入 `/` 会自动建文件夹），把本项目里同名文件的内容整段粘进去，提交。

---

## 4. 等它自己编译

推送（Push）完成后，GitHub 会自动开始编译：

1. 打开仓库页面 → 顶部 **Actions** 标签
2. 左侧看到 **Build unsigned IPA**，右侧有一条正在转圈的记录
3. 点进去 → 点 **build** 这个 job → 能看到实时日志
4. 大约 **4–6 分钟**，全部变绿 ✔

> 第一次用 Actions 可能看到黄色提示条：
> 「Workflows aren't being run on this repository」→ 点 **I understand my workflows, go ahead and enable them**，
> 然后到 Actions 页面点 **Run workflow** 手动跑一次。

编译过程中你会看到这些步骤，都是自动的：

| 步骤 | 在干什么 |
| --- | --- |
| Install XcodeGen | 装一个把 `project.yml` 转成 Xcode 工程的工具 |
| Generate Xcode project | 生成 `Fathom.xcodeproj` |
| Build | 真正编译（`CODE_SIGNING_ALLOWED=NO`，不签名，所以不需要证书） |
| Package IPA | 把 `Fathom.app` 装进 `Payload/` 并打 zip |
| Upload IPA | 把结果上传，供你下载 |

---

## 5. 下载 IPA

1. 编译成功的记录页面往下滚，找到 **Artifacts** 区域
2. 下载 **Fathom-unsigned-ipa**（会得到一个 zip）
3. 解压，里面是 `Fathom-unsigned.ipa`
4. 顺便可以下载 **Fathom-xcodeproj** 备用（以后有 Mac 时能直接打开工程）

> ⚠️ 下载的 zip 有时会被 Windows 标记为「来自其他计算机」，
> 右键 → 属性 → 勾选「解除锁定」→ 确定。不解除的话 AltStore 可能读不了。

---

## 6. 编译失败了怎么办

先别慌，九成是上传时少了文件。按顺序检查：

1. **仓库根目录有没有 `project.yml`？** 如果在某个子文件夹里（例如 `fathom-ios/fathom-ios/project.yml`），
   说明你把外层文件夹也传了进去——GitHub Desktop 里删掉多余那层再提交即可。
2. **`.github/workflows/build-ipa.yml` 在不在？** 不在就按第 3 步方式 B 手动创建。
3. **是不是少传了 `Shared/` 或 `FathomAction/`？** 少一个目录必然编译失败。
4. 还不行：在失败的 job 页面展开报错步骤，**把红色那几行复制给我**，
   我根据报错改代码。日志里通常写着 `error: ...` 和文件名、行号。

> **最快拿到错误的两条路**（不用翻几屏日志）：
> - 打开失败的那次运行，页面最上方 **Summary** 里有一块「**编译错误摘要**」，直接截图或复制给我；
> - 或者在同一页的 **Artifacts** 下载 **build-log**（只有失败时才有），解压得到 `build.log`，发我。
>
> 发的时候不用挑，整段贴过来就行——我自己找关键行。

> 说明：本项目是「未签名 IPA」。AltStore 安装时会用自己的免费证书重新签名，
> 所以编译阶段不需要你的 Apple ID，也不需要证书文件。

---

## 7. 以后的更新

改了代码（或者我发给你新版本）后重复第 3 步的「覆盖文件 → Commit → Push」，
云端会自动重新编译，再下一次 Artifacts 即可。
