export const todayScores = {
  recovery: 78,
  strain: 14.2,
  strainMax: 21,
  sleep: 86,
  stress: 32,
  energy: 72,
};

export const heroMetrics = [
  { id: "hrv", label: "HRV", value: 68, unit: "ms", delta: "+4", up: true, color: "#34c759" },
  { id: "rhr", label: "静息心率", value: 52, unit: "bpm", delta: "-2", up: true, color: "#ff3b30" },
  { id: "sleep", label: "睡眠", value: "7h 42m", unit: "", delta: "+18m", up: true, color: "#5856d6" },
  { id: "resp", label: "呼吸率", value: 14.2, unit: "rpm", delta: "+0.3", up: false, color: "#30b0c7" },
];

export const aiInsights = [
  {
    title: "今天适合中等强度训练",
    body: "你的恢复评分良好，HRV 上升 6%。建议进行 60–75 分钟的耐力训练，强度控制在 Zone 2–3。",
  },
  {
    title: "睡眠债务下降",
    body: "过去 7 天累计补足了 1h 23m，深睡比例稳步回升。继续保持 23:00 前入睡。",
  },
];

export function makeTrend(seed = 1, n = 30, base = 60, amp = 18) {
  const arr: { day: string; value: number }[] = [];
  let v = base;
  for (let i = 0; i < n; i++) {
    v = base + Math.sin((i + seed) * 0.6) * amp * 0.6 + Math.cos(i * 0.3 + seed) * amp * 0.4;
    arr.push({ day: `${i + 1}`, value: Math.round(v + ((seed * 7 + i * 13) % 5)) });
  }
  return arr;
}

export function makeHeatmap(days = 30) {
  return Array.from({ length: days }, (_, i) => ({
    day: i,
    strain: Math.max(0, Math.min(21, 8 + Math.sin(i * 0.5) * 6 + ((i * 17) % 8))),
  }));
}

export const vitals = [
  { id: "hrv", name: "HRV", value: 68, unit: "ms", color: "#34c759", trend: "+4 vs 7d", icon: "Activity" },
  { id: "rhr", name: "静息心率", value: 52, unit: "bpm", color: "#ff3b30", trend: "-2 vs 7d", icon: "Heart" },
  { id: "sleep-hr", name: "睡眠心率", value: 48, unit: "bpm", color: "#5856d6", trend: "稳定", icon: "Moon" },
  { id: "resp", name: "呼吸率", value: 14.2, unit: "rpm", color: "#30b0c7", trend: "+0.3", icon: "Wind" },
  { id: "spo2", name: "血氧", value: 98, unit: "%", color: "#34c759", trend: "正常", icon: "Droplets" },
  { id: "temp", name: "皮肤温度", value: 0.2, unit: "°C", color: "#ff9500", trend: "+0.1", icon: "Thermometer" },
  { id: "weight", name: "体重", value: 71.4, unit: "kg", color: "#ff2d55", trend: "-0.3", icon: "Scale" },
  { id: "vo2", name: "VO₂ Max", value: 52, unit: "ml/kg/min", color: "#5ac8fa", trend: "+1", icon: "Gauge" },
];

export const biomarkers = [
  { id: "albumin", name: "白蛋白", value: 4.6, unit: "g/dL", date: "2026-05-12" },
  { id: "creatinine", name: "肌酐", value: 0.9, unit: "mg/dL", date: "2026-05-12" },
  { id: "glucose", name: "空腹血糖", value: 92, unit: "mg/dL", date: "2026-05-12" },
  { id: "crp", name: "CRP", value: 0.4, unit: "mg/L", date: "2026-05-12" },
  { id: "lymph", name: "淋巴细胞%", value: 32, unit: "%", date: "2026-05-12" },
  { id: "wbc", name: "白细胞计数", value: 5.8, unit: "10⁹/L", date: "2026-05-12" },
];

export const journalEntries = [
  { time: "06:42", kind: "睡眠", title: "夜间睡眠 7h 42m", detail: "深睡 1h 25m · REM 1h 51m · 平均心率 48 bpm", color: "#5856d6", icon: "Moon" },
  { time: "08:15", kind: "营养", title: "早餐 · 燕麦碗", detail: "约 480 kcal · 蛋白质 22g · 碳水 64g", color: "#34c759", icon: "UtensilsCrossed" },
  { time: "10:00", kind: "习惯", title: "咖啡因 · 一杯美式", detail: "120 mg 咖啡因 · 早", color: "#a2845e", icon: "Coffee" },
  { time: "12:30", kind: "训练", title: "力量 · 上肢推", detail: "55 分钟 · 平均心率 122 · Strain 8.4", color: "#007aff", icon: "Dumbbell" },
  { time: "15:00", kind: "备注", title: "状态良好", detail: "训练后精神不错，下午专注度高。", color: "#ff9500", icon: "Pencil" },
  { time: "20:10", kind: "营养", title: "晚餐 · 鸡胸沙拉", detail: "约 540 kcal · 蛋白质 38g", color: "#34c759", icon: "UtensilsCrossed" },
];

