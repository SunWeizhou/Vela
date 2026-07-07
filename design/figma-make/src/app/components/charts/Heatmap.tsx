interface HeatmapProps {
  cells: { day: number; strain: number }[];
  color?: string;
}

export function Heatmap({ cells, color = "#007aff" }: HeatmapProps) {
  return (
    <div className="grid grid-cols-10 gap-1.5">
      {cells.map((c) => {
        const intensity = Math.min(1, c.strain / 21);
        return (
          <div
            key={c.day}
            className="aspect-square rounded-[6px]"
            style={{
              background: `${color}${Math.floor(30 + intensity * 220)
                .toString(16)
                .padStart(2, "0")}`,
            }}
            title={`Day ${c.day + 1} · Strain ${c.strain.toFixed(1)}`}
          />
        );
      })}
    </div>
  );
}
