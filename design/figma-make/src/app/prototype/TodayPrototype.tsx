// Chosen score-led Today direction. Exercise five data scenarios via
// ?state=stable|recovery-low|load-high|partial|mismatch.
import { useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  Check,
  ChevronRight,
  CircleHelp,
  Moon,
  Pencil,
  Sparkles,
  SunMedium,
  Trash2,
  X,
} from "lucide-react";

type Nav = (route: string) => void;
type DemoStateKey = "stable" | "recovery-low" | "load-high" | "partial" | "mismatch";
type ScoreKey = "recovery" | "sleep" | "strain" | "stress" | "energy";
type Feeling = "match" | "worse" | "better" | "unsure";

interface ScoreDatum {
  key: ScoreKey;
  label: string;
  value: number | null;
  color: string;
  deviation?: "high" | "low";
}

interface DemoState {
  scores: Record<ScoreKey, number | null>;
  deviations: Partial<Record<ScoreKey, "high" | "low">>;
  sentence: string;
  planTitle: string;
  planTime: string;
  support: string[];
  defaultFeeling?: Feeling;
}

const scoreMeta: Record<ScoreKey, { label: string; color: string }> = {
  recovery: { label: "恢复", color: "#28B463" },
  sleep: { label: "睡眠", color: "#6C63E6" },
  strain: { label: "负荷", color: "#F59D20" },
  stress: { label: "压力", color: "#EF5B78" },
  energy: { label: "能量", color: "#20A7A0" },
};

const demoStates: Record<DemoStateKey, DemoState> = {
  stable: {
    scores: { recovery: 86, sleep: 82, strain: 44, stress: 29, energy: 78 },
    deviations: {},
    sentence: "身体状态与近期节律一致，今天可以照常安排。",
    planTitle: "保持原计划",
    planTime: "18:30 · 胸部力量训练",
    support: ["训练后轻松走 20 分钟", "23:30 前准备睡眠"],
  },
  "recovery-low": {
    scores: { recovery: 38, sleep: 57, strain: 68, stress: 64, energy: 42 },
    deviations: { recovery: "low", sleep: "low", stress: "high", energy: "low" },
    sentence: "今天更适合把恢复放在前面，训练可以留一点余地。",
    planTitle: "给身体留出恢复空间",
    planTime: "18:30 · 轻量活动 30 分钟",
    support: ["训练容量控制在平时六成", "23:00 前结束高刺激活动"],
  },
  "load-high": {
    scores: { recovery: 61, sleep: 76, strain: 88, stress: 79, energy: 54 },
    deviations: { strain: "high", stress: "high" },
    sentence: "近期负荷和压力都偏高，今天不用再把强度推上去。",
    planTitle: "让负荷回落一天",
    planTime: "17:30 · 低强度步行 40 分钟",
    support: ["取消额外冲刺训练", "晚间留出 20 分钟安静过渡"],
  },
  partial: {
    scores: { recovery: null, sleep: 74, strain: 33, stress: null, energy: 61 },
    deviations: {},
    sentence: "现有数据没有明显偏离；恢复与压力会在同步后补全。",
    planTitle: "先保留原计划",
    planTime: "等待晨间数据补全",
    support: ["按当前感受决定训练强度", "手表同步后再检查一次"],
    defaultFeeling: "unsure",
  },
  mismatch: {
    scores: { recovery: 84, sleep: 87, strain: 42, stress: 26, energy: 80 },
    deviations: {},
    sentence: "数据看起来稳定，但你的感受更差；先相信身体，再一起找原因。",
    planTitle: "按真实感受放慢一点",
    planTime: "今天 · 计划暂时降一档",
    support: ["保留取消训练的空间", "下午重新确认身体感受"],
    defaultFeeling: "worse",
  },
};

const stateOrder: DemoStateKey[] = ["stable", "recovery-low", "load-high", "partial", "mismatch"];
const stateLabels: Record<DemoStateKey, string> = {
  stable: "稳定",
  "recovery-low": "恢复低",
  "load-high": "负荷高",
  partial: "缺数据",
  mismatch: "感受不一致",
};

