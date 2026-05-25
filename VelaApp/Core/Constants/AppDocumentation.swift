struct AppDocumentation: Identifiable, Hashable {
    let id: String
    let title: String
    let relativePath: String
}

enum AppDocumentationIndex {
    static let requiredDocuments: [AppDocumentation] = [
        .init(id: "prd", title: "Product Requirements", relativePath: "docs/PRD.md"),
        .init(id: "mvp-plan", title: "MVP Execution Plan", relativePath: "docs/MVP_EXECUTION_PLAN.md"),
        .init(id: "ai-agent", title: "AI Agent Spec", relativePath: "docs/AI_AGENT_SPEC.md"),
        .init(id: "architecture", title: "Technical Architecture", relativePath: "docs/TECH_ARCHITECTURE.md"),
        .init(id: "reuse", title: "Open Source Reuse Plan", relativePath: "docs/OPEN_SOURCE_REUSE_PLAN.md"),
        .init(id: "scoring", title: "Scoring System v0.1", relativePath: "docs/SCORING_SYSTEM_V0_1.md"),
        .init(id: "stitch", title: "Stitch Design Brief", relativePath: "docs/STITCH_DESIGN_BRIEF.md")
    ]
}
