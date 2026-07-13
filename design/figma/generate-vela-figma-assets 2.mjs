import fs from "node:fs";
import path from "node:path";

const outDir = path.resolve("design/figma");
const W = 393;
const H = 852;

const C = {
  bg: "#F2F2F7",
  card: "#FFFFFF",
  ink: "#1C1C1E",
  ink2: "#636366",
  muted: "#8E8E93",
  meta: "#AEAEB2",
  border: "#E5E5EA",
  blue: "#007AFF",
  blueSoft: "#EAF3FF",
  sage: "#5B8C6F",
  sageSoft: "#ECF5EF",
  amber: "#B8843E",
  amberSoft: "#FAF1E4",
  indigo: "#6B6FA0",
  indigoSoft: "#EEEEF7",
  rose: "#A85260",
  roseSoft: "#F8ECEE",
};

const esc = (value) =>
  String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");

function rect(x, y, width, height, fill, radius = 0, attrs = "") {
  return `<rect x="${x}" y="${y}" width="${width}" height="${height}" rx="${radius}" fill="${fill}" ${attrs}/>`;
}

function line(x1, y1, x2, y2, stroke = C.border, width = 1, attrs = "") {
  return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${stroke}" stroke-width="${width}" ${attrs}/>`;
}

function text(x, y, value, size = 14, weight = 400, fill = C.ink, attrs = "") {
  return `<text x="${x}" y="${y}" font-family="-apple-system, BlinkMacSystemFont, SF Pro Text, Inter, sans-serif" font-size="${size}" font-weight="${weight}" fill="${fill}" ${attrs}>${esc(value)}</text>`;
}

function circle(cx, cy, r, fill, attrs = "") {
  return `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}" ${attrs}/>`;
}

function pill(x, y, width, label, bg, fg, icon = "") {
  return `<g aria-label="${esc(label)}">
    ${rect(x, y, width, 28, bg, 14)}
    ${icon ? text(x + 11, y + 19, icon, 12, 700, fg) : ""}
    ${text(x + (icon ? 29 : 12), y + 19, label, 11, 600, fg)}
  </g>`;
}

function cardStart(name, x, y, width, height, radius = 22) {
  return `<g id="${name}" aria-label="${name}">
    ${rect(x, y, width, height, C.card, radius, `filter="url(#shadow)"`)}
  `;
}

function cardEnd() {
  return "</g>";
}

function defs() {
  return `<defs>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="5" stdDeviation="10" flood-color="#1C1C1E" flood-opacity="0.06"/>
    </filter>
    <filter id="tabShadow" x="-20%" y="-40%" width="140%" height="180%">
      <feDropShadow dx="0" dy="6" stdDeviation="16" flood-color="#1C1C1E" flood-opacity="0.13"/>
    </filter>
  </defs>`;
}

