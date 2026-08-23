import { useEffect, useState } from "react";
import { TabBar, TabKey } from "./components/nav/TabBar";
import { HomePage } from "./pages/Home";
import { FitnessPage } from "./pages/Fitness";
import { VitalsPage } from "./pages/Vitals";
import { CoachHub } from "./pages/CoachHub";
import { CoachChat } from "./pages/CoachChat";
import { MetricDetail } from "./pages/MetricDetail";
import { SettingsPage } from "./pages/Settings";
import { WikiPage } from "./pages/Wiki";
import { BiomarkerPage } from "./pages/Biomarkers";
import { FoodLogPage } from "./pages/FoodLog";
import { ReportsPage } from "./pages/Reports";
import { TrainingPlanPage } from "./pages/TrainingPlan";
import { WikiFilePage } from "./pages/WikiFile";
import { AlgorithmsPage, AlgorithmDetail, AlgoId } from "./pages/Algorithms";

export default function App() {
  const [tab, setTab] = useState<TabKey>("today");
  const [stack, setStack] = useState<string[]>([]);

  useEffect(() => {
    const colorScheme = window.matchMedia("(prefers-color-scheme: dark)");
    const applySystemAppearance = () => {
      document.documentElement.classList.toggle("dark", colorScheme.matches);
    };
    applySystemAppearance();
    colorScheme.addEventListener("change", applySystemAppearance);
    return () => colorScheme.removeEventListener("change", applySystemAppearance);
  }, []);

  const push = (r: string) => {
    if (r === "coach") {
      setTab("coach");
      setStack([]);
      return;
    }
    setStack((s) => [...s, r]);
  };
  const pop = () => setStack((s) => s.slice(0, -1));
  const top = stack[stack.length - 1];

  function renderRoot() {
    switch (tab) {
      case "today": return <HomePage go={push} />;
      case "trends": return <VitalsPage go={push} />;
      case "plan": return <FitnessPage go={push} />;
      case "coach": return <CoachHub go={push} />;
    }
  }

  function renderTop() {
    if (!top) return null;
    if (top === "chat") return <CoachChat onBack={pop} />;
    if (top === "settings") return <SettingsPage onBack={pop} go={push} />;
    if (top === "wiki") return <WikiPage onBack={pop} go={push} />;
    if (top === "algorithms") return <AlgorithmsPage onBack={pop} go={push} />;
    if (top.startsWith("algo:")) return <AlgorithmDetail id={top.slice("algo:".length) as AlgoId} onBack={pop} />;
    if (top.startsWith("wikifile:")) return <WikiFilePage filename={top.slice("wikifile:".length)} onBack={pop} />;
    if (top === "biomarker") return <BiomarkerPage onBack={pop} />;
    if (top === "food") return <FoodLogPage onBack={pop} />;
    if (top === "reports") return <ReportsPage onBack={pop} />;
    if (top === "plan") return <TrainingPlanPage onBack={pop} />;
    if (top.startsWith("detail:")) {
      const id = top.slice("detail:".length);
      return <MetricDetail id={id} onBack={pop} openChat={() => push("chat")} />;
    }
    // unknown route — render coach hub as fallback
    return <CoachHub go={push} />;
  }

  const isFullScreen = top === "chat";

  return (
    <div
      className="size-full min-h-screen relative antialiased"
      style={{ background: "var(--ios-bg)", color: "var(--ios-label)" }}
    >
      <div className="mx-auto max-w-[480px] min-h-screen relative">
        {top ? renderTop() : renderRoot()}
      </div>

      {!isFullScreen && (
        <TabBar
          active={tab}
          onChange={(k) => {
            setStack([]);
            setTab(k);
          }}
        />
      )}
    </div>
  );
}
