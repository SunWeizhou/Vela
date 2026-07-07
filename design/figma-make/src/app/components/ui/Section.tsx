import { ReactNode } from "react";
import { ChevronRight } from "lucide-react";

export function Section({
  header,
  footer,
  children,
}: {
  header?: string;
  footer?: string;
  children: ReactNode;
}) {
  return (
    <div className="mb-6">
      {header && (
        <div
          className="px-5 mb-1.5"
          style={{ fontSize: 13, color: "var(--ios-label-secondary)", textTransform: "uppercase", letterSpacing: 0.3 }}
        >
          {header}
        </div>
      )}
      <div
        className="mx-4 rounded-[14px] overflow-hidden"
        style={{ background: "var(--ios-bg-elevated)" }}
      >
        {children}
      </div>
      {footer && (
        <div
          className="px-5 mt-1.5"
          style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}
        >
          {footer}
        </div>
      )}
    </div>
  );
}

interface RowProps {
  icon?: ReactNode;
  iconBg?: string;
  title: ReactNode;
  subtitle?: ReactNode;
  value?: ReactNode;
  onClick?: () => void;
  showChevron?: boolean;
  destructive?: boolean;
  trailing?: ReactNode;
}

export function Row({
  icon,
  iconBg,
  title,
  subtitle,
  value,
  onClick,
  showChevron,
  destructive,
  trailing,
}: RowProps) {
  return (
    <div
      onClick={onClick}
      className={`flex items-center gap-3 px-4 py-2.5 active:bg-[color:var(--ios-fill-tertiary)] ${onClick ? "cursor-pointer" : ""}`}
      style={{
        borderBottom: "0.5px solid var(--ios-separator)",
      }}
    >
      {icon && (
        <div
          className="w-7 h-7 rounded-[7px] flex items-center justify-center shrink-0"
          style={{ background: iconBg ?? "var(--ios-fill)", color: "white" }}
        >
          {icon}
        </div>
      )}
      <div className="flex-1 min-w-0">
        <div
          className="truncate"
          style={{
            fontSize: 17,
            color: destructive ? "var(--ios-red)" : "var(--ios-label)",
          }}
        >
          {title}
        </div>
        {subtitle && (
          <div
            className="truncate"
            style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}
          >
            {subtitle}
          </div>
        )}
      </div>
      {value && (
        <div style={{ fontSize: 17, color: "var(--ios-label-secondary)" }}>{value}</div>
      )}
      {trailing}
      {showChevron && (
        <ChevronRight className="w-4 h-4" style={{ color: "var(--ios-label-tertiary)" }} />
      )}
    </div>
  );
}

// Wrap rows to strip last divider
export function Rows({ children }: { children: ReactNode }) {
  return <div className="[&>*:last-child]:!border-b-0">{children}</div>;
}
