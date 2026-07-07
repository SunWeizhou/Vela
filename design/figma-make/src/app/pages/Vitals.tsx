import { NavBar } from "../components/ui/NavBar";
import { Section, Row, Rows } from "../components/ui/Section";
import { biomarkers, vitals } from "../data/mock";
import {
  Activity,
  Droplets,
  FlaskConical,
  Gauge,
  Heart,
  Moon,
  Scale,
  Thermometer,
  Wind,
} from "lucide-react";

const iconMap: Record<string, any> = {
  Activity, Heart, Moon, Wind, Droplets, Thermometer, Scale, Gauge,
};

export function VitalsPage({ go }: { go: (r: string) => void }) {
  return (
    <>
      <NavBar largeTitle="体征" subtitle="健康数据" />

      <div className="pb-32">
        <Section header="心脏与活动">
          <Rows>
            {vitals.slice(0, 4).map((v) => {
              const Icon = iconMap[v.icon] ?? Activity;
              return (
                <Row
                  key={v.id}
                  icon={<Icon className="w-4 h-4" />}
                  iconBg={v.color}
                  title={v.name}
                  subtitle={v.trend}
                  value={
                    <span style={{ color: "var(--ios-label)", fontWeight: 600 }}>
                      {v.value} <span style={{ color: "var(--ios-label-secondary)", fontWeight: 400 }}>{v.unit}</span>
                    </span>
                  }
                  onClick={() => go(`detail:${v.id}`)}
                  showChevron
                />
              );
            })}
          </Rows>
        </Section>

        <Section header="身体">
          <Rows>
            {vitals.slice(4).map((v) => {
              const Icon = iconMap[v.icon] ?? Activity;
              return (
                <Row
                  key={v.id}
                  icon={<Icon className="w-4 h-4" />}
                  iconBg={v.color}
                  title={v.name}
                  subtitle={v.trend}
                  value={
                    <span style={{ color: "var(--ios-label)", fontWeight: 600 }}>
                      {v.value} <span style={{ color: "var(--ios-label-secondary)", fontWeight: 400 }}>{v.unit}</span>
                    </span>
                  }
                  onClick={() => go(`detail:${v.id}`)}
                  showChevron
                />
              );
            })}
          </Rows>
        </Section>

        <Section header="生物标志物" footer="点击「添加」录入新的化验结果，Vela 会自动重算生物年龄。">
          <Rows>
            {biomarkers.map((b) => (
              <Row
                key={b.id}
                icon={<FlaskConical className="w-4 h-4" />}
                iconBg="var(--ios-teal)"
                title={b.name}
                subtitle={b.date}
                value={
                  <span style={{ color: "var(--ios-label)", fontWeight: 600 }}>
                    {b.value} <span style={{ color: "var(--ios-label-secondary)", fontWeight: 400 }}>{b.unit}</span>
                  </span>
                }
                onClick={() => go("biomarker")}
                showChevron
              />
            ))}
            <Row
              icon={<span style={{ fontSize: 16, fontWeight: 600 }}>+</span>}
              iconBg="var(--ios-blue)"
              title="添加生物标志物"
              onClick={() => go("biomarker")}
              showChevron
            />
          </Rows>
        </Section>
      </div>
    </>
  );
}
