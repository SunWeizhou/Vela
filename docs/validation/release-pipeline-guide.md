# 发布链路（审计 H5；未验证——需 Apple 开发者账号）

## 现状

仓库此前无任何发布流水线（无 fastlane / TestFlight / 版本号自动化），商店交付完全手工。
本目录提供**最小可用骨架**（`fastlane/Fastfile` + `Appfile`），尚未在本机验证——
验证需要：Apple Developer 账号、App Store Connect API Key、首次 App 记录创建。

## 启用步骤

```bash
# 1. 安装 fastlane（需要 Ruby；仓库首次）
gem install fastlane
# 或 bundle exec（若你有 Gemfile）

# 2. 提供凭据（环境变量，勿入库）
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXX.p8
export FASTLANE_TEAM_ID=...

# 3. 首次：在 App Store Connect 创建 App 记录 + 完成协议/税务

# 4. 构建并上传 TestFlight
fastlane beta
```

## 版本号约定

- `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 当前定义在 pbxproj
  （4.0.0 / 1）——上架自动化时可改为从 `fastlane/version.txt` 或 git tag 注入
  （本期未做，属后续演进项）。

## 验证清单（首次执行必检）

- [ ] xcodebuild archive 成功（Debug-iphoneos）
- [ ] TestFlight 构建上传成功且状态 Processing/Ready
- [ ] 真机安装包签名有效
- [ ] 隐私清单（PrivacyInfo.xcprivacy）随构建携带
