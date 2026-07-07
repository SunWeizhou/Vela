import { useEffect, useState } from "react";
import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { wikiFiles } from "../data/mock";
import { Check, FileText, History, Sparkles, X } from "lucide-react";

const INITIAL_CONTENT: Record<string, string> = {
  "profile.md": `# 个人资料

- **姓名**：Sun Weizhou
- **年龄**：32
- **身高**：178 cm
- **体重**：71.4 kg
- **职业**：软件工程师
- **居住地**：杭州

## 简介
长期跑者 + 力量训练爱好者；偏好数据驱动的训练方式。`,
  "goals.md": `# 健康目标

## 6 月
- [ ] 跑量 100 km
- [ ] 力量训练 12 次
- [ ] 平均睡眠 ≥ 7h 30m

## 长期
- 半马 PB 进入 1:45
- 体脂保持 15% 以下
- HRV 基线提升至 70ms`,
  "habits.md": `# 习惯设置

- 咖啡因截止：**14:00**
- 工作日入睡：**23:00 前**
- 周末入睡：**00:00 前**
- 酒精：每周 ≤ 2 次，每次 ≤ 2 标准杯
- 训练时间偏好：傍晚 17:00–19:00`,
  "training_history.md": `# 训练历史

## 比赛
- 2024 杭州马拉松 3:42
- 2025 上海半马 1:48 (PB)

## 长期项目
- 跑步：5 年
- 力量训练：4 年（自重 + 杠铃）
- VO₂ Max 趋势：48 → 52`,
  "health_context.md": `# 健康背景

- 慢性病：**无**
- 旧伤：左肩盂唇 2023 年轻度撕裂，已恢复
- 药物：无
- 过敏：花粉（春季）
- 家族史：父亲高血压`,
  "baselines.md": `# 个人基线（自动生成）

> 由 Vela 根据过去 28 天滚动数据计算，每日 6:00 更新。

- HRV：**64 ms** (±MAD 7)
- RHR：**54 bpm** (±MAD 3)
- 睡眠时长：**7.4 h** (±MAD 0.5)
- 步数：**8,420 / day**
- 周训练负荷：**62**`,
};

export function WikiFilePage({ filename, onBack }: { filename: string; onBack: () => void }) {
  const file = wikiFiles.find((f) => f.name === filename) ?? wikiFiles[0];
  const [text, setText] = useState(INITIAL_CONTENT[file.name] ?? "");
  const [original, setOriginal] = useState(text);
  const [editing, setEditing] = useState(false);

  useEffect(() => {
    const t = INITIAL_CONTENT[file.name] ?? "";
    setText(t);
    setOriginal(t);
    setEditing(false);
  }, [file.name]);

  const dirty = text !== original;
  const isAuto = file.name === "baselines.md";

  return (
    <>
      <NavBar
        title={file.title}
        onBack={onBack}
        backLabel="Wiki"
        right={
          editing ? (
            <button
              onClick={() => {
                setOriginal(text);
                setEditing(false);
              }}
              style={{ color: "var(--ios-blue)", fontSize: 17, fontWeight: 600 }}
              disabled={!dirty}
            >
              保存
            </button>
          ) : isAuto ? null : (
            <button
              onClick={() => setEditing(true)}
              style={{ color: "var(--ios-blue)", fontSize: 17 }}
            >
              编辑
            </button>
          )
        }
      />

      <div className="px-4 pb-32 space-y-3">
        <Card padding="p-4">
          <div className="flex items-center gap-3">
            <div
              className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white shrink-0"
              style={{ background: "var(--ios-purple)" }}
            >
              <FileText className="w-5 h-5" />
            </div>
            <div className="flex-1 min-w-0">
              <div style={{ fontSize: 15, fontWeight: 600 }}>{file.name}</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                更新于 {file.updated} {isAuto && "· 自动维护"}
              </div>
            </div>
            {dirty && (
              <span style={{ fontSize: 12, color: "var(--ios-orange)" }}>未保存</span>
            )}
          </div>
        </Card>

        {/* editor / viewer */}
        <Card padding="p-0">
          {editing ? (
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              rows={18}
              className="w-full bg-transparent outline-none p-4 resize-none"
              style={{
                fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
                fontSize: 14,
                lineHeight: 1.6,
                color: "var(--ios-label)",
              }}
            />
          ) : (
            <div className="p-4">
              <MarkdownView text={text} />
            </div>
          )}
        </Card>

        {editing && dirty && (
          <div className="flex gap-2">
            <button
              onClick={() => {
                setText(original);
                setEditing(false);
              }}
              className="flex-1 py-3 rounded-[14px] flex items-center justify-center gap-1"
              style={{ background: "var(--ios-bg-elevated)", color: "var(--ios-red)", fontSize: 15, fontWeight: 600 }}
            >
              <X className="w-4 h-4" />
              放弃
            </button>
            <button
              onClick={() => {
                setOriginal(text);
                setEditing(false);
              }}
              className="flex-1 py-3 rounded-[14px] text-white flex items-center justify-center gap-1"
              style={{ background: "var(--ios-blue)", fontSize: 15, fontWeight: 600 }}
            >
              <Check className="w-4 h-4" />
              保存
            </button>
          </div>
        )}

        {!editing && (
          <>
            <Section header="Vela 建议">
              <Rows>
                <Row
                  icon={<Sparkles className="w-4 h-4" />}
                  iconBg="var(--ios-indigo)"
                  title="建议新增「6 月跑量 100km」"
                  subtitle="基于你今日的对话"
                  trailing={
                    <div className="flex gap-1.5">
                      <ConfirmBtn />
                      <RejectBtn />
                    </div>
                  }
                />
                <Row
                  icon={<Sparkles className="w-4 h-4" />}
                  iconBg="var(--ios-indigo)"
                  title="建议把咖啡因截止改为 13:30"
                  subtitle="过去 14 天相关性显示更早截止可获 +18m 深睡"
                  trailing={
                    <div className="flex gap-1.5">
                      <ConfirmBtn />
                      <RejectBtn />
                    </div>
                  }
                />
              </Rows>
            </Section>

            <Section header="修订历史">
              <Rows>
                <Row
                  icon={<History className="w-4 h-4" />}
                  iconBg="var(--ios-label-tertiary)"
                  title="今天 09:12 · 手动编辑"
                  subtitle="新增 2 行"
                  showChevron
                />
                <Row
                  icon={<History className="w-4 h-4" />}
                  iconBg="var(--ios-label-tertiary)"
                  title="昨天 21:30 · Vela 自动同步"
                  subtitle="基于晚间对话总结"
                  showChevron
                />
                <Row
                  icon={<History className="w-4 h-4" />}
                  iconBg="var(--ios-label-tertiary)"
                  title="6 月 2 日 · 初始化"
                  subtitle="由模板创建"
                  showChevron
                />
              </Rows>
            </Section>
          </>
        )}
      </div>
    </>
  );
}

