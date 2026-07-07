import { ReactNode } from "react";
import { ChevronLeft } from "lucide-react";

interface NavBarProps {
  title?: string;
  onBack?: () => void;
  backLabel?: string;
  right?: ReactNode;
  largeTitle?: string;
  subtitle?: string;
}

export function NavBar({ title, onBack, backLabel, right, largeTitle, subtitle }: NavBarProps) {
  return (
    <>
      <div
        className="sticky top-0 z-30"
        style={{
          background: "var(--chrome-bg)",
          backdropFilter: "saturate(180%) blur(20px)",
          WebkitBackdropFilter: "saturate(180%) blur(20px)",
          borderBottom: title ? "0.5px solid var(--chrome-border)" : "none",
        }}
      >
        <div className="h-11 flex items-center justify-between px-2 relative">
          <div className="min-w-[64px] flex items-center">
            {onBack && (
              <button
                onClick={onBack}
                className="flex items-center -ml-1 active:opacity-60"
                style={{ color: "var(--tint)" }}
              >
                <ChevronLeft className="w-6 h-6" strokeWidth={2.4} />
                {backLabel && (
                  <span style={{ fontSize: 17, marginLeft: -4 }}>{backLabel}</span>
                )}
              </button>
            )}
          </div>
          {title && (
            <div
              className="absolute left-1/2 -translate-x-1/2"
              style={{ fontSize: 17, fontWeight: 600 }}
            >
              {title}
            </div>
          )}
          <div className="min-w-[64px] flex items-center justify-end gap-3" style={{ color: "var(--tint)" }}>
            {right}
          </div>
        </div>
      </div>
      {largeTitle && (
        <div className="px-5 pt-1 pb-3">
          {subtitle && (
            <div
              className="mb-0.5"
              style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}
            >
              {subtitle}
            </div>
          )}
          <h1>{largeTitle}</h1>
        </div>
      )}
    </>
  );
}
