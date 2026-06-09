import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import {
  Activity,
  BatteryMedium,
  Bot,
  Brain,
  ChevronRight,
  Dna,
  Eye,
  Flame,
  GitBranch,
  Info,
  Moon,
  Server,
  Shield,
  Sparkles,
} from "lucide-react";

export type AlgoId = "recovery" | "sleep" | "strain" | "stress" | "energy" | "bioage";

export const ALGOS: Record<
  AlgoId,
  { name: string; color: string; range: string; desc: string; factors: { label: string; weight: number; color: string }[]; formula: string; note: string }
> = {
  recovery: {
    name: "Recovery 评分",
    color: "#34c759",
    range: "0–100",
    desc: "综合 HRV、RHR、睡眠和昨日 Strain，反映身体应对今日训练的能力。",
    factors: [
      { label: "HRV vs 基线", weight: 35, color: "#34c759" },
      { label: "RHR vs 基线", weight: 25, color: "#ff3b30" },
      { label: "睡眠质量", weight: 25, color: "#5856d6" },
      { label: "昨日 Strain", weight: 15, color: "#007aff" },
    ],
    formula:
      "Recovery = 100 · σ( 0.35·z(HRV) − 0.25·z(RHR) + 0.25·z(Sleep) − 0.15·z(Strain₋₁) )",
    note: "z(·) 为相对个人 28 天基线的 MAD 标准化；σ 为 sigmoid 映射。",
  },
  sleep: {
    name: "Sleep 评分",
    color: "#5856d6",
    range: "0–100",
    desc: "由时长、规律性与中断综合得出，无线设备睡眠分期作为辅助。",
    factors: [
      { label: "时长 vs 目标", weight: 40, color: "#5856d6" },
      { label: "节律一致性", weight: 30, color: "#af52de" },
      { label: "中断惩罚", weight: 20, color: "#ff3b30" },
      { label: "深睡 / REM 比例", weight: 10, color: "#30b0c7" },
    ],
    formula:
      "Sleep = 0.4·duration_score + 0.3·consistency + 0.2·(1 − awakeness) + 0.1·stages_score",
    note: "节律一致性基于过去 13 晚入睡/起床时间的标准差。",
  },
  strain: {
    name: "Strain 评分",
    color: "#ff9500",
    range: "0–21",
    desc: "全天累计的训练 + 非训练负荷，对数压缩后映射至 0–21（参考 Banister TRIMP）。",
    factors: [
      { label: "训练心率累积", weight: 55, color: "#ff9500" },
      { label: "活动能量", weight: 20, color: "#34c759" },
      { label: "步数 / 站立", weight: 15, color: "#007aff" },
      { label: "RPE 校正", weight: 10, color: "#af52de" },
    ],
    formula: "Strain = 21 · log(1 + Σ TRIMP_i + α·kcal + β·steps) / log(1 + K)",
    note: "K 为个人最近 60 天最大值；α、β 由性别、体重个性化。",
  },
  stress: {
    name: "Stress 指数",
    color: "#af52de",
    range: "0–100",
    desc: "生理压力代理指标（非心理评估）。基于昼间 HR/HRV/呼吸/体温偏离基线的程度。",
    factors: [
      { label: "RHR 偏离", weight: 25, color: "#ff3b30" },
      { label: "HRV 偏离", weight: 25, color: "#34c759" },
      { label: "呼吸率偏离", weight: 15, color: "#30b0c7" },
      { label: "体温偏离", weight: 10, color: "#ff9500" },
      { label: "睡眠债", weight: 15, color: "#5856d6" },
      { label: "负荷压力", weight: 10, color: "#007aff" },
    ],
    formula: "Stress = 100 · σ( Σ wᵢ · |z(xᵢ)| − τ )",
    note: "在睡眠和训练时段会施加遮罩，避免被生理性升高误判为压力。",
  },
  energy: {
    name: "Energy Bank",
    color: "#34c759",
    range: "0–100%",
    desc: "「电池」隐喻：早晨由恢复 + 睡眠决定，全天按活动、压力、昼夜节律消耗。",
    factors: [
      { label: "早晨：Recovery", weight: 45, color: "#34c759" },
      { label: "早晨：Sleep", weight: 35, color: "#5856d6" },
      { label: "早晨：夜间稳定性", weight: 20, color: "#30b0c7" },
      { label: "白天：活动消耗", weight: 0, color: "#ff9500" },
      { label: "白天：压力 / 昼夜衰减", weight: 0, color: "#af52de" },
    ],
    formula:
      "E₀ = 0.45·Recovery + 0.35·Sleep + 0.20·Stability\n" +
      "Eₜ = E₀ − ∫ (drain_activity + drain_stress + drain_circadian) dt",
    note: "白天的消耗系数会随个体训练经验自适应；mindfulness/小睡可回充。",
  },
  bioage: {
    name: "生物年龄 · PhenoAge / Trend",
    color: "#30b0c7",
    range: "−10 ~ +10 岁",
    desc: "化验完整时使用 Levine PhenoAge 公式；不完整时退回基于可穿戴的 Beta 趋势模型。",
    factors: [
      { label: "白蛋白", weight: 12, color: "#34c759" },
      { label: "肌酐", weight: 12, color: "#ff9500" },
      { label: "空腹血糖", weight: 14, color: "#ff3b30" },
      { label: "CRP", weight: 14, color: "#af52de" },
      { label: "淋巴细胞%", weight: 10, color: "#30b0c7" },
      { label: "其他 (MCV, RDW, ALP, WBC, Age)", weight: 38, color: "#007aff" },
    ],
    formula:
      "xb = Σ βᵢ · biomarkerᵢ + β_age · age\n" +
      "PhenoAge = 141.50 + log(−0.00553·log(1 − M)) / 0.09165\n" +
      "M = 1 − exp( −exp(xb) · (exp(γ·t) − 1) / γ )",
    note: "Levine et al. (2018)；Vela 仅用于个人趋势监测，非诊断工具。",
  },
};

