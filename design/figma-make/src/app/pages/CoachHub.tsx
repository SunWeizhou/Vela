import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { artifacts, personalities, quickPrompts, reports } from "../data/mock";
import {
  BarChart3,
  BookOpen,
  CalendarRange,
  ChevronRight,
  FileText,
  Flag,
  MessageCircle,
  Settings,
  Shield,
  Sparkles,
  UtensilsCrossed,
  Wand2,
} from "lucide-react";
import { ReactNode } from "react";

const persIcon: Record<string, any> = { BarChart3, Shield, MessageCircle, Flag };

export function CoachHub({ go }: { go: (r: string) => void }) {
  return (
    <>
      <NavBar
        largeTitle="Coach"
        subtitle="Vela Intelligence"
        right={
          <button onClick={() => go("settings")}>
            <Settings className="w-6 h-6" />
          </button>
        }
      />

      <div className="px-4 pb-32 space-y-4">
        {/* Big chat entry */}
        <Card
          padding="p-5"
          onClick={() => go("chat")}
          style={{
            background: "linear-gradient(135deg, #5856d6 0%, #007aff 100%)",
            color: "white",
          }}
        >
          <div className="flex items-start gap-3">
            <div
              className="w-11 h-11 rounded-full flex items-center justify-center shrink-0"
              style={{ background: "rgba(255,255,255,0.2)" }}
            >
              <Sparkles className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 13, opacity: 0.85 }}>开始对话</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 2 }}>
                问 Vela 任何事情
              </div>
              <div style={{ fontSize: 13, opacity: 0.85, marginTop: 4 }}>
                已读取今日体征 · 流式回复 · 支持工具调用
              </div>
            </div>
            <ChevronRight className="w-5 h-5 opacity-80" />
          </div>
        </Card>

        {/* Quick prompts */}
        <div>
          <div className="px-1 mb-2" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
            快捷提问
          </div>
          <div className="flex flex-wrap gap-2">
            {quickPrompts.map((p) => (
              <button
                key={p}
                onClick={() => go("chat")}
                className="px-3.5 py-2 rounded-full active:opacity-70"
                style={{
                  background: "var(--ios-bg-elevated)",
                  fontSize: 13,
                  color: "var(--ios-label)",
                  border: "0.5px solid var(--ios-separator)",
                }}
              >
                {p}
              </button>
            ))}
          </div>
        </div>

        {/* Action hub grid */}
        <div className="grid grid-cols-2 gap-3">
          <ActionTile
            color="#007aff"
            icon={<CalendarRange />}
            title="生成训练计划"
            desc="基于恢复与目标"
            onClick={() => go("plan")}
          />
          <ActionTile
            color="#34c759"
            icon={<UtensilsCrossed />}
            title="食物拍照"
            desc="自动识别热量"
            onClick={() => go("food")}
          />
          <ActionTile
            color="#af52de"
            icon={<BookOpen />}
            title="个人 Wiki"
            desc="记忆与目标"
            onClick={() => go("wiki")}
          />
          <ActionTile
            color="#ff9500"
            icon={<FileText />}
            title="历史报告"
            desc="每日 / 每周"
            onClick={() => go("reports")}
          />
        </div>

        {/* Personality */}
        <Section header="教练人格">
          <Rows>
            {personalities.map((p, i) => {
              const Icon = persIcon[p.icon] ?? Wand2;
              return (
                <Row
                  key={p.id}
                  icon={<Icon className="w-4 h-4" />}
                  iconBg={
                    ["#34c759", "#5856d6", "#ff9500", "#ff3b30"][i % 4]
                  }
                  title={p.name}
                  subtitle={p.desc}
                  trailing={
                    i === 0 ? (
                      <span style={{ color: "var(--ios-blue)", fontSize: 13 }}>当前</span>
                    ) : null
                  }
                  showChevron
                  onClick={() => {}}
                />
              );
            })}
          </Rows>
        </Section>

        {/* Recent artifacts */}
        <Section header="最近生成">
          <Rows>
            {artifacts.map((a) => (
              <Row
                key={a.id}
                icon={<FileText className="w-4 h-4" />}
                iconBg="var(--ios-indigo)"
                title={a.title}
                subtitle={`${a.kind} · ${a.time}`}
                showChevron
                onClick={() => go("reports")}
              />
            ))}
          </Rows>
        </Section>

        {/* Today reports preview */}
        <Section header="今日报告">
          <Rows>
            {reports.map((r) => (
              <Row
                key={r.id}
                icon={<Sparkles className="w-4 h-4" />}
                iconBg="var(--ios-blue)"
                title={r.title}
                subtitle={`${r.time} · ${r.subtitle}`}
                showChevron
                onClick={() => go("reports")}
              />
            ))}
          </Rows>
        </Section>
      </div>
    </>
  );
}

function ActionTile({
  color,
  icon,
  title,
  desc,
  onClick,
}: {
  color: string;
  icon: ReactNode;
  title: string;
  desc: string;
  onClick?: () => void;
}) {
  return (
    <Card onClick={onClick} padding="p-4">
      <div
        className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white"
        style={{ background: color }}
      >
        {icon}
      </div>
      <div style={{ fontSize: 15, fontWeight: 600, marginTop: 10 }}>{title}</div>
      <div style={{ fontSize: 12, color: "var(--ios-label-secondary)", marginTop: 2 }}>
        {desc}
      </div>
    </Card>
  );
}
