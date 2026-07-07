interface RingScoreProps {
  value: number;
  max?: number;
  size?: number;
  stroke?: number;
  color: string;
  label?: string;
  unit?: string;
}

export function RingScore({
  value,
  max = 100,
  size = 110,
  stroke = 9,
  color,
  label,
  unit,
}: RingScoreProps) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const pct = Math.min(1, Math.max(0, value / max));
  const dash = c * pct;

  return (
    <div className="flex flex-col items-center justify-center" style={{ width: size }}>
      <div className="relative" style={{ width: size, height: size }}>
        <svg width={size} height={size} className="-rotate-90">
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke="var(--ios-fill-tertiary)"
            strokeWidth={stroke}
          />
          <circle
            cx={size / 2}
            cy={size / 2}
            r={r}
            fill="none"
            stroke={color}
            strokeWidth={stroke}
            strokeLinecap="round"
            strokeDasharray={`${dash} ${c - dash}`}
            style={{ transition: "stroke-dasharray 0.8s ease" }}
          />
        </svg>
        <div className="absolute inset-0 flex flex-col items-center justify-center">
          <div style={{ fontSize: size * 0.28, fontWeight: 700, lineHeight: 1, letterSpacing: "-0.02em" }}>
            {value}
          </div>
          {unit && (
            <div style={{ fontSize: 11, color: "var(--ios-label-secondary)", marginTop: 2 }}>
              {unit}
            </div>
          )}
        </div>
      </div>
      {label && (
        <div className="mt-2" style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
          {label}
        </div>
      )}
    </div>
  );
}
