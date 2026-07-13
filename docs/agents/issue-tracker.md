# Issue tracker: GitHub

Issues and PRDs for this repository live in GitHub Issues at `SunWeizhou/Vela`. Use the `gh` CLI for all operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body "..."`
- Add or remove labels: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from the current clone. When a skill says to publish to the issue tracker, create a GitHub issue.
