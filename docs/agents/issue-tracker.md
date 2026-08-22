# Issue tracker: GitHub

> Status: Supporting
> Last verified: 2026-08-21
> Scope: GitHub Issues 规范与 gh CLI 操作契约

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body "..."`
- Add or remove labels: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the current clone. When a skill says to publish to the issue tracker, create a GitHub issue.
