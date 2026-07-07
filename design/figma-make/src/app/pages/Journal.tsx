import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { habits, journalEntries } from "../data/mock";
import {
  BookOpen,
  Camera,
  Coffee,
  Dumbbell,
  Droplets,
  Mic,
  Moon,
  Pencil,
  Plus,
  Smile,
  ThermometerSnowflake,
  UtensilsCrossed,
  Wine,
} from "lucide-react";

const iconMap: Record<string, any> = {
  Moon, UtensilsCrossed, Coffee, Dumbbell, Pencil, Wine, Smile, Droplets, ThermometerSnowflake,
};

const days = ["三", "四", "五", "六", "日", "一", "二"];
const dates = [3, 4, 5, 6, 7, 8, 9];

export function JournalPage({ go }: { go: (r: string) => void }) {
  return (
    <>
      <NavBar
        largeTitle="日志"
        subtitle="今日 · 6 月 9 日"
        right={<Plus className="w-6 h-6" />}
      />

      {/* Date strip */}
      <div className="px-4 mb-3">
        <Card padding="px-2 py-2">
          <div className="flex items-center justify-between">
            {days.map((d, i) => {
              const active = i === 6;
              return (
                <button
                  key={i}
                  className="flex flex-col items-center w-9 py-1.5 rounded-[10px]"
                  style={{
                    background: active ? "var(--ios-blue)" : "transparent",
                    color: active ? "white" : "var(--ios-label)",
                  }}
                >
                  <span style={{ fontSize: 11, opacity: 0.7 }}>{d}</span>
                  <span style={{ fontSize: 17, fontWeight: 600, marginTop: 1 }}>{dates[i]}</span>
                </button>
              );
            })}
          </div>
        </Card>
      </div>

      <div className="px-4 pb-32 space-y-3">
        {/* Habit quick-log */}
        <div className="px-1" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          快速记录
        </div>
        <Card padding="p-3">
          <div className="grid grid-cols-4 gap-2">
            {habits.map((h) => {
              const Icon = iconMap[h.icon] ?? Pencil;
              return (
                <button
                  key={h.id}
                  className="flex flex-col items-center gap-1 py-2 rounded-[12px]"
                  style={{
                    background: h.on ? "var(--ios-blue)" : "var(--ios-fill-tertiary)",
                    color: h.on ? "white" : "var(--ios-label)",
                  }}
                >
                  <Icon className="w-5 h-5" />
                  <span style={{ fontSize: 11 }}>{h.label}</span>
                </button>
              );
            })}
          </div>
        </Card>

        {/* Capture row */}
        <div className="grid grid-cols-3 gap-2">
          <CaptureBtn icon={<Camera />} label="拍餐" color="#34c759" onClick={() => go("food")} />
          <CaptureBtn icon={<Mic />} label="语音" color="#ff9500" />
          <CaptureBtn icon={<Pencil />} label="笔记" color="#5856d6" />
        </div>

        {/* Notes */}
        <Card>
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              <BookOpen className="w-4 h-4" style={{ color: "var(--ios-blue)" }} />
              <span style={{ fontSize: 13, fontWeight: 600, color: "var(--ios-label-secondary)" }}>
                自由记录
              </span>
            </div>
            <span style={{ fontSize: 13, color: "var(--ios-blue)" }}>AI 总结</span>
          </div>
          <textarea
            className="w-full bg-transparent outline-none resize-none"
            rows={2}
            placeholder="今天感觉怎么样？"
            style={{ fontSize: 15, color: "var(--ios-label)" }}
          />
        </Card>

        {/* Timeline */}
        <div className="px-1 pt-2" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          今日时间线
        </div>
        <div className="rounded-[14px] overflow-hidden" style={{ background: "var(--ios-bg-elevated)" }}>
          {journalEntries.map((e, i) => {
            const Icon = iconMap[e.icon] ?? Pencil;
            return (
              <div
                key={i}
                className="flex items-center gap-3 px-4 py-3"
                style={{ borderBottom: i < journalEntries.length - 1 ? "0.5px solid var(--ios-separator)" : "none" }}
              >
                <div
                  className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
                  style={{ background: e.color, color: "white" }}
                >
                  <Icon className="w-4 h-4" />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <div style={{ fontSize: 15, fontWeight: 600 }}>{e.title}</div>
                    <div style={{ fontSize: 13, color: "var(--ios-label-tertiary)" }}>{e.time}</div>
                  </div>
                  <div className="truncate" style={{ fontSize: 13, color: "var(--ios-label-secondary)", marginTop: 2 }}>
                    {e.detail}
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* AI correlation */}
        <Card>
          <div style={{ fontSize: 13, color: "var(--ios-indigo)", fontWeight: 600 }}>相关性发现</div>
          <div style={{ fontSize: 15, marginTop: 4 }}>
            过去 14 天里，下午 16:00 后摄入咖啡因的夜晚，平均深睡减少 22 分钟。
          </div>
        </Card>
      </div>
    </>
  );
}

function CaptureBtn({ icon, label, color, onClick }: any) {
  return (
    <button
      onClick={onClick}
      className="flex flex-col items-center justify-center py-3 rounded-[14px] active:opacity-70"
      style={{ background: "var(--ios-bg-elevated)" }}
    >
      <div
        className="w-9 h-9 rounded-full flex items-center justify-center text-white mb-1"
        style={{ background: color }}
      >
        {icon}
      </div>
      <span style={{ fontSize: 12 }}>{label}</span>
    </button>
  );
}
