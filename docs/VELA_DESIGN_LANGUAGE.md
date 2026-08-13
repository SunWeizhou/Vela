# Vela Design Language — Calm Rhythm

> Updated: 2026-08-13（对齐 Personal Edition 产品方向，见 `docs/VELA_PERSONAL_PRODUCT_DIRECTION.md` 视觉方向一节）

Vela should feel like a private health intelligence product, not a dashboard template. The interface is native to iOS, quiet enough for daily use, and decisive when the user needs to act.

## Product principles

1. **One screen, one answer.** Every primary surface should answer one question before presenting supporting detail.
2. **Content before containers.** Use spacing and typography for grouping; add a card only when it represents a distinct object or action.
3. **Action before explanation.** Show the recommended next step first, then evidence, confidence, and methodology on demand.
4. **Calm, not empty.** Minimal interfaces still need warmth, useful empty states, and a clear path forward.
5. **Confidence is part of the data.** Missing or uncertain health data must change the recommendation, not merely add a warning badge.
6. **Native by default.** Prefer system navigation, typography, sheets, controls, Dynamic Type, and SF Symbols.
7. **Motion explains change.** Animate transitions and state changes only; avoid ambient animation and decorative blur.

## Visual identity

Vela uses its own visual identity: 暖灰绿画布（`rhythmCanvas` `#F2F5F1`）、深墨文字（`rhythmInk` `#10201C`）与低饱和节律绿品牌色（`accent` `#17A35C`）。品牌气质为安静、可信、私人且有生命感；状态颜色只用于有意义的变化，不让五个领域色同时争夺注意力。

品牌主对象是 **Rhythm Horizon（健康地平线）**：一条随时间展开、由睡眠、恢复、压力、负荷和能量共同塑形的容量窗口。它表达趋势与可承受范围，不是总分，也不冒充精确预测。Training 延续同一视觉语法，以 Training Rhythm（训练节律）展示背、胸、肩、腿和手臂/核心的柔性路径。

## Visual rules

- 暖灰绿画布背景；深墨主文字；节律绿只用于主行动、选中态与“智能”信号——不作装饰。
- Semantic health colors are muted and never replace a text label.
- Apple 原生排版（SF Pro）；数字使用等宽字，行动与解释使用自然语言，不以巨型数字制造权威感。
- Prefer 16–20 pt page margins and an 8 pt spacing rhythm.
- Hero 先显示今日节奏决定，再显示最多三个证据锚点与一个计划入口；详细评分、可信度、样本与推理下沉到证据层。
- 同一层级不超过三个视觉重点；首页是一个连续环境，内容优先于容器。
- 半透明材质只用于导航、底部行动入口和可展开证据 Sheet，不在卡片上继续叠卡片。
- Avoid nested cards, tinted boxes inside tinted boxes, and more than one filled button per section.
- 数据变化使用临界阻尼、可中断的连续运动；开启 Reduce Motion 时改为静态呈现或短淡入。不使用无意义循环动画。
- 所有缺失数据显示 `--`、待同步或覆盖度说明，不显示伪造的健康数字。
- Use sentence case. Avoid uppercase section labels in Chinese.
- Empty states should be compact and always offer a useful action.

## Primary surfaces（四工作区：Today / Training / Vela / Me）

- **Today（决定优先）：** 日期与数据新鲜度 → Hero 今日最重要的健康节奏决定与唯一主按钮 → 2–3 个关键证据锚点 → 最多两项辅助行动 → 一句 Coach 解释。
- **Training（决策与边界优先）：** 下一站练哪里、为何这样安排、当天容量/RPE/时长边界 → 训练中由 Apple Watch 记录，Vela 不要求训练中操作手机 → 训练后快速体感确认 + 选填明细。
- **Vela（原 Coach，解释与调整）：** Decision Studio 首屏默认解释 Today 决定，明确区分本机建议与联网 AI 增强；AI 提出 Plan Proposal，重要变更需用户显式确认。
- **Me（设置与信任）：** 个人上下文、建议历史与必要入口，不呈现健康成绩单；旧版日志与生理能力作为证据详情与资料库，不与每日决定平级。

## Quality gate

Every screen must be checked in light/dark mode, default and accessibility text sizes, with complete and missing data, on the smallest supported iPhone and a current Pro Max device.
