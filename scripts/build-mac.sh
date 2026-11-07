#!/usr/bin/env bash
# 有 Mac 的情况下用这个脚本，比手敲命令省事。
#
# 用法：
#   1. 把工程文件夹拖到终端里，或 cd 进来
#   2. bash scripts/build-mac.sh
#
# 它会：装 XcodeGen（没有的话）→ 生成 Fathom.xcodeproj → 用 Xcode 打开。
# 之后在 Xcode 里选自己的 Apple ID（免费账号即可）和 iPhone，点 ⌘R 直接装。

set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> 检查 XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "    没装，正在用 Homebrew 安装（需要几分钟）..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "    找不到 Homebrew。请先装 Homebrew：https://brew.sh" >&2
    exit 1
  fi
  brew install xcodegen
fi
xcodegen --version

echo "==> 生成 Xcode 工程"
xcodegen generate
echo "    已生成 Fathom.xcodeproj"

echo "==> 打开 Xcode"
open Fathom.xcodeproj

cat <<'TIP'

接下来在 Xcode 里：
  1. 左上角选 target「Fathom」→ Signing & Capabilities → Team 选你的 Apple ID
     （免费账号会显示 "Personal Team"）
  2. 如果 Bundle Identifier 被占用，在 project.yml 里把 com.fathomapp 改成
     你专属的名字，然后重新跑一次本脚本
  3. 手机连上电脑 → 顶部设备选你的 iPhone → 按 ⌘R
  4. 首次运行会提示「不受信任的开发者」：
     iPhone 设置 → 通用 → VPN与设备管理 → 信任你的 Apple ID

注意：免费账号生成的 App 7 天后会打不开，重新 ⌘R 一次即可，数据不丢。
TIP
