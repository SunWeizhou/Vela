import { useState } from "react";
import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { TrendChart } from "../components/charts/TrendChart";
import { RingScore } from "../components/charts/RingScore";
import { makeTrend, vitals } from "../data/mock";
import { Sparkles } from "lucide-react";

const SCORE_META: Record<string, { name: string; color: string; value: number; max?: number; unit: string; isScore: boolean }> = {
  recovery: { name: "恢复", color: "#34c759", value: 78, unit: "%", isScore: true },
  sleep:    { name: "睡眠", color: "#5856d6", value: 86, unit: "分", isScore: true },
  strain:   { name: "负荷", color: "#ff9500", value: 14, max: 21, unit: "/ 21", isScore: true },
  stress:   { name: "压力", color: "#af52de", value: 32, unit: "低", isScore: true },
  energy:   { name: "能量", color: "#34c759", value: 72, unit: "%", isScore: true },
};

export function MetricDetail({ id, onBack, openChat }: { id: string; onBack: () => void; openChat: () => void }) {
  const isScore = !!SCORE_META[id];
  const score = SCORE_META[id];
  const vital = !isScore ? vitals.find((x) => x.id === id) ?? vitals[0] : null;

  const name = isScore ? score.name : vital!.name;
  const color = isScore ? score.color : vital!.color;
  const value = isScore ? score.value : vital!.value;
  const unit = isScore ? score.unit : vital!.unit;

  const [range, setRange] = useState<"7" | "30">("7");
  const data = makeTrend(name.length + 3, range === "7" ? 7 : 30, 55, 14);

  return (
    <>
      <NavBar title={name} onBack={onBack} backLabel="返回" />

      <div className="px-4 pb-32 space-y-3">
        {/* hero */}
        <Card padding="p-5">
          <div className="flex items-center gap-5">
            {isScore ? (
              <RingScore value={value as number} max={score.max ?? 100} color={color} size={110} />
            ) : (
              <div>
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>当前</div>
                <div className="flex items-baseline gap-1.5">
                  <span style={{ fontSize: 52, fontWeight: 700, color }}>{value}</span>
                  <span style={{ fontSize: 15, color: "var(--ios-label-secondary)" }}>{unit}</span>
                </div>
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>{vital?.trend}</div>
              </div>
            )}
            {isScore && (
              <div>
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>状态</div>
                <div style={{ fontSize: 20, fontWeight: 700 }}>
                  {value >= 70 ? "良好" : value >= 40 ? "中等" : "偏低"}
                </div>
                <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 4 }}>
                  比 7 天均值 +4%
                </div>
              </div>
            )}
          </div>
        </Card>

        {/* range switch */}
        <Card>
          <div className="flex items-center justify-between mb-3">
            <div style={{ fontSize: 15, fontWeight: 600 }}>趋势</div>
            <div
              className="inline-flex rounded-[8px] p-0.5"
              style={{ background: "var(--ios-fill-tertiary)" }}
            >
              {(["7", "30"] as const).map((r) => (
                <button
                  key={r}
                  onClick={() => setRange(r)}
                  className="px-3 py-1 rounded-[6px]"
                  style={{
                    background: range === r ? "var(--ios-bg-elevated)" : "transparent",
                    fontSize: 13,
                    fontWeight: range === r ? 600 : 500,
                    color: "var(--ios-label)",
                  }}
                >
                  {r} 天
                </button>
              ))}
            </div>
          </div>
          <TrendChart data={data} color={color} height={180} showAxis />
        </Card>

        {/* stats grid */}
        <div className="grid grid-cols-3 gap-2">
          {[
            { k: "基线", v: "64" },
            { k: "本周均值", v: "67" },
            { k: "变化", v: "+4%" },
          ].map((s) => (
            <Card key={s.k} padding="p-3">
              <div style={{ fontSize: 12, color: "var(--ios-label-secondary)" }}>{s.k}</div>
              <div style={{ fontSize: 17, fontWeight: 600, marginTop: 2 }}>{s.v}</div>
            </Card>
          ))}
        </div>

        {/* driver breakdown for scores */}
        {isScore && (
          <Section header="驱动因素">
            <Rows>
              <Row title="HRV" value="+12 分" />
              <Row title="睡眠" value="+8 分" />
              <Row title="昨日 Strain" value="−4 分" />
              <Row title="呼吸率 / 体温" value="−1 分" />
            </Rows>
          </Section>
        )}

        {/* AI insight */}
        <Card onClick={openChat}>
          <div className="flex items-start gap-3">
            <div
              className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white shrink-0"
              style={{ background: "var(--ios-indigo)" }}
            >
              <Sparkles className="w-4 h-4" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 13, color: "var(--ios-indigo)", fontWeight: 600 }}>
                Vela 分析
              </div>
              <div style={{ fontSize: 15, marginTop: 2, lineHeight: 1.5 }}>
                你的 {name} 高于 7 天基线，反映出训练负荷的良好适应。继续维持当前睡眠时间和水分摄入。
              </div>
              <button
                className="mt-3 px-3 py-1.5 rounded-full text-white"
                style={{ background: "var(--ios-blue)", fontSize: 13, fontWeight: 600 }}
              >
                与 Vela 详谈 →
              </button>
            </div>
          </div>
        </Card>
      </div>
    </>
  );
}
