import { Home, BookOpen, Dumbbell, HeartPulse, Sparkles } from "lucide-react";

export type TabKey = "home" | "journal" | "fitness" | "vitals" | "coach";

interface TabBarProps {
  active: TabKey;
  onChange: (k: TabKey) => void;
}

const items: { key: TabKey; label: string; Icon: any }[] = [
  { key: "home", label: "总览", Icon: Home },
  { key: "journal", label: "日志", Icon: BookOpen },
  { key: "coach", label: "Coach", Icon: Sparkles },
  { key: "fitness", label: "训练", Icon: Dumbbell },
  { key: "vitals", label: "体征", Icon: HeartPulse },
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
              className="flex-1 flex flex-col items-center justify-center gap-0.5 py-1.5 active:opacity-60"
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
