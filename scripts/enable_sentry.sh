#!/usr/bin/env bash
# 启用 Sentry 崩溃上报（审计 H4 云端部分）
#
# 本仓库环境曾因 SPM 下载 Sentry 二进制 xcframework 被 TLS 拦截而无法验证；
# 在正常网络（你本机 / GitHub Actions）上运行本脚本即可完成接线：
#   1. 生成 VelaApp/AI/Provider/SentryService.swift（DSN 存 Keychain、缺省 no-op、
#      强制关闭 PII/面包屑/追踪，符合健康数据合规红线）
#   2. 给 Vela.xcodeproj 打 SPM 补丁（sentry-cocoa@8.x + Sentry product + Frameworks 挂载）
#   3. 把 SentryService.swift 挂进 Vela target（否则 VelaApp.swift 找不到类型）
#   4. 在 VelaApp.swift init 接线 SentryService.configureOnLaunch()
#
# 幂等：每步单独检查，重复运行安全。
set -euo pipefail
cd "$(dirname "$0")/.."

SERVICE_FILE="VelaApp/AI/Provider/SentryService.swift"
if [ ! -f "$SERVICE_FILE" ]; then
cat > "$SERVICE_FILE" <<'SWIFT'
import Foundation
import Sentry

/// 崩溃上报（审计 H4）——可选启用：DSN 存 Keychain（account: "sentry_dsn"），
/// 未配置时完全 no-op（不上传任何数据）；用户显式配置后才发送崩溃与诊断。
/// 隐私边界：原始健康采样永不出设备；Sentry 仅接收技术诊断（崩溃栈/系统信息）；
/// breadcrumb 关闭、PII 关闭、tracing 采样率 0。
enum SentryService {
    static let dsnAccount = "sentry_dsn"

    @MainActor
    static func configureOnLaunch(keychain: KeychainService = .shared) {
        guard let dsn = try? keychain.read(account: dsnAccount), !dsn.isEmpty else {
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAutoBreadcrumbTracking = false
            options.sendDefaultPii = false
            options.tracesSampleRate = 0
        }
    }

    @MainActor
    static var isConfigured: Bool {
        guard let dsn = try? KeychainService.shared.read(account: dsnAccount) else { return false }
        return !dsn.isEmpty
    }
}
SWIFT
    echo "created $SERVICE_FILE"
fi

# VelaApp.swift 接线（幂等）
if ! grep -q "SentryService.configureOnLaunch()" VelaApp/App/VelaApp.swift; then
  python3 - <<'PY'
from pathlib import Path
p = Path("VelaApp/App/VelaApp.swift")
t = p.read_text(encoding="utf-8")
old = "        // Register background task handler"
new = "        // 崩溃上报：DSN 未配置时完全 no-op，不上传任何数据。\n        SentryService.configureOnLaunch()\n\n        // Register background task handler"
assert t.count(old) == 1
p.write_text(t.replace(old, new), encoding="utf-8")
print("hooked SentryService.configureOnLaunch()")
PY
fi

# SentryService.swift 挂进 Vela target（幂等）
if ! grep -q "SentryService.swift in Sources" Vela.xcodeproj/project.pbxproj; then
python3 - <<'PY'
from pathlib import Path
import re
import hashlib
p = Path("Vela.xcodeproj/project.pbxproj")
text = p.read_text(encoding="utf-8")
src_id = hashlib.sha256("sentry-service-build".encode()).hexdigest().upper()[:24]
ref_id = hashlib.sha256("sentry-service-ref".encode()).hexdigest().upper()[:24]
assert text.count(src_id) == 0 and text.count(ref_id) == 0
def ins(needle, addition, expected=1):
    global text
    n = text.count(needle)
    assert n == expected, f"anchor {n}: {needle[:60]!r}"
    i = text.index(needle) + len(needle)
    text = text[:i] + addition + text[i:]