export const habits = [
  { id: "coffee", label: "咖啡", icon: "Coffee", on: true },
  { id: "alcohol", label: "酒精", icon: "Wine", on: false },
  { id: "lateMeal", label: "晚餐过晚", icon: "Moon", on: false },
  { id: "mood", label: "心情好", icon: "Smile", on: true },
  { id: "hydration", label: "饮水充足", icon: "Droplets", on: true },
  { id: "exercise", label: "已运动", icon: "Dumbbell", on: true },
  { id: "sick", label: "身体不适", icon: "ThermometerSnowflake", on: false },
];

export const trainingPlan = [
  { day: "周一", focus: "Zone 2 跑步", time: "45 min", load: "low" },
  { day: "周二", focus: "上肢力量", time: "60 min", load: "med" },
  { day: "周三", focus: "恢复 + 拉伸", time: "30 min", load: "low" },
  { day: "周四", focus: "间歇 HIIT", time: "40 min", load: "high" },
  { day: "周五", focus: "下肢力量", time: "70 min", load: "high" },
  { day: "周六", focus: "长距离有氧", time: "90 min", load: "med" },
  { day: "周日", focus: "完全休息", time: "—", load: "rest" },
];

export const reports = [
  { id: "morning", title: "今日 Morning Brief", time: "6:00", subtitle: "恢复良好，建议中等强度耐力训练" },
  { id: "sleep", title: "睡眠回顾", time: "07:10", subtitle: "深睡比例上升 8%，节律稳定" },
  { id: "weekly", title: "上周总结", time: "周日 21:00", subtitle: "训练量 +12%，HRV 趋势上升" },
];

export const wikiFiles = [
  { name: "profile.md", title: "个人资料", desc: "姓名、年龄、目标概述", updated: "今天 09:12" },
  { name: "goals.md", title: "健康目标", desc: "6 月：跑步 100km、力量 12 次", updated: "昨天" },
  { name: "habits.md", title: "习惯设置", desc: "咖啡因、酒精、睡眠窗口", updated: "3 天前" },
  { name: "training_history.md", title: "训练历史", desc: "马拉松 2 次 · 自重训练 5 年", updated: "1 周前" },
  { name: "health_context.md", title: "健康背景", desc: "无慢性病；左肩旧伤", updated: "2 周前" },
  { name: "baselines.md", title: "个人基线（自动）", desc: "HRV 64ms · RHR 54bpm · 睡眠 7.4h", updated: "今天 6:00" },
];

export const personalities = [
  { id: "nerd", name: "数据派", desc: "解释每个数字背后的因果", icon: "BarChart3" },
  { id: "guardian", name: "守护者", desc: "谨慎、强调风险与恢复", icon: "Shield" },
  { id: "friend", name: "朋友", desc: "轻松、鼓励、像聊天", icon: "MessageCircle" },
  { id: "commander", name: "指挥官", desc: "直接、命令式、零废话", icon: "Flag" },
];

export const quickPrompts = [
  "为什么我今天恢复低？",
  "现在适合训练吗？",
  "本周总结一下",
  "帮我看看这顿饭",
  "下周给我一个计划",
];

export const chatHistory = [
  { role: "ai", text: "早上好，Sun。你昨晚的 HRV 比 7 天均值高 6%，今天恢复得不错 ☀️" },
  { role: "ai", text: "**今日建议**\n- 主要：60–75 分钟 Zone 2 跑步\n- 补充：核心 10 分钟\n- 入睡时间：23:00 前" },
  { role: "me", text: "如果改成 HIIT 呢？" },
  { role: "ai", text: "可以做 25 分钟 HIIT，但要把跑步换成放松慢跑。注意 HIIT 后 RPE 控制在 8 以下，否则会影响明天的 HRV。" },
];

export const artifacts = [
  { id: "plan-0608", title: "本周训练计划", kind: "计划", time: "昨天 21:30" },
  { id: "corr-food", title: "晚餐时间 vs 睡眠相关性", kind: "图表", time: "2 天前" },
  { id: "wiki-diff", title: "Wiki 更新：habits.md", kind: "记忆", time: "3 天前" },
  { id: "review-week", title: "上周训练回顾", kind: "报告", time: "周日" },
];
