import { Area, AreaChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

interface TrendChartProps {
  data: { day: string; value: number }[];
  color: string;
  height?: number;
  showAxis?: boolean;
}

export function TrendChart({ data, color, height = 120, showAxis = false }: TrendChartProps) {
  const id = `grad-${color.replace("#", "")}`;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 4, right: 4, bottom: 0, left: 0 }}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.35} />
            <stop offset="100%" stopColor={color} stopOpacity={0} />
          </linearGradient>
        </defs>
        {showAxis && (
          <>
            <XAxis dataKey="day" tick={{ fill: "var(--ios-label-tertiary)", fontSize: 10 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: "var(--ios-label-tertiary)", fontSize: 10 }} axisLine={false} tickLine={false} width={26} />
          </>
        )}
        <Tooltip
          contentStyle={{
            background: "var(--ios-bg-elevated)",
            border: "0.5px solid var(--ios-separator)",
            borderRadius: 10,
            color: "var(--ios-label)",
            fontSize: 12,
            boxShadow: "0 4px 16px rgba(0,0,0,0.08)",
          }}
          labelStyle={{ color: "var(--ios-label-secondary)" }}
        />
        <Area type="monotone" dataKey="value" stroke={color} strokeWidth={2} fill={`url(#${id})`} />
      </AreaChart>
    </ResponsiveContainer>
  );
}
