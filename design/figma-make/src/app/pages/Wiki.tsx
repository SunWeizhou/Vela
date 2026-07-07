import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { wikiFiles } from "../data/mock";
import { BookOpen, FileText, History, Sparkles } from "lucide-react";

export function WikiPage({ onBack, go }: { onBack: () => void; go: (r: string) => void }) {
  return (
    <>
      <NavBar title="个人 Wiki" onBack={onBack} backLabel="Coach" />
      <div className="pb-32">
        <div className="px-4 mb-3">
        <Card>
          <div className="flex items-start gap-3">
            <div
              className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white shrink-0"
              style={{ background: "var(--ios-purple)" }}
            >
              <BookOpen className="w-5 h-5" />
            </div>
            <div>
              <div style={{ fontSize: 15, fontWeight: 600 }}>由你掌控的记忆</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 4, lineHeight: 1.5 }}>
                Vela 在每次对话中读取这里的 7 个 markdown 文件作为长期记忆。所有更改都需要你确认。
              </div>
            </div>
          </div>
        </Card>
        </div>

      <Section header="Wiki 文件">
        <Rows>
          {wikiFiles.map((f) => (
            <Row
              key={f.name}
              icon={<FileText className="w-4 h-4" />}
              iconBg="var(--ios-purple)"
              title={f.title}
              subtitle={`${f.desc} · 更新于 ${f.updated}`}
              showChevron
              onClick={() => go("wikifile:" + f.name)}
            />
          ))}
        </Rows>
      </Section>

      <Section header="待确认的更新" footer="Vela 提出的更改在你确认前不会写入。">
        <Rows>
          <Row
            icon={<Sparkles className="w-4 h-4" />}
            iconBg="var(--ios-indigo)"
            title="goals.md · 新增「6 月跑量 100km」"
            subtitle="基于今日对话 · 待确认"
            showChevron
            onClick={() => go("wikifile:goals.md")}
          />
          <Row
            icon={<Sparkles className="w-4 h-4" />}
            iconBg="var(--ios-indigo)"
            title="habits.md · 咖啡因截止 14:00"
            subtitle="基于过去 14 天相关性 · 待确认"
            showChevron
            onClick={() => go("wikifile:habits.md")}
          />
        </Rows>
      </Section>

      <Section header="审计日志">
        <Rows>
          <Row icon={<History className="w-4 h-4" />} iconBg="var(--ios-label-tertiary)" title="6 月 8 日 · baselines.md 自动更新" subtitle="HRV 基线 63 → 64" />
          <Row icon={<History className="w-4 h-4" />} iconBg="var(--ios-label-tertiary)" title="6 月 6 日 · training_history.md" subtitle="+ 半马 PB 1:48" />
        </Rows>
      </Section>
      </div>
    </>
  );
}