function shell(title, subtitle, body, activeTab) {
  const tabs = [
    ["Today", "●"],
    ["Training", "◆"],
    ["Vitals", "♥"],
    ["Intelligence", "✦"],
    ["Me", "○"],
  ];
  const tabXs = [44, 116, 189, 271, 348];
  const tab = `<g id="Bottom Navigation">
    ${rect(16, 774, 361, 64, "#FFFFFFEE", 25, `filter="url(#tabShadow)" stroke="#FFFFFF" stroke-width="1"`)}
    ${tabs
      .map(([label, icon], index) => {
        const active = label === activeTab;
        return `${text(tabXs[index], 799, icon, 15, 700, active ? C.blue : C.muted, 'text-anchor="middle"')}
          ${text(tabXs[index], 820, label, 9, active ? 650 : 500, active ? C.blue : C.muted, 'text-anchor="middle"')}`;
      })
      .join("")}
  </g>`;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
    ${defs()}
    ${rect(0, 0, W, H, C.bg)}
    <g id="Status Bar">
      ${text(22, 26, "9:41", 12, 650, C.ink)}
      ${text(337, 26, "5G  ▰", 11, 600, C.ink)}
    </g>
    <g id="Navigation Header">
      ${text(20, 62, title, 30, 760, C.ink)}
      ${text(20, 84, subtitle, 12, 500, C.ink2)}
      ${circle(354, 59, 18, C.ink)}
      ${text(354, 64, "W", 12, 700, "#FFFFFF", 'text-anchor="middle"')}
    </g>
    ${body}
    ${tab}
  </svg>`;
}

function todayScreen() {
  const hero = `${cardStart("Body State Hero", 16, 104, 361, 252)}
    ${pill(32, 121, 118, "Ready with caution", C.amberSoft, C.amber)}
    ${text(32, 173, "78", 50, 760, C.ink)}
    ${text(112, 168, "Readiness", 14, 650, C.ink2)}
    ${text(112, 189, "Good capacity, mild local fatigue", 11, 500, C.muted)}
    ${pill(245, 124, 104, "Confidence 82%", C.blueSoft, C.blue)}
    ${pill(245, 158, 104, "Fresh 12 min", C.sageSoft, C.sage)}
    ${line(32, 211, 361, 211)}
    ${text(32, 237, "STATE", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(93, 237, "Ready, but protect pressing volume", 12, 580, C.ink)}
    ${text(32, 261, "CAUSE", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(93, 261, "Sleep + HRV support training", 12, 580, C.ink)}
    ${text(32, 285, "PLAN", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(93, 285, "Upper Body · 80% volume · RPE ≤ 7", 12, 650, C.blue)}
    ${text(32, 309, "WATCH", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(93, 309, "Chest fatigue and afternoon energy", 12, 580, C.ink)}
    ${rect(32, 322, 329, 42, C.blue, 14)}
    ${text(196.5, 348, "Start adapted session", 14, 700, "#FFFFFF", 'text-anchor="middle"')}
  ${cardEnd()}`;

  const metric = (x, value, label, color, soft, detail) => `<g aria-label="${label}">
    ${rect(x, 374, 111, 108, C.card, 18)}
    ${circle(x + 28, 404, 15, soft)}
    ${text(x + 28, 409, value, 12, 750, color, 'text-anchor="middle"')}
    ${text(x + 16, 438, label, 12, 650, C.ink)}
    ${text(x + 16, 459, detail, 10, 500, C.muted)}
  </g>`;

  const watch = `${cardStart("Watch Card", 16, 498, 361, 104)}
    ${text(32, 524, "WATCH TODAY", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${circle(43, 552, 11, C.amberSoft)}
    ${text(43, 557, "!", 12, 750, C.amber, 'text-anchor="middle"')}
    ${text(64, 552, "If energy drops below 45", 13, 650, C.ink)}
    ${text(64, 571, "Swap final press for mobility and finish early.", 11, 500, C.ink2)}
    ${text(32, 590, "Source: BodyStateKernel · Non-diagnostic guidance", 9, 500, C.muted)}
  ${cardEnd()}`;

  const timeline = `${cardStart("Daily Loop", 16, 618, 361, 132)}
    ${text(32, 644, "DAILY LOOP", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${line(45, 676, 345, 676, C.border, 2)}
    ${[
      [46, C.sage, "Sleep", "7h 42m"],
      [121, C.blue, "Plan", "Adapted"],
      [196, C.amber, "Train", "Today"],
      [271, C.indigo, "Check-in", "Tonight"],
      [346, C.meta, "Response", "Tomorrow"],
    ]
      .map(
        ([x, color, label, value]) =>
          `${circle(x, 676, 7, color)}${text(x, 702, label, 9, 620, C.ink2, 'text-anchor="middle"')}${text(x, 718, value, 9, 520, C.muted, 'text-anchor="middle"')}`
      )
      .join("")}
    ${text(32, 739, "The next plan adapts to your recovery response.", 10, 550, C.ink2)}
  ${cardEnd()}`;

  return shell(
    "Today",
    "Tuesday, June 9 · Active Coach OS",
    `${hero}
     ${metric(16, "74", "Recovery", C.sage, C.sageSoft, "HRV above baseline")}
     ${metric(141, "82", "Sleep", C.indigo, C.indigoSoft, "Consistent timing")}
     ${metric(266, "61", "Strain", C.amber, C.amberSoft, "Moderate target")}
     ${watch}
     ${timeline}`,
    "Today"
  );
}

function trainingScreen() {
  const session = `${cardStart("Today Session", 16, 104, 361, 282)}
    ${pill(32, 121, 78, "REDUCE", C.amberSoft, C.amber)}
    ${text(32, 171, "Upper Body", 25, 760, C.ink)}
    ${text(32, 194, "Week 4 · Session 2 · 42 min", 12, 520, C.ink2)}
    ${pill(245, 126, 104, "Plan active", C.sageSoft, C.sage)}
    ${line(32, 214, 361, 214)}
    ${text(32, 241, "Volume", 11, 600, C.muted)}
    ${text(32, 267, "80%", 27, 750, C.ink)}
    ${text(133, 241, "Intensity cap", 11, 600, C.muted)}
    ${text(133, 267, "RPE 7", 27, 750, C.ink)}
    ${text(257, 241, "Exercises", 11, 600, C.muted)}
    ${text(257, 267, "5", 27, 750, C.ink)}
    ${rect(32, 286, 329, 48, C.blue, 16)}
    ${text(196.5, 316, "Start Workout", 15, 720, "#FFFFFF", 'text-anchor="middle"')}
    ${text(32, 357, "Why adjusted", 11, 650, C.ink)}
    ${text(111, 357, "Chest fatigue is elevated; recovery remains stable.", 11, 500, C.ink2)}
    ${text(32, 375, "Source: TrainingDecisionKernel · Confidence 82%", 9, 500, C.muted)}
  ${cardEnd()}`;

  const control = `${cardStart("Execution Controls", 16, 402, 361, 106)}
    ${text(32, 427, "EXECUTION CONTROLS", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${rect(32, 443, 101, 47, C.bg, 14)}
    ${text(82.5, 462, "REST TIMER", 9, 700, C.muted, 'text-anchor="middle"')}
    ${text(82.5, 481, "01:30", 15, 750, C.ink, 'text-anchor="middle"')}
    ${rect(145, 443, 101, 47, C.bg, 14)}
    ${text(195.5, 462, "LAST SET", 9, 700, C.muted, 'text-anchor="middle"')}
    ${text(195.5, 481, "70 × 8", 15, 750, C.ink, 'text-anchor="middle"')}
    ${rect(258, 443, 103, 47, C.blueSoft, 14)}
    ${text(309.5, 462, "PERSONAL BEST", 9, 700, C.blue, 'text-anchor="middle"')}
    ${text(309.5, 481, "82.5 kg", 15, 750, C.blue, 'text-anchor="middle"')}
  ${cardEnd()}`;

  const fatigue = `${cardStart("Muscle Fatigue", 16, 524, 361, 100)}
    ${text(32, 550, "LOCAL FATIGUE", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(32, 576, "Chest", 12, 650, C.ink)}
    ${rect(92, 568, 199, 8, C.border, 4)}
    ${rect(92, 568, 145, 8, C.rose, 4)}
    ${text(345, 576, "High", 11, 650, C.rose, 'text-anchor="end"')}
    ${text(32, 603, "Triceps", 12, 650, C.ink)}
    ${rect(92, 595, 199, 8, C.border, 4)}
    ${rect(92, 595, 107, 8, C.amber, 4)}
    ${text(345, 603, "Moderate", 11, 650, C.amber, 'text-anchor="end"')}
  ${cardEnd()}`;

  const next = `${cardStart("Next Session Suggestion", 16, 640, 361, 110)}
    ${text(32, 666, "NEXT SESSION", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${text(32, 692, "Lower Body · Thursday", 15, 700, C.ink)}
    ${text(32, 713, "Keep full volume if next-day recovery stays ≥ 70.", 11, 500, C.ink2)}
    ${pill(32, 726, 126, "Review after check-in", C.indigoSoft, C.indigo)}
    ${text(361, 744, "›", 22, 400, C.meta, 'text-anchor="end"')}
  ${cardEnd()}`;

  return shell(
    "Training",
    "Execute the plan, capture the response",
    `${session}${control}${fatigue}${next}`,
    "Training"
  );
}

function intelligenceScreen() {
  const insight = `${cardStart("Proactive Insight", 16, 104, 361, 132)}
    ${pill(32, 120, 112, "PROACTIVE INSIGHT", C.blueSoft, C.blue)}
    ${text(32, 164, "Your best training window is 17:00–19:00", 15, 720, C.ink)}
    ${text(32, 186, "Energy is stable and recent strength sessions recover well", 11, 500, C.ink2)}
    ${text(32, 202, "when pressing volume stays below 85%.", 11, 500, C.ink2)}
    ${text(32, 221, "Source: 30-day trend · Confidence 79% · Non-diagnostic", 9, 500, C.muted)}
  ${cardEnd()}`;

  const plan = `${cardStart("Today Plan Artifact", 16, 252, 361, 126)}
    ${text(32, 278, "TODAY PLAN ARTIFACT", 10, 750, C.meta, 'letter-spacing="1.2"')}
    ${circle(48, 311, 16, C.blueSoft)}
    ${text(48, 316, "✦", 12, 750, C.blue, 'text-anchor="middle"')}
    ${text(76, 307, "Adapted Upper Body", 15, 720, C.ink)}
    ${text(76, 327, "Reduce volume to 80% · cap effort at RPE 7", 11, 500, C.ink2)}
    ${pill(76, 340, 104, "Confidence 82%", C.sageSoft, C.sage)}
    ${text(350, 326, "›", 22, 400, C.meta, 'text-anchor="end"')}
  ${cardEnd()}`;

  const inbox = `${cardStart("Memory Inbox", 16, 394, 361, 78)}
    ${circle(45, 433, 17, C.indigoSoft)}
    ${text(45, 438, "2", 12, 760, C.indigo, 'text-anchor="middle"')}
    ${text(73, 425, "Memory inbox", 14, 700, C.ink)}
    ${text(73, 445, "Two proposals waiting for review", 11, 500, C.ink2)}
    ${text(349, 439, "Review ›", 11, 650, C.blue, 'text-anchor="end"')}
  ${cardEnd()}`;

  const artifactCard = (y, icon, titleValue, typeValue, confidence, color, soft) => `${cardStart(titleValue, 16, y, 361, 74, 18)}
    ${circle(44, y + 37, 16, soft)}
    ${text(44, y + 42, icon, 11, 750, color, 'text-anchor="middle"')}
    ${text(72, y + 31, titleValue, 13, 680, C.ink)}
    ${text(72, y + 49, typeValue, 10, 520, C.muted)}
    ${pill(274, y + 23, 87, confidence, C.bg, C.ink2)}
  ${cardEnd()}`;

  const wiki = `${cardStart("Wiki Files", 16, 650, 361, 62, 18)}
    ${circle(43, 681, 15, C.sageSoft)}
    ${text(43, 686, "W", 11, 750, C.sage, 'text-anchor="middle"')}
    ${text(70, 678, "Body Wiki & long-term memory", 13, 680, C.ink)}
    ${text(70, 695, "Preferences · patterns · constraints", 10, 500, C.muted)}
    ${text(350, 689, "›", 22, 400, C.meta, 'text-anchor="end"')}
  ${cardEnd()}`;

  const composer = `<g id="Ask Coach Composer">
    ${rect(16, 728, 361, 42, C.card, 21, `stroke="${C.border}" stroke-width="1"`)}
    ${text(34, 754, "Ask Coach about today's plan…", 12, 500, C.muted)}
    ${circle(351, 749, 15, C.blue)}
    ${text(351, 754, "↑", 13, 750, "#FFFFFF", 'text-anchor="middle"')}
  </g>`;

  return shell(
    "Intelligence",
    "Insights become durable product artifacts",
    `${insight}${plan}${inbox}
     ${text(20, 500, "RECENT ARTIFACTS", 10, 750, C.meta, 'letter-spacing="1.2"')}
     ${artifactCard(512, "↗", "Weekly recovery report", "weekly_report · Jun 8", "84%", C.sage, C.sageSoft)}
     ${artifactCard(592, "↔", "Pressing volume adjustment", "training_adjustment · Today", "82%", C.amber, C.amberSoft)}
     ${wiki}${composer}`,
    "Intelligence"
  );
}

const assets = {
  "vela-today-os.svg": todayScreen(),
  "vela-training-execution.svg": trainingScreen(),
  "vela-intelligence-workspace.svg": intelligenceScreen(),
};

for (const [name, svg] of Object.entries(assets)) {
  fs.writeFileSync(path.join(outDir, name), svg);
}

const boardGap = 44;
const boardPadding = 64;
const boardWidth = boardPadding * 2 + W * 3 + boardGap * 2;
const boardHeight = H + 164;
const board = `<svg xmlns="http://www.w3.org/2000/svg" width="${boardWidth}" height="${boardHeight}" viewBox="0 0 ${boardWidth} ${boardHeight}">
  ${defs()}
  ${rect(0, 0, boardWidth, boardHeight, "#E7E7EC")}
  ${text(64, 58, "Vela 4.0 · Active Coach OS", 32, 760, C.ink)}
  ${text(64, 86, "Daily body intelligence loop · Core mobile experience", 14, 520, C.ink2)}
  ${Object.entries(assets)
    .map(([name, svg], index) => {
      const inner = svg.replace(/^<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
      const x = boardPadding + index * (W + boardGap);
      return `<g transform="translate(${x}, 124)">
        ${rect(-10, -10, W + 20, H + 20, "#FFFFFF", 36, `filter="url(#shadow)"`)}
        ${inner}
      </g>`;
    })
    .join("")}
</svg>`;

fs.writeFileSync(path.join(outDir, "vela-active-coach-os-board.svg"), board);
console.log(`Generated ${Object.keys(assets).length + 1} SVG assets in ${outDir}`);
