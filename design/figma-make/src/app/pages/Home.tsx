import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { RingScore } from "../components/charts/RingScore";
import { TrendChart } from "../components/charts/TrendChart";
import { aiInsights, makeTrend, todayScores } from "../data/mock";
import {
  Activity,
  BatteryMedium,
  Brain,
  ChevronRight,
  Dna,
  Moon,
  Sparkles,
  Sun,
  TrendingUp,
} from "lucide-react";
import { ReactNode } from "react";

type Nav = (route: string) => void;

export function HomePage({ go }: { go: Nav }) {
  return (
    <>
      <NavBar
        largeTitle="今日"
        subtitle="星期二 · 6 月 9 日"
        right={
          <div
            className="w-8 h-8 rounded-full flex items-center justify-center"
            style={{ background: "var(--ios-fill)", color: "var(--ios-label)", fontSize: 13, fontWeight: 600 }}
          >
            S
          </div>
        }
      />

      <div className="px-4 pb-32 space-y-3">
        {/* Hero readiness */}
        <Card padding="p-5" onClick={() => go("detail:recovery")}>
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2" style={{ color: "var(--ios-green)" }}>
              <Activity className="w-4 h-4" />
              <span style={{ fontSize: 13, fontWeight: 600 }}>恢复</span>
            </div>
            <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </div>
          <div className="flex items-center gap-5">
            <RingScore value={todayScores.recovery} color="#34c759" size={108} />
            <div className="flex-1">
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>状态</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>良好</div>
              <div className="mt-2 space-y-0.5" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                <div>HRV 比基线 +6%</div>
                <div>睡眠贡献 +12 分</div>
                <div>昨日 Strain 影响 −4 分</div>
              </div>
            </div>
          </div>
        </Card>

        {/* 2x2 grid of secondary scores */}
        <div className="grid grid-cols-2 gap-3">
          <MiniScoreCard
            title="睡眠"
            icon={<Moon className="w-4 h-4" />}
            color="#5856d6"
            value={todayScores.sleep}
            unit="分"
            sub="7h 42m · 较目标 +12m"
            onClick={() => go("detail:sleep")}
          />
          <MiniScoreCard
            title="负荷"
            icon={<Sun className="w-4 h-4" />}
            color="#ff9500"
            value={todayScores.strain}
            unit={`/ ${todayScores.strainMax}`}
            sub="目标区间内"
            onClick={() => go("detail:strain")}
          />
          <MiniScoreCard
            title="压力"
            icon={<Brain className="w-4 h-4" />}
            color="#af52de"
            value={todayScores.stress}
            unit="低"
            sub="平和稳定"
            onClick={() => go("detail:stress")}
          />
          <MiniScoreCard
            title="能量"
            icon={<BatteryMedium className="w-4 h-4" />}
            color="#34c759"
            value={todayScores.energy}
            unit="%"
            sub="预计晚间 48%"
            onClick={() => go("detail:energy")}
          />
        </div>

        {/* Today plan */}
        <Card onClick={() => go("plan")}>
          <div className="flex items-start gap-3">
            <div
              className="w-9 h-9 rounded-[9px] flex items-center justify-center shrink-0"
              style={{ background: "var(--ios-blue)", color: "white" }}
            >
              <TrendingUp className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between">
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>今日计划</div>
                <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
              </div>
              <div style={{ fontSize: 17, fontWeight: 600, marginTop: 2 }}>Zone 2 跑步 · 60 分钟</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 2 }}>
                目标 Strain 11–13 · 18:00 前完成最佳
              </div>
            </div>
          </div>
        </Card>

        {/* Biological age trend */}
        <Card onClick={() => go("bioage")}>
          <div className="flex items-center gap-3">
            <div
              className="w-9 h-9 rounded-[9px] flex items-center justify-center shrink-0"
              style={{ background: "var(--ios-teal)", color: "white" }}
            >
              <Dna className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between">
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>生物年龄趋势 · Beta</div>
                <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
              </div>
              <div className="flex items-baseline gap-2">
                <span style={{ fontSize: 22, fontWeight: 700 }}>−2.4 岁</span>
                <span style={{ fontSize: 13, color: "var(--ios-green)" }}>持续改善</span>
              </div>
            </div>
          </div>
        </Card>

        {/* HRV preview */}
        <Card onClick={() => go("detail:hrv")}>
          <div className="flex items-center justify-between mb-1">
            <div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>HRV · 14 天</div>
              <div className="flex items-baseline gap-1">
                <span style={{ fontSize: 22, fontWeight: 700 }}>68</span>
                <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>ms · 基线 64</span>
              </div>
            </div>
            <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </div>
          <TrendChart data={makeTrend(2, 14, 64, 8)} color="#34c759" height={100} />
        </Card>

        {/* AI insights carousel */}
        {aiInsights.map((ins, i) => (
          <Card key={i} onClick={() => go("coach")}>
            <div className="flex items-start gap-3">
              <div
                className="w-9 h-9 rounded-[9px] flex items-center justify-center shrink-0"
                style={{ background: "var(--ios-indigo)", color: "white" }}
              >
                <Sparkles className="w-4 h-4" />
              </div>
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <div style={{ fontSize: 13, color: "var(--ios-indigo)", fontWeight: 600 }}>
                    Vela Coach
                  </div>
                  <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
                </div>
                <div style={{ fontSize: 17, fontWeight: 600, marginTop: 2 }}>{ins.title}</div>
                <div style={{ fontSize: 14, color: "var(--ios-label-secondary)", marginTop: 4, lineHeight: 1.5 }}>
                  {ins.body}
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </>
  );
}

function MiniScoreCard({
  title,
  icon,
  color,
  value,
  unit,
  sub,
  onClick,
}: {
  title: string;
  icon: ReactNode;
  color: string;
  value: number | string;
  unit?: string;
  sub?: string;
  onClick?: () => void;
}) {
  return (
    <Card onClick={onClick}>
      <div className="flex items-center justify-between" style={{ color }}>
        <div className="flex items-center gap-1.5">
          {icon}
          <span style={{ fontSize: 13, fontWeight: 600 }}>{title}</span>
        </div>
        <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
      </div>
      <div className="mt-2 flex items-baseline gap-1">
        <span style={{ fontSize: 28, fontWeight: 700, letterSpacing: "-0.02em" }}>{value}</span>
        {unit && <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>{unit}</span>}
      </div>
      {sub && (
        <div style={{ fontSize: 12, color: "var(--ios-label-secondary)", marginTop: 4 }}>{sub}</div>
      )}
    </Card>
  );
}
