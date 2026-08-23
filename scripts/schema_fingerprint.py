#!/usr/bin/env python3
"""Vela SwiftData schema 版本守卫

提取 App 中全部 @Model 的持久化属性指纹，并与黄金快照比较：
  - 任何人改了 @Model 的属性/属性注解，`--check` 会失败，
    直到他按流程：冻结旧版本 → 新建版本（bump versionIdentifier）→ 更新黄金快照。

用法：
  python3 scripts/schema_fingerprint.py --check       # CI 门禁（默认）
  python3 scripts/schema_fingerprint.py --update      # 生成/更新黄金快照（模型变更时）
  python3 scripts/schema_fingerprint.py --emit-frozen # 重新生成 V3 冻结模型文件

规则（见脚本头的 goldens 结构）：
  goldens["4.0.0"] = 当前模型图指纹（来自生产代码，VelaSchemaV4）
  goldens["3.0.0"] = V3 冻结模型图指纹（来自 VelaSchemaV3Frozen 文件）
"""

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GOLDENS_PATH = ROOT / "scripts" / "schema_goldens.json"
FROZEN_PATH = (
    ROOT / "VelaApp" / "Persistence" / "SwiftDataModels" / "VelaSchemaV3Frozen.swift"
)

# 定义 @Model 的生产源文件（排除冻结文件本身的提取目标）
MODEL_SOURCE_FILES = [
    "VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift",
    "VelaApp/AI/Memory/MemoryModels.swift",
    "VelaApp/Scoring/Training/AdaptiveTrainingManager.swift",
]

# 类名 -> 当前存活版本（更新版本时按下标同步）
LIVE_VERSION = "4.0.0"
FROZEN_V3_VERSION = "3.0.0"

PROP_RE = re.compile(
    r"^(?:@Attribute\([^)]*\)\s+)?(?:public\s+|internal\s+)?"
    r"(var|let)\s+(\w+)\s*:\s*(.+?)\s*$"
)


def parse_models(text, file_tag):
    """返回 { className: [(prop_decl_line, ...)], ... } 保持声明顺序。"""
    models = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].strip() == "@Model":
            # 下一行应为 class 声明（允许 public/internal/final 变体）
            j = i + 1
            while j < len(lines) and lines[j].strip() == "":
                j += 1
            m = re.match(r"^(\s*)(?:public\s+|internal\s+)?final\s+class\s+(\w+)\s*\{", lines[j])
            if not m:
                m = re.match(r"^(\s*)(?:public\s+|internal\s+)?class\s+(\w+)\s*\{", lines[j])
            if not m:
                i += 1
                continue
            indent = len(m.group(1)) if m.group(1) else 0
            name = m.group(2)
            props = []
            depth = 0
            k = j
            while k < len(lines):
                line = lines[k]
                stripped = line.rstrip()
                depth += line.count("{") - line.count("}")
                if k > j:
                    stripped_body = stripped.lstrip()
                    lvl = len(stripped) - len(stripped_body)
                    if lvl == indent + 4 and depth > 0:
                        pm = PROP_RE.match(stripped_body)
                        if pm and "{" not in stripped_body:
                            props.append(stripped_body)
                if k > j and depth <= 0:
                    break
                k += 1
            models[name] = props
        i += 1
    return models


def model_fingerprint(name, props):
    canon = name + "\n" + "\n".join(props) + "\n"
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def fingerprint_set(models):
    return {name: model_fingerprint(name, props) for name, props in sorted(models.items())}


def load_production_models():
    merged = {}
    for rel in MODEL_SOURCE_FILES:
        p = ROOT / rel
        if not p.exists():
            raise SystemExit(f"missing source file: {rel}")
        text = p.read_text(encoding="utf-8")
        merged.update(parse_models(text, rel))
    return merged


def load_frozen_v3_models():
    """解析冻结文件：提取 VelaSchemaV3 枚举内嵌套的 @Model 类。"""
    text = FROZEN_PATH.read_text(encoding="utf-8")
    return parse_models(text, "frozen")


def load_goldens():
    if not GOLDENS_PATH.exists():
        return {}
    return json.loads(GOLDENS_PATH.read_text(encoding="utf-8"))