export function TodayPrototypePage({ go }: { go: Nav }) {
  const [demoState, setDemoState] = useQueryChoice<DemoStateKey>("state", stateOrder, "stable");
  const state = demoStates[demoState];
  const scores = useMemo(
    () =>
      (Object.keys(scoreMeta) as ScoreKey[]).map((key) => ({
        key,
        ...scoreMeta[key],
        value: state.scores[key],
        deviation: state.deviations[key],
      })),
    [state],
  );

  return (
    <>
      <TodayHeader />
      <main className="px-4 pb-52">
        <BalancedDashboard key={demoState} scores={scores} state={state} go={go} />
      </main>
      <PrototypeStateSwitcher state={demoState} setState={setDemoState} />
    </>
  );
}

function TodayHeader() {
  const [isDark, setIsDark] = useState(() => document.documentElement.classList.contains("dark"));

  const toggleAppearance = () => {
    const next = !document.documentElement.classList.contains("dark");
    document.documentElement.classList.toggle("dark", next);
    setIsDark(next);
  };

  return (
    <header className="px-5 pt-3 pb-5 flex items-end justify-between">
      <div>
        <p className="text-[13px] tracking-[0.01em]" style={{ color: "var(--ios-label-secondary)" }}>
          8 月 23 日 · 数据更新于 08:42
        </p>
        <h1 className="mt-1 text-[32px] leading-none tracking-[-0.035em]">今天</h1>
      </div>
      <div className="flex items-center gap-2">
        <button
          aria-label={isDark ? "切换到浅色模式" : "切换到深色模式"}
          className="prototype-pressable size-9 rounded-full grid place-items-center"
          style={{ background: "var(--ios-fill-tertiary)" }}
          onClick={toggleAppearance}
        >
          {isDark ? <SunMedium className="size-[18px]" /> : <Moon className="size-[18px]" />}
        </button>
        <button
          aria-label="打开个人资料与数据设置"
          className="prototype-pressable size-9 rounded-full grid place-items-center text-[13px] font-semibold"
          style={{ background: "var(--ios-label)", color: "var(--ios-bg)" }}
        >
          S
        </button>
      </div>
    </header>
  );
}

function BalancedDashboard({ scores, state, go }: SurfaceProps) {
  return (
    <div className="space-y-4 prototype-enter">
      <section
        aria-label="主要身体分数"
        className="rounded-[28px] px-2 py-5"
        style={{ background: "var(--ios-bg-elevated)" }}
      >
        <div className="grid grid-cols-3 gap-0">
          {scores.slice(0, 3).map((score) => (
            <ScoreRing key={score.key} score={score} size={104} stroke={9} onClick={() => go(`detail:${score.key}`)} />
          ))}
        </div>
      </section>
      <StressEnergyPanel scores={scores} go={go} />
      <SharedTodayContent state={state} go={go} />
    </div>
  );
}

