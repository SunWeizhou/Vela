# Sentry 接入指南（H4 云端崩溃上报）

> 因本仓库开发环境的 SPM 二进制下载被 TLS 拦截无法验证，接线封装为脚本，
> 在**正常网络**（你本机 / GitHub Actions）执行一次即可。

## 步骤

```bash
# 1. 接线（生成 SentryService.swift + pbxproj SPM 补丁 + VelaApp.swift 钩子；幂等）
bash scripts/enable_sentry.sh

# 2. 构建（首次自动下载 sentry-cocoa 8.x；构建必须通过后再提交）
xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ~/Developer/Vela-DerivedData build

# 3. 在 [sentry.io](https://sentry.io) 创建 iOS 项目获取 DSN
# 4. 真机/模拟器上写入 DSN（App 内一次即可，Keychain 持久并随设备解锁可用）：
#    KeychainService.shared.save("<你的 DSN>", account: SentryService.dsnAccount)
```

## 设计边界（健康数据合规，CLAUDE.md 红线）

| 项 | 设置 |
| :--- | :--- |
| 未配置 DSN | 完全 no-op，零上传（`SentryService.configureOnLaunch()` 直接 return） |
| 面包屑 | 关闭（`enableAutoBreadcrumbTracking = false`） |
| PII | 关闭（`sendDefaultPii = false`） |
| 追踪采样 | 0（仅崩溃与异常上报） |
| 健康采样 | 永不进入 Sentry（上传内容仅技术诊断：崩溃栈、系统/设备信息） |

## 待确认项

- DSN 账号归属（个人 / 未来团队）——由你注册并保管，Keychain `sentry_dsn` 只会出现在你的设备上
- 若未来需要批量遥测：单独评估（当前报告未要求、合规边界更窄，不建议近期开启）