function ConfirmBtn() {
  return (
    <button
      className="w-7 h-7 rounded-full flex items-center justify-center text-white"
      style={{ background: "var(--ios-green)" }}
    >
      <Check className="w-4 h-4" />
    </button>
  );
}
function RejectBtn() {
  return (
    <button
      className="w-7 h-7 rounded-full flex items-center justify-center"
      style={{ background: "var(--ios-fill)", color: "var(--ios-label-secondary)" }}
    >
      <X className="w-4 h-4" />
    </button>
  );
}

function MarkdownView({ text }: { text: string }) {
  // tiny markdown: headings, bullets, bold, blockquote
  const lines = text.split("\n");
  return (
    <div className="space-y-1" style={{ fontSize: 15, lineHeight: 1.6 }}>
      {lines.map((raw, i) => {
        const line = raw.trimEnd();
        if (!line) return <div key={i} style={{ height: 6 }} />;
        if (line.startsWith("# ")) return <div key={i} style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{line.slice(2)}</div>;
        if (line.startsWith("## ")) return <div key={i} style={{ fontSize: 17, fontWeight: 600, marginTop: 8, color: "var(--ios-label-secondary)" }}>{line.slice(3)}</div>;
        if (line.startsWith("> ")) return (
          <div key={i} style={{ paddingLeft: 10, borderLeft: "3px solid var(--ios-fill)", color: "var(--ios-label-secondary)", fontSize: 13 }}>
            {line.slice(2)}
          </div>
        );
        if (line.startsWith("- [ ]")) return <Bullet key={i} text={line.slice(5)} check={false} />;
        if (line.startsWith("- [x]")) return <Bullet key={i} text={line.slice(5)} check={true} />;
        if (line.startsWith("- ")) return <Bullet key={i} text={line.slice(2)} />;
        return <div key={i}>{renderInline(line)}</div>;
      })}
    </div>
  );
}

function Bullet({ text, check }: { text: string; check?: boolean }) {
  return (
    <div className="flex items-start gap-2">
      {check === undefined ? (
        <span style={{ color: "var(--ios-label-tertiary)" }}>•</span>
      ) : (
        <span
          className="mt-0.5 w-4 h-4 rounded-[4px] flex items-center justify-center"
          style={{
            background: check ? "var(--ios-blue)" : "transparent",
            border: check ? "none" : "1.5px solid var(--ios-label-tertiary)",
            color: "white",
          }}
        >
          {check && <Check className="w-3 h-3" strokeWidth={3} />}
        </span>
      )}
      <span>{renderInline(text)}</span>
    </div>
  );
}

function renderInline(text: string) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return parts.map((p, i) =>
    p.startsWith("**") && p.endsWith("**") ? (
      <strong key={i}>{p.slice(2, -2)}</strong>
    ) : (
      <span key={i}>{p}</span>
    )
  );
}
