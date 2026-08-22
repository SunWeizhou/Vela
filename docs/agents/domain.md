# Domain Docs

> Status: Supporting
> Last verified: 2026-08-21
> Scope: Agent 领域上下文阅读规范

## Read before exploring

- Read `CONTEXT.md` at the repository root when it exists.
- Read decisions in `docs/adr/` that affect the area being changed.
- If either location is absent, continue silently; producer workflows create documents when decisions crystallize.

## Consumer rules

- Use the canonical terms defined in `CONTEXT.md` in code, tests, issues, and reports.
- Do not introduce synonyms for an existing canonical term.
- Surface any conflict with an ADR explicitly instead of silently overriding it.

## Layout

```text
/
├── CONTEXT.md
├── docs/adr/
└── VelaApp/
```