k_bf = re.search(r'^\t\t(\w{24}) /\* KeychainService.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = \w{24} /\* KeychainService.swift \*/; \};$', text, re.M).group(0)
ins(k_bf, f'\n\t\t{src_id} /* SentryService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* SentryService.swift */; }};', 1)
k_ref = re.search(r'^\t\t(\w{24}) /\* KeychainService.swift \*/ = \{isa = PBXFileReference;.*$', text, re.M).group(0)
ins(k_ref, f'\n\t\t{ref_id} /* SentryService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AI/Provider/SentryService.swift; sourceTree = "<group>"; }};', 1)
k_child = "\t\t\t\t" + re.search(r'^\t\t\t\t(\w{24}) /\* KeychainService.swift \*/,$', text, re.M).group(1) + " /* KeychainService.swift */,\n"
ins(k_child, f"\t\t\t\t{ref_id} /* SentryService.swift */,\n", 1)
k_phase = "\t\t\t\t" + re.search(r'^\t\t\t\t(\w{24}) /\* KeychainService.swift in Sources \*/,$', text, re.M).group(1) + " /* KeychainService.swift in Sources */,\n"
ins(k_phase, f"\t\t\t\t{src_id} /* SentryService.swift in Sources */,\n", 1)
p.write_text(text, encoding="utf-8")
print("SentryService.swift wired into target")
PY
else
  echo "SentryService.swift already wired (skip)"
fi

# SPM 接线（幂等）
if ! grep -q "sentry-cocoa" Vela.xcodeproj/project.pbxproj; then
python3 - <<'PY'
from pathlib import Path
import hashlib, re
p = Path("Vela.xcodeproj/project.pbxproj")
text = p.read_text(encoding="utf-8")
def nid(seed):
    h = hashlib.sha256(seed.encode()).hexdigest().upper()[:24]
    assert text.count(h) == 0, h
    return h
pkg_id, prod_id, fw_id = nid("sentry-cocoa-pkg"), nid("sentry-product"), nid("sentry-framework")
def ins(needle, addition, expected=1):
    global text
    n = text.count(needle)
    assert n == expected, f"anchor {n}: {needle[:60]!r}"
    i = text.index(needle) + len(needle)
    text = text[:i] + addition + text[i:]
ins("/* Begin PBXBuildFile section */\n",
    f"\t\t{fw_id} /* Sentry in Frameworks */ = {{isa = PBXBuildFile; productRef = {prod_id} /* Sentry */; }};\n", 1)
fw_block = text[text.find("\t\t0B0000080000000000000008 /* Frameworks */ = {"):]
fw_block = fw_block[:fw_block.find("\t\t\tfiles = (\n") + len("\t\t\tfiles = (\n")]
ins(fw_block, f"\t\t\t\t{fw_id} /* Sentry in Frameworks */,\n", 1)
ins("/* Begin PBXProject section */",
    f"/* Begin XCRemoteSwiftPackageReference section */\n\t\t{pkg_id} /* XCRemoteSwiftPackageReference \"sentry-cocoa\" */ = {{isa = XCRemoteSwiftPackageReference; repositoryURL = \"https://github.com/getsentry/sentry-cocoa\"; requirement = {{kind = upToNextMajorVersion; minimumVersion = 8.0.0;}}; }};\n/* End XCRemoteSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t{prod_id} /* Sentry */ = {{isa = XCSwiftPackageProductDependency; package = {pkg_id} /* XCRemoteSwiftPackageReference \"sentry-cocoa\" */; productName = Sentry; }};\n/* End XCSwiftPackageProductDependency section */\n\n", 1)
ins('\t\t\tprojectRoot = "";\n', f'\t\t\tpackageReferences = (\n\t\t\t\t{pkg_id} /* XCRemoteSwiftPackageReference "sentry-cocoa" */,\n\t\t\t);\n', 1)
ins("\t\t\tname = Vela;\n", f"\t\t\tpackageProductDependencies = (\n\t\t\t\t{prod_id} /* Sentry */,\n\t\t\t);\n", 1)
p.write_text(text, encoding="utf-8")
print("pbxproj wired")
PY
else
  echo "SPM wiring already present (skip)"
fi

echo ""
echo "=== 完成。下一步 ==="
echo "1) 用 Xcode 打开工程并构建（首次会自动下载 sentry-cocoa）："
echo "   open Vela.xcodeproj && xcodebuild -project Vela.xcodeproj -scheme Vela \\"
echo "     -destination 'generic/platform=iOS Simulator' -derivedDataPath ~/Developer/Vela-DerivedData build"
echo "2) 在 App 内（或临时代码/调试器）写入 DSN 启用："
echo "   KeychainService.shared.save(\"https://<key>@o<org>.ingest.sentry.io/<project>\", account: SentryService.dsnAccount)"
echo "3) 验证：触发一次崩溃（如 fatalError）→ Sentry 后台出现 issue；"
echo "   不填写 DSN 时 App 行为与现在完全一致（零上传）。"