export function AlgorithmsPage({ onBack, go }: { onBack: () => void; go: (r: string) => void }) {
  return (
    <>
      <NavBar title="算法与模型" onBack={onBack} backLabel="设置" />

      <div className="px-4 pb-32 space-y-3">
        <Card>
          <div className="flex items-start gap-3">
            <div
              className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white shrink-0"
              style={{ background: "var(--ios-indigo)" }}
            >
              <Eye className="w-4 h-4" />
            </div>
            <div>
              <div style={{ fontSize: 15, fontWeight: 600 }}>透明可审计</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 4, lineHeight: 1.5 }}>
                Vela 的每一个评分背后都有可追溯的公式与权重。点击查看每个模型的因子分解、个性化基线与限制说明。
              </div>
            </div>
          </div>
        </Card>

        <div className="px-1 pt-1" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          评分模型
        </div>
        <Card padding="p-0">
          <AlgoRow id="recovery" icon={<Activity className="w-4 h-4" />} go={go} />
          <AlgoRow id="sleep" icon={<Moon className="w-4 h-4" />} go={go} />
          <AlgoRow id="strain" icon={<Flame className="w-4 h-4" />} go={go} />
          <AlgoRow id="stress" icon={<Brain className="w-4 h-4" />} go={go} />
          <AlgoRow id="energy" icon={<BatteryMedium className="w-4 h-4" />} go={go} />
          <AlgoRow id="bioage" icon={<Dna className="w-4 h-4" />} go={go} last />
        </Card>

        <Section header="LLM & Agent">
          <Rows>
            <Row icon={<Bot className="w-4 h-4" />} iconBg="var(--ios-indigo)" title="DeepSeek-Chat" subtitle="主对话 · 流式 · 工具调用" value="v3.1" showChevron />
            <Row icon={<Sparkles className="w-4 h-4" />} iconBg="#af52de" title="Claude (via Backend)" subtitle="计划生成 · 长文本审核" value="备选" showChevron />
            <Row icon={<Eye className="w-4 h-4" />} iconBg="#30b0c7" title="Kimi Vision" subtitle="食物图像识别" value="启用" showChevron />
            <Row icon={<Server className="w-4 h-4" />} iconBg="#34c759" title="本地分数引擎" subtitle="Recovery / Sleep / Strain 等" value="设备内" showChevron />
          </Rows>
        </Section>

        <Section header="Agent 调度">
          <Rows>
            <Row icon={<GitBranch className="w-4 h-4" />} iconBg="#007aff" title="Morning Brief Agent" subtitle="每日 6:00" showChevron />
            <Row icon={<GitBranch className="w-4 h-4" />} iconBg="#5856d6" title="Evening Wiki Sync Agent" subtitle="每日 21:00" showChevron />
            <Row icon={<GitBranch className="w-4 h-4" />} iconBg="#ff9500" title="Post-Workout Check-in" subtitle="训练结束 +15 min" showChevron />
            <Row icon={<GitBranch className="w-4 h-4" />} iconBg="#34c759" title="Weekly Review Agent" subtitle="周日 21:00" showChevron />
          </Rows>
        </Section>

        <Section header="数据与隐私" footer="所有原始 HealthKit 数据仅在本地处理。发送给 LLM 的仅为结构化摘要。">
          <Rows>
            <Row icon={<Shield className="w-4 h-4" />} iconBg="#34c759" title="个人基线窗口" value="28 天滚动" />
            <Row icon={<Info className="w-4 h-4" />} iconBg="var(--ios-label-tertiary)" title="模型版本" value="scoring v1.4" />
          </Rows>
        </Section>
      </div>
    </>
  );
}

