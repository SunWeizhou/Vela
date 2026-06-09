# Vela 移动端 Web App — Apple 毛玻璃风格

## Context
用户希望基于其 GitHub 仓库 `SunWeizhou/Vela` (branch: `codex/vela-3-active-coach-os`) 的 iOS 健身助手 App，构建一个移动端 Web 版本的视觉/交互复刻，整体采用 Apple iOS 26 原生毛玻璃（liquid glass / frosted glass）风格。Vela 自定位为 "Active Coach OS"：将健康数据、AI 教练和训练计划整合在一起，前端已于 2026-05 冻结，仍可作为完整设计参照。

本项目无 `@make-kits` 设计系统，可使用 Tailwind v4 + Radix 自由构建。

## 设计语言（Apple iOS 26 Liquid Glass）
- 深色 + 浅色双主题，默认深色（更突出毛玻璃高光）
- 背景：渐变 / 模糊照片背景，配合 `backdrop-filter: blur(30px) saturate(180%)` 卡片
- 卡片：半透明白 (light) / 半透明黑 (dark)，1px 内描边 `rgba(255,255,255,0.15)`，柔和阴影
- 圆角：卡片 24px，控件 16px，按钮 pill
- 字体：SF Pro 风格 — 使用 `-apple-system, "SF Pro Display"` fallback
- 颜色 accent：Vela 蓝紫渐变（运动/恢复主色），强调色随场景变化
- 顶部 large title + 下方 sticky 毛玻璃导航栏；底部 5 项 tab bar 同样毛玻璃

## 信息架构（基于源 App 5 个 tab）
1. **Home** — 今日总览：Recovery / Strain / Sleep 三大评分环 + 关键指标 + AI 洞察卡
2. **Journal** — 日记式时间线，含训练 / 营养 / 备注卡片
3. **Fitness** — 30 天活动 heatmap + 训练 readiness + 表现趋势 chart
4. **Vitals** — HRV / 静息心率 / 睡眠 / 呼吸率 / 血氧 / 体重 多指标列表，点击进入详情
5. **Vela Intelligence**（中心 + 按钮）— AI Chat：Ask / Analyze / Plan 快捷操作

附加：指标详情页（大数值 + 7/30 天趋势 + driver 卡 + AI 分析条）

## 关键文件改动
- `src/app/App.tsx` — 装配路由（react-router）、tab bar、全局背景渐变
- `src/styles/theme.css` — 注入 iOS 风格 token：玻璃背景变量、模糊半径、accent 渐变
- `src/styles/fonts.css` — 引入 SF 风格回退字体栈
- `src/app/components/glass/GlassCard.tsx` — 通用毛玻璃容器
- `src/app/components/nav/TabBar.tsx` — 底部 5 项毛玻璃 tab bar（中心凸起 + 号）
- `src/app/components/nav/TopBar.tsx` — Large title + sticky 毛玻璃顶栏
- `src/app/components/charts/RingScore.tsx` — Recovery/Strain/Sleep 评分环（SVG）
- `src/app/components/charts/TrendChart.tsx` — recharts 7/30 天趋势
- `src/app/components/charts/Heatmap.tsx` — 30 天活动 heatmap
- `src/app/pages/Home.tsx`
- `src/app/pages/Journal.tsx`
- `src/app/pages/Fitness.tsx`
- `src/app/pages/Vitals.tsx`
- `src/app/pages/Intelligence.tsx` — AI chat 入口 + sheet
- `src/app/pages/MetricDetail.tsx` — 通用指标详情页
- `src/app/data/mock.ts` — Vela 风格 mock 数据（HRV、Strain、Recovery、Sleep、训练计划等）

依赖：已具备 `recharts`、`motion`、`react-router`、`lucide-react`，无需新增包。

## 视觉细节
- 顶部背景：根据 tab 切换的多色径向渐变（Home 紫蓝，Fitness 橙红，Vitals 青绿）
- 卡片浮层动效：进入用 motion 弹簧；点击轻微缩放
- Tab bar 浮在内容上方，内容滚动时背景可透出
- 中心 + 按钮：圆形大尺寸，蓝紫渐变 + 内发光，按下触发 Intelligence sheet

## 验证
- 在 Make 预览中以 iPhone 视口检查 5 个 tab 的切换、滚动、毛玻璃模糊效果
- 检查浅/深背景下卡片可读性
- 点击 Vitals 指标进入详情页并返回
- 中心 + 按钮唤起 Intelligence 抽屉