def write_goldens(goldens):
    GOLDENS_PATH.write_text(
        json.dumps(goldens, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def check():
    goldens = load_goldens()
    if not goldens:
        print("schema_goldens.json 不存在，先运行 --update", file=sys.stderr)
        return 1
    ok = True

    live = load_production_models()
    expected_live = goldens.get("live", {})
    live_fp = fingerprint_set(live)
    for name, fp in live_fp.items():
        if expected_live.get(name) != fp:
            ok = False
            print(f"[FAIL] live model {name} 的指纹与黄金快照不符")
    for name in expected_live:
        if name not in live_fp:
            ok = False
            print(f"[FAIL] live model {name} 已从模型图消失（若是删除，请更新黄金快照）")

    frozen = load_frozen_v3_models()
    expected_frozen = goldens.get("frozen_v3", {})
    frozen_fp = fingerprint_set(frozen)
    for name, fp in frozen_fp.items():
        if expected_frozen.get(name) != fp:
            ok = False
            print(f"[FAIL] frozen V3 model {name} 的指纹与黄金快照不符（冻结类不可改！）")
    for name in expected_frozen:
        if name not in frozen_fp:
            ok = False
            print(f"[FAIL] frozen V3 model {name} 缺失")

    if ok:
        print(f"schema fingerprint OK: {len(live)} live models, {len(frozen)} frozen V3 models")
        return 0
    print(
        "\n模型图发生了变化。修复流程：\n"
        f"  1. 将当前模型图冻结为新的 VelaSchemaV{n}（复制 {FROZEN_PATH} 模式）；\n"
        f"  2. 在 VelaModelContainer.swift 新增 VelaSchemaV{n+1}（live 类型）并 bump 版本；\n"
        f"  3. VelaMigrationPlan 增加对应 .lightweight stage；\n"
        f"  4. 运行 python3 scripts/schema_fingerprint.py --update 更新黄金快照。",
        file=sys.stderr,
    )
    return 1


def update():
    live = load_production_models()
    frozen = load_frozen_v3_models()
    goldens = {
        "live": fingerprint_set(live),
        "frozen_v3": fingerprint_set(frozen),
    }
    write_goldens(goldens)
    print(f"goldens updated: {len(live)} live, {len(frozen)} frozen_v3")
    return 0


def emit_frozen():
    """从生产模型生成 VelaSchemaV3 冻结文件（含自动生成的 init）。"""
    live = load_production_models()
    src = {}
    for rel in MODEL_SOURCE_FILES:
        text = (ROOT / rel).read_text(encoding="utf-8")
        src.update(parse_models(text, rel))

    lines = [
        "// AUTO-GENERATED by scripts/schema_fingerprint.py --emit-frozen",
        "// VelaSchemaV3 的冻结（frozen）模型图快照：生成时与 live 图形逐属性一致。",
        "// 规则：本文件内容禁止手工修改；模型变更时必须新建 VelaSchemaV(n+1) 后重新生成。",
        "//",
        "// 为什么需要冻结副本：SwiftData 的 VersionedSchema 一旦指向 live 类型，",
        "// 任何字段增删都会改变历史 checksum，使存量 store 报告 unknown model version。",
        "import Foundation",
        "import SwiftData",
        "",
        "/// 冻结的模型图快照（生成时与 live 图形完全一致）。",
        "/// 注意：不要把它注册进 VelaMigrationPlan——SwiftData 拒绝 checksum 相",
        "/// 同的两个 schema（Duplicate version checksums）。模型变更时：",
        "///   1) 用本文件把变更前图形升级为 VersionedSchema（见 VelaModelContainer 注释）；",
        "///   2) 新建 live 的 VelaSchemaV4 并加入计划；",
        "///   3) python3 scripts/schema_fingerprint.py --update 更新黄金快照。",
        "enum VelaSchemaV3Frozen {",
        "",
    ]
    for name in sorted(src):
        props = src[name]  # 原始声明行（含 @Attribute 前缀与可选默认值）
        lines.append("    @Model")
        lines.append(f"    final class {name} {{")
        entries = []  # (full_line, prop_name, type_part, default_part)
        for line in props:
            pm = re.match(
                r"^(?:@Attribute\([^)]*\)\s+)?(?:public\s+|internal\s+)?"
                r"(var|let)\s+(\w+)\s*:\s*(.+?)\s*$",
                line,
            )
            type_part = pm.group(3)
            # 剥离尾注释（如 `var name: String // e.g., ...`），仅用于 init 参数生成
            comment_safe = type_part.split(" // ")[0].rstrip()
            default_part = None
            eq = comment_safe.find(" = ")
            if eq >= 0:
                default_part = comment_safe[eq + 3 :]
                comment_safe = comment_safe[:eq]
            entries.append((line, pm.group(2), comment_safe.strip(), default_part))

        for line, _, _, _ in entries:
            lines.append(f"        {line}")
        lines.append("")
        lines.append(f"        init(")
        for idx, (_, name, type_part, default_part) in enumerate(entries):
            if default_part is not None:
                param = f"{name}: {type_part} = {default_part}"
            elif type_part.rstrip().endswith("?"):
                param = f"{name}: {type_part} = nil"
            else:
                param = f"{name}: {type_part}"
            suffix = "," if idx < len(entries) - 1 else ""
            lines.append(f"            {param}{suffix}")
        lines.append("        ) {")
        for _, name, _, _ in entries:
            lines.append(f"            self.{name} = {name}")
        lines.append("        }")
        lines.append("    }")
        lines.append("")
    lines.append("    static var models: [any PersistentModel.Type] {")
    lines.append("        [")
    for name in sorted(src):
        lines.append(f"            {name}.self,")
    lines.append("        ]")
    lines.append("    }")
    lines.append("}")
    FROZEN_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {FROZEN_PATH} with {len(src)} frozen classes")
    return 0


def main():
    args = sys.argv[1:]
    if "--update" in args:
        sys.exit(update())
    if "--emit-frozen" in args:
        sys.exit(emit_frozen())
    sys.exit(check())


if __name__ == "__main__":
    main()