function AlgoRow({
  id,
  icon,
  go,
  last,
}: {
  id: AlgoId;
  icon: React.ReactNode;
  go: (r: string) => void;
  last?: boolean;
}) {
  const a = ALGOS[id];
  return (
    <div
      onClick={() => go(`algo:${id}`)}
      className="flex items-center gap-3 px-4 py-3 cursor-pointer active:bg-[color:var(--ios-fill-tertiary)]"
      style={{ borderBottom: last ? "none" : "0.5px solid var(--ios-separator)" }}
    >
      <div
        className="w-9 h-9 rounded-[10px] flex items-center justify-center text-white shrink-0"
        style={{ background: a.color }}
      >
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <div style={{ fontSize: 15, fontWeight: 600 }}>{a.name}</div>
        <div className="truncate" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          {a.range} · {a.factors.length} 个因子
        </div>
      </div>
      <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
    </div>
  );
}

export function AlgorithmDetail({ id, onBack }: { id: AlgoId; onBack: () => void }) {
  const a = ALGOS[id];
  const total = a.factors.reduce((s, f) => s + f.weight, 0) || 1;

  return (
    <>
      <NavBar title={a.name} onBack={onBack} backLabel="算法" />

      <div className="px-4 pb-32 space-y-3">
        <Card padding="p-5">
          <div className="flex items-center gap-3 mb-3">
            <div
              className="w-11 h-11 rounded-[12px] flex items-center justify-center text-white"
              style={{ background: a.color }}
            >
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>取值范围</div>
              <div style={{ fontSize: 17, fontWeight: 600 }}>{a.range}</div>
            </div>
          </div>
          <div style={{ fontSize: 15, lineHeight: 1.55 }}>{a.desc}</div>
        </Card>

        {/* factor stacked bar */}
        <Card>
          <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginBottom: 8 }}>
            因子权重
          </div>
          <div className="flex h-2.5 rounded-full overflow-hidden mb-3">
            {a.factors.map((f, i) => (
              <div
                key={i}
                style={{
                  width: `${(f.weight / total) * 100}%`,
                  background: f.weight === 0 ? "var(--ios-fill-tertiary)" : f.color,
                }}
              />
            ))}
          </div>
          <div className="space-y-2">
            {a.factors.map((f, i) => (
              <div key={i} className="flex items-center gap-2">
                <span
                  className="w-2.5 h-2.5 rounded-full shrink-0"
                  style={{ background: f.weight === 0 ? "var(--ios-fill)" : f.color }}
                />
                <span style={{ fontSize: 14, flex: 1 }}>{f.label}</span>
                <span style={{ fontSize: 14, color: "var(--ios-label-secondary)", fontWeight: 600 }}>
                  {f.weight === 0 ? "动态" : `${f.weight}%`}
                </span>
              </div>
            ))}
          </div>
        </Card>

        <Card>
          <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginBottom: 6 }}>
            公式
          </div>
          <pre
            className="rounded-[10px] p-3 overflow-x-auto"
            style={{
              background: "var(--ios-fill-tertiary)",
              fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace",
              fontSize: 13,
              lineHeight: 1.6,
              color: "var(--ios-label)",
              whiteSpace: "pre-wrap",
            }}
          >
{a.formula}
          </pre>
        </Card>

        <Card>
          <div className="flex items-start gap-2">
            <Info className="w-4 h-4 mt-0.5 shrink-0" style={{ color: "var(--ios-label-secondary)" }} />
            <div style={{ fontSize: 13, color: "var(--ios-label-secondary)", lineHeight: 1.55 }}>
              {a.note}
            </div>
          </div>
        </Card>

        <Section header="个性化">
          <Rows>
            <Row title="基线窗口" value="28 天滚动" />
            <Row title="基线方法" value="中位数 ± MAD" />
            <Row title="数据来源" value="HealthKit · Journal" />
            <Row title="模型版本" value="v1.4 · 2026-05" />
          </Rows>
        </Section>
      </div>
    </>
  );
}
