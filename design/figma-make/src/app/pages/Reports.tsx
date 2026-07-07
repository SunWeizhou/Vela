import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { artifacts, reports } from "../data/mock";
import { CalendarRange, FileText, Sparkles, Sun, Moon } from "lucide-react";

export function ReportsPage({ onBack }: { onBack: () => void }) {
  return (
    <>
      <NavBar title="历史报告" onBack={onBack} backLabel="Coach" />

      <div className="px-4 mb-3">
        <Card padding="p-5" style={{ background: "linear-gradient(135deg,#ff9500,#ff2d55)", color: "white" }}>
          <div className="flex items-center gap-2 mb-1" style={{ fontSize: 13, opacity: 0.9 }}>
            <Sun className="w-4 h-4" />
            今日 Morning Brief · 6:00
          </div>
          <div style={{ fontSize: 22, fontWeight: 700, lineHeight: 1.25 }}>
            恢复良好，建议 60–75 分钟中等强度耐力训练。
          </div>
          <div style={{ fontSize: 13, opacity: 0.9, marginTop: 8, lineHeight: 1.5 }}>
            HRV 比基线上升 6%。深睡比例提升，但夜间醒来 2 次。注意下午控制咖啡因摄入。
          </div>
        </Card>
      </div>

      <Section header="今日">
        <Rows>
          {reports.map((r) => (
            <Row
              key={r.id}
              icon={
                r.id === "morning" ? <Sun className="w-4 h-4" /> :
                r.id === "sleep" ? <Moon className="w-4 h-4" /> :
                <CalendarRange className="w-4 h-4" />
              }
              iconBg={r.id === "morning" ? "#ff9500" : r.id === "sleep" ? "#5856d6" : "#007aff"}
              title={r.title}
              subtitle={`${r.time} · ${r.subtitle}`}
              showChevron
              onClick={() => {}}
            />
          ))}
        </Rows>
      </Section>

      <Section header="生成物">
        <Rows>
          {artifacts.map((a) => (
            <Row
              key={a.id}
              icon={<FileText className="w-4 h-4" />}
              iconBg="var(--ios-indigo)"
              title={a.title}
              subtitle={`${a.kind} · ${a.time}`}
              showChevron
              onClick={() => {}}
            />
          ))}
        </Rows>
      </Section>

      <Section header="自动报告" footer="可在「设置 · 通知」中调整时间与开关。">
        <Rows>
          <Row icon={<Sparkles className="w-4 h-4" />} iconBg="var(--ios-blue)" title="Morning Brief" subtitle="每日 6:00" trailing={<Toggle on />} />
          <Row icon={<Sparkles className="w-4 h-4" />} iconBg="var(--ios-purple)" title="睡眠回顾" subtitle="起床后" trailing={<Toggle on />} />
          <Row icon={<Sparkles className="w-4 h-4" />} iconBg="var(--ios-green)" title="周报" subtitle="周日 21:00" trailing={<Toggle on />} />
          <Row icon={<Sparkles className="w-4 h-4" />} iconBg="var(--ios-orange)" title="训练后复盘" subtitle="训练结束 15 分钟后" trailing={<Toggle />} />
        </Rows>
      </Section>
    </>
  );
}

function Toggle({ on }: { on?: boolean }) {
  return (
    <div
      className="w-12 h-7 rounded-full p-0.5 flex"
      style={{
        background: on ? "var(--ios-green)" : "var(--switch-background)",
        justifyContent: on ? "flex-end" : "flex-start",
        transition: "all 0.2s",
      }}
    >
      <div
        className="w-6 h-6 rounded-full bg-white"
        style={{ boxShadow: "0 1px 3px rgba(0,0,0,0.2)" }}
      />
    </div>
  );
}
