import { ChartNoAxesCombined, Gauge, ListChecks, MessageCircle } from "lucide-react";

export type TabKey = "today" | "trends" | "plan" | "coach";

interface TabBarProps {
  active: TabKey;
  onChange: (k: TabKey) => void;
}

const items: { key: TabKey; label: string; Icon: any }[] = [
  { key: "today", label: "Today", Icon: Gauge },
  { key: "trends", label: "趋势", Icon: ChartNoAxesCombined },
  { key: "plan", label: "计划", Icon: ListChecks },
  { key: "coach", label: "Coach", Icon: MessageCircle },
];

export function TabBar({ active, onChange }: TabBarProps) {
  return (
    <div
      className="fixed bottom-0 inset-x-0 z-40"
      style={{
        background: "var(--chrome-bg)",
        backdropFilter: "saturate(180%) blur(30px)",
        WebkitBackdropFilter: "saturate(180%) blur(30px)",
        borderTop: "0.5px solid var(--chrome-border)",
        paddingBottom: "max(env(safe-area-inset-bottom), 6px)",
      }}
    >
      <div className="mx-auto max-w-[480px] flex items-stretch justify-between px-1 pt-1">
        {items.map(({ key, label, Icon }) => {
          const isActive = active === key;
          return (
            <button
              key={key}
              onClick={() => onChange(key)}
              className="prototype-pressable flex-1 flex flex-col items-center justify-center gap-0.5 py-1.5"
              style={{
                color: isActive ? "var(--tint)" : "var(--ios-label-secondary)",
              }}
            >
              <Icon className="w-6 h-6" strokeWidth={isActive ? 2.4 : 1.8} />
              <span style={{ fontSize: 10, fontWeight: isActive ? 600 : 500 }}>{label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
