import { NavBar } from "../components/ui/NavBar";
import { Section, Row, Rows } from "../components/ui/Section";
import {
  Bell,
  Bot,
  Database,
  Download,
  FlaskConical,
  Globe,
  Heart,
  GitBranch,
  Info,
  KeyRound,
  Languages,
  Moon,
  Palette,
  Shield,
  User,
} from "lucide-react";

export function SettingsPage({ onBack, go }: { onBack: () => void; go: (r: string) => void }) {
  return (
    <>
      <NavBar title="设置" onBack={onBack} backLabel="Coach" />

      <div className="pt-2 pb-32">
        {/* Profile header */}
        <div className="mx-4 mb-6 rounded-[14px] overflow-hidden" style={{ background: "var(--ios-bg-elevated)" }}>
          <div className="flex items-center gap-3 p-4">
            <div
              className="w-14 h-14 rounded-full flex items-center justify-center text-white"
              style={{ background: "linear-gradient(135deg,#5856d6,#007aff)", fontSize: 22, fontWeight: 600 }}
            >
              S
            </div>
            <div className="flex-1">
              <div style={{ fontSize: 18, fontWeight: 600 }}>Sun Weizhou</div>
              <div style={{ fontSize: 13, color: "var(--ios-label-secondary)" }}>
                Apple ID · iCloud · 媒体与购买
              </div>
            </div>
          </div>
        </div>

        <Section header="AI 模型">
          <Rows>
            <Row icon={<Bot className="w-4 h-4" />} iconBg="#5856d6" title="模型提供方" value="DeepSeek" showChevron onClick={() => {}} />
            <Row icon={<KeyRound className="w-4 h-4" />} iconBg="#ff9500" title="API Key" value="已连接" showChevron onClick={() => {}} />
            <Row icon={<Palette className="w-4 h-4" />} iconBg="#af52de" title="教练人格" value="数据派" showChevron onClick={() => {}} />
            <Row icon={<GitBranch className="w-4 h-4" />} iconBg="#30b0c7" title="算法与模型" subtitle="评分公式 · LLM · Agent 调度" showChevron onClick={() => go("algorithms")} />
          </Rows>
        </Section>

        <Section header="生物数据">
          <Rows>
            <Row icon={<User className="w-4 h-4" />} iconBg="#007aff" title="生理信息" subtitle="32 岁 · 178cm · 71kg" showChevron onClick={() => {}} />
            <Row icon={<FlaskConical className="w-4 h-4" />} iconBg="#30b0c7" title="生物标志物" subtitle="9 项已录入" showChevron onClick={() => go("biomarker")} />
          </Rows>
        </Section>

        <Section header="数据" footer="所有数据保留在你的设备上。结构化摘要会发送给 LLM，原始 HealthKit 数据永不上传。">
          <Rows>
            <Row icon={<Heart className="w-4 h-4" />} iconBg="#ff3b30" title="HealthKit 权限" subtitle="12/14 类型已授权" showChevron onClick={() => {}} />
            <Row icon={<Database className="w-4 h-4" />} iconBg="#34c759" title="数据保留" value="90 天" showChevron onClick={() => {}} />
            <Row icon={<Download className="w-4 h-4" />} iconBg="#5856d6" title="导出数据" subtitle="JSON" showChevron onClick={() => {}} />
          </Rows>
        </Section>

        <Section header="通知">
          <Rows>
            <Row icon={<Bell className="w-4 h-4" />} iconBg="#ff9500" title="Morning Brief" value="6:00" showChevron onClick={() => {}} />
            <Row icon={<Moon className="w-4 h-4" />} iconBg="#5856d6" title="入睡提醒" value="22:30" showChevron onClick={() => {}} />
            <Row icon={<Heart className="w-4 h-4" />} iconBg="#ff3b30" title="异常体征警报" value="开启" showChevron onClick={() => {}} />
          </Rows>
        </Section>

        <Section header="外观">
          <Rows>
            <Row icon={<Palette className="w-4 h-4" />} iconBg="#000" title="主题" value="跟随系统" showChevron onClick={() => {}} />
            <Row icon={<Languages className="w-4 h-4" />} iconBg="#34c759" title="语言" value="简体中文" showChevron onClick={() => {}} />
          </Rows>
        </Section>

        <Section header="隐私 & 关于">
          <Rows>
            <Row icon={<Shield className="w-4 h-4" />} iconBg="#34c759" title="Trust Center" subtitle="数据流转与权限" showChevron onClick={() => {}} />
            <Row icon={<Globe className="w-4 h-4" />} iconBg="#007aff" title="服务条款" showChevron onClick={() => {}} />
            <Row icon={<Info className="w-4 h-4" />} iconBg="var(--ios-label-tertiary)" title="版本" value="4.0.1 (build 312)" />
          </Rows>
        </Section>
      </div>
    </>
  );
}
