---
description: Print a structured text summary of every running Agent Team — roster, task counts, recent task activity. Reads ~/.claude/teams/ and ~/.claude/tasks/. No browser, no server.
allowed-tools: Bash, Read, Glob, Grep
---

# /team-status

Show what every Agent Team on this machine is currently doing, as text. Useful when you want a quick check without spinning up the dashboard.

## Input

`$ARGUMENTS` — optional team name. If provided, show only that team. If empty, show all.

## Steps

1. **List teams.** `ls -la ~/.claude/teams/` (skip if directory missing → tell user "no teams active").
2. **For each team directory:**
   - Read `~/.claude/teams/<team>/config.json` → extract `members[]` (name, agentType, agentId).
   - Read every `~/.claude/tasks/<team>/*.json` → extract `id`, `title` (or `content`), `owner`, `status`, mtime.
3. **Format the output** as the structure below. Use Markdown tables if the chat renders them well, otherwise aligned columns.

## Output format

```
Team: <name>
Description: <config.description or —>
Members (N):
  · <name>          <agentType>          <agentId-short>
  · ...

Tasks (X total: A in-progress, B completed, C blocked, D pending):
  ID    OWNER          STATUS         AGE       TITLE
  001   researcher     in-progress    2m ago    Research domain best practices
  002   architect      pending        5m ago    Synthesize TEAM_SPEC.json
  ...

Recent activity (last 5 task updates):
  · 2m ago — researcher set task 001 → in-progress
  · 5m ago — orchestrator created task 002
  ...
```

If there are multiple teams, separate each with a horizontal rule and a blank line.

## Hard rules

- **Read-only.** Never modify any team or task file.
- **Be quiet about empty state.** "No active teams" is one line, not a paragraph.
- **Do not leak agentIds in full** — show first 8 characters and `…` to keep output scannable.
- **Cap task list at 20 per team** by default; if there are more, summarize and offer to print all.
- **For absolute current state, recommend `/team-dashboard`** at the bottom of the output. Don't auto-start it.
