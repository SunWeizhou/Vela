import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { trainingPlan } from "../data/mock";
import { Sparkles, Wand2 } from "lucide-react";

const loadColor: Record<string, string> = {
  low: "#34c759",
  med: "#007aff",
  high: "#ff3b30",
  rest: "#8e8e93",
};

export function TrainingPlanPage({ onBack }: { onBack: () => void }) {
  return (
    <>
      <NavBar
        title="训练计划"
        onBack={onBack}
        backLabel="Coach"
        right={<Wand2 className="w-5 h-5" />}
      />

      <div className="px-4 pb-32 space-y-3">
        <Card padding="p-5" style={{ background: "linear-gradient(135deg,#007aff,#5856d6)", color: "white" }}>
          <div className="flex items-center gap-2 mb-1" style={{ fontSize: 13, opacity: 0.9 }}>
            <Sparkles className="w-4 h-4" />
            本周计划 · 由 Vela 生成
          </div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>第 23 周 · 强度构建</div>
          <div style={{ fontSize: 13, opacity: 0.9, marginTop: 6, lineHeight: 1.5 }}>
            目标周负荷 70 · 已完成 28 · ACWR 维持在 1.0–1.3
          </div>
        </Card>

        <div className="rounded-[14px] overflow-hidden" style={{ background: "var(--ios-bg-elevated)" }}>
          {trainingPlan.map((d, i) => (
            <div
              key={d.day}
              className="p-4 flex items-center gap-3"
              style={{ borderBottom: i < trainingPlan.length - 1 ? "0.5px solid var(--ios-separator)" : "none" }}
            >
              <div
                className="w-12 h-12 rounded-[10px] flex flex-col items-center justify-center text-white"
                style={{ background: loadColor[d.load] }}
              >
                <span style={{ fontSize: 10, opacity: 0.85 }}>{d.day}</span>
                <span style={{ fontSize: 14, fontWeight: 700 }}>{d.time === "—" ? "休息" : d.time.split(" ")[0]}</span>
              </div>
              <div className="flex-1">
                <div style={{ fontSize: 15, fontWeight: 600 }}>{d.focus}</div>
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 2 }}>
                  {d.load === "rest" ? "完全恢复" : `目标 Strain ${d.load === "low" ? "8–10" : d.load === "med" ? "11–14" : "15–18"}`}
                </div>
              </div>
            </div>
          ))}
        </div>

        <Card>
          <div style={{ fontSize: 13, color: "var(--ios-indigo)", fontWeight: 600 }}>调整建议</div>
          <div style={{ fontSize: 14, marginTop: 4, lineHeight: 1.5 }}>
            周四 HIIT 与周五下肢力量距离较近，若周四 RPE 超过 8，建议将周五力量推迟到周六。
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-3">
          <button
            className="py-3 rounded-[14px] text-white"
            style={{ background: "var(--ios-blue)", fontSize: 15, fontWeight: 600 }}
          >
            重新生成
          </button>
          <button
            className="py-3 rounded-[14px]"
            style={{ background: "var(--ios-bg-elevated)", color: "var(--ios-blue)", fontSize: 15, fontWeight: 600 }}
          >
            导出到日历
          </button>
        </div>
      </div>
    </>
  );
}
