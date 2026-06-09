import { useEffect, useRef, useState } from "react";
import { NavBar } from "../components/ui/NavBar";
import { chatHistory, quickPrompts } from "../data/mock";
import {
  Activity,
  ArrowUp,
  AudioLines,
  Camera,
  ImageIcon,
  Plus,
  Sparkles,
} from "lucide-react";

type Msg = { role: "ai" | "me"; text: string; meta?: string };

export function CoachChat({ onBack }: { onBack: () => void }) {
  const [msgs, setMsgs] = useState<Msg[]>(chatHistory as any);
  const [input, setInput] = useState("");
  const [streaming, setStreaming] = useState(false);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [msgs, streaming]);

  function send(text?: string) {
    const t = (text ?? input).trim();
    if (!t) return;
    setInput("");
    setMsgs((m) => [...m, { role: "me", text: t }]);
    setStreaming(true);
    setTimeout(() => {
      setMsgs((m) => [
        ...m,
        {
          role: "ai",
          text:
            "我已经看过你最近 7 天的数据。" +
            "今天 HRV 68ms（基线 64），RHR 52bpm（基线 54），睡眠 7h 42m。\n\n" +
            "**结论**：状态适合中等强度训练。\n" +
            "**建议**：60 分钟 Zone 2 + 10 分钟核心。",
          meta: "已使用工具：HealthKit · 训练记录 · 个人基线",
        },
      ]);
      setStreaming(false);
    }, 900);
  }

  return (
    <div className="h-screen flex flex-col">
      <NavBar
        title="Vela Coach"
        onBack={onBack}
        backLabel="返回"
        right={
          <button>
            <Sparkles className="w-5 h-5" />
          </button>
        }
      />

      {/* messages */}
      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3" style={{ background: "var(--ios-bg)" }}>
        <div className="flex items-center justify-center mb-2">
          <div
            className="px-3 py-1 rounded-full"
            style={{
              background: "var(--ios-fill-tertiary)",
              fontSize: 12,
              color: "var(--ios-label-secondary)",
            }}
          >
            今天 · Coach 在线
          </div>
        </div>

        {msgs.map((m, i) => (
          <Bubble key={i} msg={m} />
        ))}

        {streaming && <TypingBubble />}

        <div ref={endRef} />
      </div>

      {/* quick prompts above input */}
      <div
        className="px-3 py-2 overflow-x-auto"
        style={{
          background: "var(--chrome-bg)",
          backdropFilter: "saturate(180%) blur(20px)",
          WebkitBackdropFilter: "saturate(180%) blur(20px)",
          borderTop: "0.5px solid var(--chrome-border)",
        }}
      >
        <div className="flex gap-2 whitespace-nowrap">
          {quickPrompts.map((p) => (
            <button
              key={p}
              onClick={() => send(p)}
              className="px-3 py-1.5 rounded-full active:opacity-70"
              style={{
                background: "var(--ios-fill-tertiary)",
                fontSize: 13,
                color: "var(--ios-label)",
              }}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* input bar */}
      <div
        className="px-3 pt-2"
        style={{
          paddingBottom: "max(env(safe-area-inset-bottom), 10px)",
          background: "var(--chrome-bg)",
          backdropFilter: "saturate(180%) blur(20px)",
          WebkitBackdropFilter: "saturate(180%) blur(20px)",
        }}
      >
        <div className="flex items-end gap-2">
          <button
            className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
            style={{ background: "var(--ios-fill-tertiary)", color: "var(--ios-label)" }}
          >
            <Plus className="w-5 h-5" />
          </button>
          <div
            className="flex-1 flex items-end gap-1 px-3 py-1.5 rounded-[20px]"
            style={{ background: "var(--ios-bg-elevated)", border: "0.5px solid var(--ios-separator)" }}
          >
            <textarea
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  send();
                }
              }}
              rows={1}
              placeholder="问 Vela…"
              className="flex-1 bg-transparent outline-none resize-none py-1"
              style={{ fontSize: 16, color: "var(--ios-label)", maxHeight: 120 }}
            />
            <div className="flex items-center gap-1 pb-0.5">
              <button style={{ color: "var(--ios-label-secondary)" }}>
                <Camera className="w-5 h-5" />
              </button>
              <button style={{ color: "var(--ios-label-secondary)" }}>
                <ImageIcon className="w-5 h-5" />
              </button>
            </div>
          </div>
          {input.trim() ? (
            <button
              onClick={() => send()}
              className="w-9 h-9 rounded-full flex items-center justify-center shrink-0 text-white"
              style={{ background: "var(--ios-blue)" }}
            >
              <ArrowUp className="w-5 h-5" strokeWidth={2.6} />
            </button>
          ) : (
            <button
              className="w-9 h-9 rounded-full flex items-center justify-center shrink-0"
              style={{ background: "var(--ios-fill-tertiary)", color: "var(--ios-label)" }}
            >
              <AudioLines className="w-5 h-5" />
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function Bubble({ msg }: { msg: Msg }) {
  const isMe = msg.role === "me";
  return (
    <div className={`flex ${isMe ? "justify-end" : "justify-start"} items-end gap-2`}>
      {!isMe && (
        <div
          className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
          style={{ background: "linear-gradient(135deg,#5856d6,#007aff)", color: "white" }}
        >
          <Sparkles className="w-3.5 h-3.5" />
        </div>
      )}
      <div className={`max-w-[78%] ${isMe ? "items-end" : "items-start"} flex flex-col`}>
        <div
          className="px-3.5 py-2 rounded-[20px]"
          style={{
            background: isMe ? "var(--ios-blue)" : "var(--ios-bg-elevated)",
            color: isMe ? "white" : "var(--ios-label)",
            fontSize: 16,
            lineHeight: 1.4,
            borderBottomRightRadius: isMe ? 6 : 20,
            borderBottomLeftRadius: isMe ? 20 : 6,
            whiteSpace: "pre-wrap",
            border: isMe ? "none" : "0.5px solid var(--ios-separator)",
          }}
        >
          {renderMarkdown(msg.text)}
        </div>
        {msg.meta && (
          <div
            className="flex items-center gap-1 mt-1 px-1"
            style={{ fontSize: 11, color: "var(--ios-label-tertiary)" }}
          >
            <Activity className="w-3 h-3" />
            {msg.meta}
          </div>
        )}
      </div>
    </div>
  );
}

function TypingBubble() {
  return (
    <div className="flex justify-start items-end gap-2">
      <div
        className="w-7 h-7 rounded-full flex items-center justify-center shrink-0"
        style={{ background: "linear-gradient(135deg,#5856d6,#007aff)", color: "white" }}
      >
        <Sparkles className="w-3.5 h-3.5" />
      </div>
      <div
        className="px-3.5 py-2.5 rounded-[20px] flex items-center gap-1.5"
        style={{
          background: "var(--ios-bg-elevated)",
          border: "0.5px solid var(--ios-separator)",
          borderBottomLeftRadius: 6,
        }}
      >
        {[0, 1, 2].map((i) => (
          <span
            key={i}
            className="w-2 h-2 rounded-full"
            style={{
              background: "var(--ios-label-tertiary)",
              animation: `velaBlink 1.2s ${i * 0.15}s infinite ease-in-out`,
            }}
          />
        ))}
        <style>{`@keyframes velaBlink{0%,80%,100%{opacity:.3}40%{opacity:1}}`}</style>
      </div>
    </div>
  );
}

function renderMarkdown(text: string) {
  // tiny: handle **bold** and line breaks
  const lines = text.split("\n");
  return lines.map((line, i) => {
    const parts = line.split(/(\*\*[^*]+\*\*)/g);
    return (
      <div key={i}>
        {parts.map((p, j) =>
          p.startsWith("**") && p.endsWith("**") ? (
            <strong key={j}>{p.slice(2, -2)}</strong>
          ) : (
            <span key={j}>{p}</span>
          )
        )}
      </div>
    );
  });
}
