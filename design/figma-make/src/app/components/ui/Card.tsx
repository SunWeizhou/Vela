import { CSSProperties, ReactNode } from "react";

export function Card({
  children,
  className = "",
  style,
  onClick,
  padding = "p-4",
}: {
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
  onClick?: () => void;
  padding?: string;
}) {
  return (
    <div
      onClick={onClick}
      className={`rounded-[14px] ${padding} ${onClick ? "active:opacity-80 cursor-pointer" : ""} ${className}`}
      style={{
        background: "var(--ios-bg-elevated)",
        ...style,
      }}
    >
      {children}
    </div>
  );
}
