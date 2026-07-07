import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Heatmap } from "../components/charts/Heatmap";
import { TrendChart } from "../components/charts/TrendChart";
import { makeHeatmap, makeTrend, trainingPlan } from "../data/mock";
import { CalendarDays, ChevronRight, Dumbbell, Flame, Gauge, Plus } from "lucide-react";

const loadColor: Record<string, string> = {
  low: "#34c759",
  med: "#007aff",
  high: "#ff3b30",
  rest: "var(--ios-label-tertiary)",
};

export function FitnessPage({ go }: { go: (r: string) => void }) {
  const cells = makeHeatmap(30);
  return (
    <>
      <NavBar
        largeTitle="训练"
        subtitle="过去 30 天"
        right={<Plus className="w-6 h-6" />}
      />
      <div className="px-4 pb-32 space-y-3">
        {/* readiness */}
        <Card onClick={() => go("readiness")}>
          <div className="flex items-center gap-3">
            <div
              className="w-10 h-10 rounded-[10px] flex items-center justify-center"
              style={{ background: "var(--ios-orange)", color: "white" }}
            >
              <Gauge className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>训练 readiness</div>
              <div className="flex items-baseline gap-1">
                <span style={{ fontSize: 22, fontWeight: 700 }}>82</span>
                <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>/ 100 · 中到高强度</span>
              </div>
            </div>
            <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </div>
        </Card>

        {/* heatmap */}
        <Card>
          <div className="flex items-center justify-between mb-3">
            <div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>活动 heatmap</div>
              <div style={{ fontSize: 17, fontWeight: 600 }}>30 天负荷分布</div>
            </div>
            <div className="flex items-center gap-1" style={{ fontSize: 11, color: "var(--ios-label-secondary)" }}>
              <span>低</span>
              <div className="flex gap-0.5">
                {[0.2, 0.4, 0.6, 0.8, 1].map((i) => (
                  <div
                    key={i}
                    className="w-3 h-3 rounded"
                    style={{ background: `#007aff${Math.floor(30 + i * 220).toString(16).padStart(2,"0")}` }}
                  />
                ))}
              </div>
              <span>高</span>
            </div>
          </div>
          <Heatmap cells={cells} />
        </Card>

        {/* ACWR */}
        <Card onClick={() => go("detail:strain")}>
          <div className="flex items-center justify-between mb-2">
            <div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>Strain · 30 天</div>
              <div className="flex items-baseline gap-1">
                <span style={{ fontSize: 22, fontWeight: 700 }}>14.2</span>
                <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>avg 12.6</span>
              </div>
            </div>
            <Flame className="w-5 h-5" style={{ color: "var(--ios-orange)" }} />
          </div>
          <TrendChart data={makeTrend(7, 30, 12, 6)} color="#007aff" height={110} />
          <div className="mt-3 pt-3 flex items-center justify-between" style={{ borderTop: "0.5px solid var(--ios-separator)" }}>
            <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>急/慢负荷比 (ACWR)</span>
            <span style={{ fontSize: 15, fontWeight: 600, color: "var(--ios-green)" }}>1.12 · 适宜</span>
          </div>
        </Card>

        {/* This week plan */}
        <div className="px-1 pt-1" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          本周训练计划 · 由 Vela 生成
        </div>
        <Card padding="p-0">
          {trainingPlan.map((d, i) => (
            <div
              key={d.day}
              className="flex items-center justify-between px-4 py-3"
              style={{ borderBottom: i < trainingPlan.length - 1 ? "0.5px solid var(--ios-separator)" : "none" }}
            >
              <div className="flex items-center gap-3">
                <div
                  className="w-1 h-9 rounded-full"
                  style={{ background: loadColor[d.load] }}
                />
                <div>
                  <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>{d.day}</div>
                  <div style={{ fontSize: 15, fontWeight: 500 }}>{d.focus}</div>
                </div>
              </div>
              <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>{d.time}</span>
            </div>
          ))}
        </Card>

        {/* Strength templates */}
        <Card onClick={() => go("strength")}>
          <div className="flex items-center gap-3">
            <div
              className="w-10 h-10 rounded-[10px] flex items-center justify-center"
              style={{ background: "var(--ios-blue)", color: "white" }}
            >
              <Dumbbell className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 15, fontWeight: 600 }}>力量训练模板</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                胸 / 背 / 腿 / 肩 / 手臂 / 核心
              </div>
            </div>
            <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </div>
        </Card>

        <Card onClick={() => go("calendar")}>
          <div className="flex items-center gap-3">
            <div
              className="w-10 h-10 rounded-[10px] flex items-center justify-center"
              style={{ background: "var(--ios-pink)", color: "white" }}
            >
              <CalendarDays className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 15, fontWeight: 600 }}>训练日历</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                未来 4 周 · 已排 18 次训练
              </div>
            </div>
            <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </div>
        </Card>
      </div>
    </>
  );
}
