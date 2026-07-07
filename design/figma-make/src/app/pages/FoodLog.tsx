import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Camera, Check, Sparkles } from "lucide-react";

const items = [
  { name: "鸡胸肉", g: 120, kcal: 198, p: 36, c: 0, f: 4, conf: 0.92 },
  { name: "糙米饭", g: 150, kcal: 165, p: 4, c: 35, f: 1, conf: 0.88 },
  { name: "西兰花", g: 90, kcal: 30, p: 3, c: 5, f: 0, conf: 0.95 },
  { name: "橄榄油", g: 8, kcal: 72, p: 0, c: 0, f: 8, conf: 0.7 },
];

export function FoodLogPage({ onBack }: { onBack: () => void }) {
  const total = items.reduce(
    (a, b) => ({
      kcal: a.kcal + b.kcal,
      p: a.p + b.p,
      c: a.c + b.c,
      f: a.f + b.f,
    }),
    { kcal: 0, p: 0, c: 0, f: 0 }
  );

  return (
    <>
      <NavBar
        title="食物识别"
        onBack={onBack}
        backLabel="返回"
        right={<span style={{ fontSize: 17, fontWeight: 600, color: "var(--ios-blue)" }}>保存</span>}
      />
      <div className="px-4 pb-32 space-y-3">
        {/* photo placeholder */}
        <Card padding="p-0">
          <div
            className="aspect-[16/10] flex items-center justify-center"
            style={{
              background:
                "linear-gradient(135deg, #c9d6ff 0%, #e2e2e2 100%)",
              borderRadius: "14px 14px 0 0",
            }}
          >
            <Camera className="w-10 h-10 text-white/80" />
          </div>
          <div className="p-4 flex items-center justify-between">
            <div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                Kimi Vision 已识别 4 项
              </div>
              <div style={{ fontSize: 17, fontWeight: 600, marginTop: 2 }}>
                {total.kcal} kcal · P{total.p} C{total.c} F{total.f}
              </div>
            </div>
            <div
              className="w-9 h-9 rounded-full flex items-center justify-center text-white"
              style={{ background: "var(--ios-green)" }}
            >
              <Check className="w-5 h-5" />
            </div>
          </div>
        </Card>

        {/* macro bar */}
        <Card>
          <div className="flex items-center gap-1 mb-2">
            {(["p", "c", "f"] as const).map((k, i) => {
              const v = total[k];
              const totalMacros = total.p + total.c + total.f;
              const pct = (v / totalMacros) * 100;
              const color = ["#34c759", "#ff9500", "#ff2d55"][i];
              return (
                <div
                  key={k}
                  className="h-2 rounded-full"
                  style={{ width: `${pct}%`, background: color }}
                />
              );
            })}
          </div>
          <div className="flex justify-between" style={{ fontSize: 12, color: "var(--ios-label-secondary)" }}>
            <span>蛋白 {total.p}g</span>
            <span>碳水 {total.c}g</span>
            <span>脂肪 {total.f}g</span>
          </div>
        </Card>

        {/* items */}
        <div className="rounded-[14px] overflow-hidden" style={{ background: "var(--ios-bg-elevated)" }}>
          {items.map((it, i) => (
            <div
              key={i}
              className="px-4 py-3 flex items-center justify-between"
              style={{ borderBottom: i < items.length - 1 ? "0.5px solid var(--ios-separator)" : "none" }}
            >
              <div>
                <div style={{ fontSize: 15, fontWeight: 600 }}>{it.name}</div>
                <div style={{ fontSize: 12, color: "var(--ios-label-secondary)" }}>
                  {it.g}g · P{it.p} C{it.c} F{it.f} · 可信度 {Math.round(it.conf * 100)}%
                </div>
              </div>
              <div style={{ fontSize: 17, fontWeight: 600 }}>{it.kcal} kcal</div>
            </div>
          ))}
        </div>

        <Card>
          <div className="flex items-start gap-2">
            <Sparkles className="w-4 h-4 mt-0.5" style={{ color: "var(--ios-indigo)" }} />
            <div style={{ fontSize: 14, lineHeight: 1.5 }}>
              这餐蛋白质充足、碳水适中。结合今天的训练计划，可以再补充 30g 复合碳水以支持恢复。
            </div>
          </div>
        </Card>
      </div>
    </>
  );
}