function StressEnergyPanel({ scores, go }: { scores: ScoreDatum[]; go: Nav }) {
  const stress = scores.find((score) => score.key === "stress")!;
  const energy = scores.find((score) => score.key === "energy")!;
  const energyWidth = energy.value === null ? 0 : Math.max(7, Math.min(100, energy.value));
  const stressPoints = stress.value === null
    ? "0,24 18,24 36,24 54,24 72,24 90,24 108,24"
    : stress.value > 60
      ? "0,32 18,25 36,29 54,13 72,20 90,7 108,15"
      : "0,18 18,23 36,15 54,26 72,20 90,28 108,21";

  return (
    <section aria-label="压力与能量" className="rounded-[24px] px-4 py-4" style={{ background: "var(--ios-bg-elevated)" }}>
      <h2 className="mb-3 text-[15px] font-semibold">压力与能量</h2>
      <div className="grid grid-cols-2 divide-x" style={{ borderColor: "var(--ios-separator)" }}>
        <button
          className="prototype-pressable pr-4 text-left"
          aria-label={`压力 ${stress.value ?? "数据缺失"}${stress.deviation ? "，偏离个人基线" : ""}`}
          onClick={() => go("detail:stress")}
        >
          <span className="flex items-center gap-1.5 text-[12px] font-semibold">
            <span style={{ color: stress.color }}>⌁</span> 压力
            {stress.deviation && <DeviationDot direction={stress.deviation} />}
            <ChevronRight className="ml-auto size-3.5" style={{ color: "var(--ios-label-tertiary)" }} />
          </span>
          <span className="mt-1 block text-[30px] font-bold tracking-[-0.04em] tabular-nums">{stress.value ?? "--"}</span>
          <svg viewBox="0 0 108 38" className="mt-1 h-8 w-full" aria-hidden="true">
            <path d={`M ${stressPoints}`} fill="none" stroke={stress.value === null ? "var(--ios-label-tertiary)" : stress.color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" strokeDasharray={stress.value === null ? "3 5" : undefined} />
          </svg>
        </button>

        <button
          className="prototype-pressable pl-4 text-left"
          aria-label={`能量 ${energy.value ?? "数据缺失"}${energy.deviation ? "，偏离个人基线" : ""}`}
          onClick={() => go("detail:energy")}
        >
          <span className="flex items-center gap-1.5 text-[12px] font-semibold">
            <span style={{ color: energy.color }}>ϟ</span> 能量
            {energy.deviation && <DeviationDot direction={energy.deviation} />}
            <ChevronRight className="ml-auto size-3.5" style={{ color: "var(--ios-label-tertiary)" }} />
          </span>
          <span className="mt-1 block text-[30px] font-bold tracking-[-0.04em] tabular-nums">
            {energy.value ?? "--"}{energy.value !== null && <span className="ml-0.5 text-[12px]">%</span>}
          </span>
          <span className="mt-3 flex items-center gap-1" aria-hidden="true">
            <span className="relative block h-6 flex-1 overflow-hidden rounded-[8px]" style={{ background: "var(--ios-fill-tertiary)" }}>
              {energy.value === null ? (
                <span className="absolute inset-0 rounded-[8px] border border-dashed" style={{ borderColor: "var(--ios-label-tertiary)" }} />
              ) : (
                <span className="absolute inset-y-0 left-0 rounded-[8px]" style={{ width: `${energyWidth}%`, background: energy.color }} />
              )}
            </span>
            <span className="block h-3 w-[3px] rounded-full" style={{ background: "var(--ios-label-tertiary)" }} />
          </span>
        </button>
      </div>
    </section>
  );
}

interface SurfaceProps {
  scores: ScoreDatum[];
  state: DemoState;
  go: Nav;
}

function SharedTodayContent({ state, go }: { state: DemoState; go: Nav }) {
  const [feeling, setFeeling] = useState<Feeling | undefined>(state.defaultFeeling);
  const [editingPlan, setEditingPlan] = useState(false);
  const [planTitle, setPlanTitle] = useState(state.planTitle);
  const [planTime, setPlanTime] = useState(state.planTime);

  return (
    <div className="space-y-4">
      <button
        className="prototype-pressable w-full text-left flex items-start gap-3 rounded-[24px] p-4"
        style={{ background: "var(--ios-bg-elevated)" }}
        onClick={() => go("coach")}
      >
        <Sparkles className="size-[18px] mt-0.5 shrink-0" style={{ color: "var(--accent)" }} />
        <span className="text-[16px] leading-[1.45] font-medium">{state.sentence}</span>
        <ChevronRight className="size-4 mt-1 ml-auto shrink-0" style={{ color: "var(--ios-label-tertiary)" }} />
      </button>

      <section aria-label="身体感受校准">
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-[15px] font-semibold">和你的感受一致吗？</h2>
          <button aria-label="了解身体感受校准" className="prototype-pressable" style={{ color: "var(--ios-label-tertiary)" }}>
            <CircleHelp className="size-[17px]" />
          </button>
        </div>
        <div className="grid grid-cols-4 gap-2">
          {([
            ["match", "一致"],
            ["worse", "更差"],
            ["better", "更好"],
            ["unsure", "不确定"],
          ] as [Feeling, string][]).map(([key, label]) => {
            const selected = feeling === key;
            return (
              <button
                key={key}
                className="prototype-pressable h-9 rounded-full text-[12px] font-semibold"
                style={{
                  background: selected ? "var(--ios-label)" : "var(--ios-fill-tertiary)",
                  color: selected ? "var(--ios-bg)" : "var(--ios-label)",
                }}
                onClick={() => setFeeling(selected ? undefined : key)}
              >
                {selected && <Check className="inline size-3.5 mr-1 -mt-0.5" />}
                {label}
              </button>
            );
          })}
        </div>
        {feeling && (
          <button
            className="prototype-pressable mt-2 text-[13px] font-semibold"
            style={{ color: "var(--accent)" }}
            onClick={() => go("chat")}
          >
            补充细节或继续追问
          </button>
        )}
      </section>

      <section
        className="rounded-[26px] p-5"
        style={{ background: "var(--ios-bg-elevated)", borderColor: "var(--ios-separator)" }}
      >
        <div className="flex items-center justify-between">
          <span className="text-[13px] font-semibold" style={{ color: "var(--ios-label-secondary)" }}>今日计划</span>
          <button
            className="prototype-pressable flex items-center gap-1 text-[13px] font-semibold"
            style={{ color: "var(--accent)" }}
            onClick={() => setEditingPlan(true)}
          >
            <Pencil className="size-3.5" /> 调整
          </button>
        </div>
        <button className="prototype-pressable w-full text-left mt-3" onClick={() => go("plan")}>
          <span className="flex items-center justify-between">
            <span className="text-[19px] font-bold tracking-[-0.02em]">{planTitle}</span>
            <ChevronRight className="size-4" style={{ color: "var(--ios-label-tertiary)" }} />
          </span>
          <span className="mt-1 block text-[14px]" style={{ color: "var(--ios-label-secondary)" }}>{planTime}</span>
          <span className="mt-4 block space-y-2">
            {state.support.map((item) => (
              <span key={item} className="flex items-center gap-2 text-[14px]">
                <span className="size-1.5 rounded-full" style={{ background: "var(--accent)" }} />
                {item}
              </span>
            ))}
          </span>
        </button>
      </section>

      {editingPlan && (
        <PlanEditor
          title={planTitle}
          time={planTime}
          onClose={() => setEditingPlan(false)}
          onSave={(title, time) => {
            setPlanTitle(title);
            setPlanTime(time);
            setEditingPlan(false);
          }}
          onDelete={() => {
            setPlanTitle("今天不安排固定行动");
            setPlanTime("你可以随时重新添加");
            setEditingPlan(false);
          }}
        />
      )}
    </div>
  );
}

function ScoreRing({ score, size, stroke, compact = false, onClick }: {
  score: ScoreDatum;
  size: number;
  stroke: number;
  compact?: boolean;
  onClick?: () => void;
}) {
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const progress = score.value === null ? 0 : Math.max(0, Math.min(100, score.value)) / 100;
  const direction = score.key === "strain" ? "负荷量" : score.key === "stress" ? "越高越需关注" : "越高通常越有利";

  const ring = (
    <>
      <span className="relative block" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90" aria-hidden="true">
          <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="var(--ios-fill-tertiary)" strokeWidth={stroke} />
          <circle
            className="prototype-score-arc"
            cx={size / 2}
            cy={size / 2}
            r={radius}
            fill="none"
            stroke={score.value === null ? "var(--ios-label-tertiary)" : score.color}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={score.value === null ? "2 7" : circumference}
            strokeDashoffset={circumference * (1 - progress)}
          />
        </svg>
        <span className="absolute inset-0 grid place-items-center">
          <span className={`font-bold tracking-[-0.045em] tabular-nums ${compact ? "text-[19px]" : size >= 100 ? "text-[27px]" : "text-[24px]"}`}>
            {score.value ?? "--"}
          </span>
        </span>
        {score.deviation && (
          <span className="absolute right-[3px] top-[8px]">
            <DeviationDot direction={score.deviation} />
          </span>
        )}
      </span>
      {!compact && <span className="mt-2 text-[13px] font-semibold">{score.label}</span>}
    </>
  );

  const accessibilityLabel = `${score.label} ${score.value ?? "数据缺失"}，${direction}${score.deviation ? "，偏离个人基线" : ""}`;
  if (onClick) {
    return (
      <button
        type="button"
        className="prototype-pressable mx-auto flex flex-col items-center justify-center"
        onClick={onClick}
        aria-label={accessibilityLabel}
      >
        {ring}
      </button>
    );
  }

  return (
    <span className="mx-auto flex flex-col items-center justify-center" aria-label={accessibilityLabel}>
      {ring}
    </span>
  );
}

function DeviationDot({ direction }: { direction: "high" | "low" }) {
  return (
    <span
      role="img"
      aria-label={direction === "high" ? "高于个人基线" : "低于个人基线"}
      className="inline-block size-2.5 rounded-full"
      style={{ background: "#FF9F0A", boxShadow: "0 0 0 2px var(--ios-bg-elevated)" }}
    />
  );
}

function PlanEditor({ title, time, onSave, onDelete, onClose }: {
  title: string;
  time: string;
  onSave: (title: string, time: string) => void;
  onDelete: () => void;
  onClose: () => void;
}) {
  const [draftTitle, setDraftTitle] = useState(title);
  const [draftTime, setDraftTime] = useState(time);
  return (
    <div className="fixed inset-0 z-[80] flex items-end justify-center" role="dialog" aria-modal="true" aria-label="调整今日计划">
      <button className="absolute inset-0 bg-black/30" aria-label="关闭计划编辑" onClick={onClose} />
      <div
        className="prototype-sheet relative w-full max-w-[480px] rounded-t-[30px] p-5 pb-8"
        style={{ background: "var(--ios-bg-elevated)", boxShadow: "0 -18px 60px rgba(0,0,0,.18)" }}
      >
        <div className="flex items-center justify-between mb-5">
          <button className="prototype-pressable size-8 grid place-items-center rounded-full" style={{ background: "var(--ios-fill-tertiary)" }} onClick={onClose}>
            <X className="size-4" />
          </button>
          <h2 className="text-[17px] font-semibold">调整今日计划</h2>
          <button className="prototype-pressable text-[15px] font-semibold" style={{ color: "var(--accent)" }} onClick={() => onSave(draftTitle, draftTime)}>
            完成
          </button>
        </div>
        <label className="block text-[13px] font-semibold mb-2" style={{ color: "var(--ios-label-secondary)" }}>主要行动</label>
        <input
          value={draftTitle}
          onChange={(event) => setDraftTitle(event.target.value)}
          className="w-full h-12 rounded-[14px] px-4 outline-none"
          style={{ background: "var(--ios-fill-tertiary)" }}
        />
        <label className="block text-[13px] font-semibold mt-4 mb-2" style={{ color: "var(--ios-label-secondary)" }}>时间与安排</label>
        <input
          value={draftTime}
          onChange={(event) => setDraftTime(event.target.value)}
          className="w-full h-12 rounded-[14px] px-4 outline-none"
          style={{ background: "var(--ios-fill-tertiary)" }}
        />
        <div className="grid grid-cols-2 gap-3 mt-4">
          <button
            className="prototype-pressable h-11 rounded-[14px] flex items-center justify-center gap-2 text-[14px] font-semibold"
            style={{ background: "var(--ios-fill-tertiary)" }}
            onClick={() => setDraftTime("19:30 · 已改到今晚")}
          >
            <CalendarClock className="size-4" /> 改到今晚
          </button>
          <button
            className="prototype-pressable h-11 rounded-[14px] flex items-center justify-center gap-2 text-[14px] font-semibold"
            style={{ background: "rgba(255,59,48,.1)", color: "var(--ios-red)" }}
            onClick={onDelete}
          >
            <Trash2 className="size-4" /> 删除行动
          </button>
        </div>
      </div>
    </div>
  );
}

function PrototypeStateSwitcher({ state, setState }: {
  state: DemoStateKey;
  setState: (value: DemoStateKey) => void;
}) {
  if (!import.meta.env.DEV) return null;
  return (
    <aside
      className="fixed z-[60] left-1/2 -translate-x-1/2 bottom-[78px] w-[min(448px,calc(100%-24px))] rounded-[22px] px-3 py-2.5"
      style={{
        background: "var(--prototype-chrome)",
        backdropFilter: "blur(24px) saturate(180%)",
        WebkitBackdropFilter: "blur(24px) saturate(180%)",
        boxShadow: "0 10px 36px rgba(0,0,0,.18)",
        border: "0.5px solid var(--chrome-border)",
      }}
      aria-label="原型数据状态切换器"
    >
      <div className="flex gap-1 overflow-x-auto no-scrollbar">
        {stateOrder.map((key) => (
          <button
            key={key}
            className="prototype-pressable shrink-0 h-7 px-2.5 rounded-full text-[11px] font-semibold"
            style={{
              background: key === state ? "var(--ios-label)" : "var(--ios-fill-tertiary)",
              color: key === state ? "var(--ios-bg)" : "var(--ios-label-secondary)",
            }}
            onClick={() => setState(key)}
          >
            {stateLabels[key]}
          </button>
        ))}
      </div>
    </aside>
  );
}

function useQueryChoice<T extends string>(key: string, choices: readonly T[], fallback: T) {
  const read = () => {
    const value = new URLSearchParams(window.location.search).get(key);
    return choices.includes(value as T) ? (value as T) : fallback;
  };
  const [choice, setChoice] = useState<T>(read);

  useEffect(() => {
    const onPopState = () => setChoice(read());
    window.addEventListener("popstate", onPopState);
    return () => window.removeEventListener("popstate", onPopState);
  }, []);

  const update = (value: T) => {
    const url = new URL(window.location.href);
    url.searchParams.set(key, value);
    window.history.replaceState({}, "", url);
    setChoice(value);
  };
  return [choice, update] as const;
}
