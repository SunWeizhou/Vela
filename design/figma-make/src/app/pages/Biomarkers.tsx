import { NavBar } from "../components/ui/NavBar";
import { Card } from "../components/ui/Card";
import { Section, Row, Rows } from "../components/ui/Section";
import { biomarkers } from "../data/mock";
import { Dna, FlaskConical, Plus } from "lucide-react";

export function BiomarkerPage({ onBack }: { onBack: () => void }) {
  return (
    <>
      <NavBar title="生物标志物" onBack={onBack} backLabel="返回" right={<Plus className="w-6 h-6" />} />
      <div className="px-4 mb-3">
        <Card>
          <div className="flex items-center gap-3">
            <div
              className="w-10 h-10 rounded-[10px] flex items-center justify-center text-white"
              style={{ background: "var(--ios-teal)" }}
            >
              <Dna className="w-5 h-5" />
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                PhenoAge · Levine 公式
              </div>
              <div className="flex items-baseline gap-2">
                <span style={{ fontSize: 24, fontWeight: 700 }}>29.6</span>
                <span style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>实际 32 岁 · −2.4</span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <Section header="化验结果" footer="非诊断性，仅供个人健康管理参考。建议结合医生意见。">
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
              showChevron
              onClick={() => {}}
            />
          ))}
        </Rows>
      </Section>

      <Section header="录入方式">
        <Rows>
          <Row icon={<Plus className="w-4 h-4" />} iconBg="var(--ios-blue)" title="手动添加" showChevron onClick={() => {}} />
          <Row icon={<FlaskConical className="w-4 h-4" />} iconBg="var(--ios-green)" title="上传体检报告 PDF" showChevron onClick={() => {}} />
        </Rows>
      </Section>
    </>
  );
}
