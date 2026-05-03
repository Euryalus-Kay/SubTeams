---
description: Show detailed information about a generated or running team — agents with full descriptions, roles, models, tools, file ownership, quality gates, communication topology. Reads TEAM_SPEC.json if available; falls back to the agent files and live config.
allowed-tools: Read, Glob, Grep, Bash
---

# /team-info

Inspect a team. Useful when you need to know what your generated team can do, who's on it, what each agent's responsibilities are, what tools they have, or which files each implementer owns.

## Input

`$ARGUMENTS` — flexible:
- empty — list every team you can see (live + built specs in cwd) and prompt the user to pick one
- a team name — show full detail for that team
- `live` — show only currently-running teams (those in `~/.claude/teams/`)
- `built` — show only generated team specs (TEAM_SPEC.json under cwd)
- `all` — show full detail for every team you can see
- a path — treated as a project root; show the team there

## Discovery sources

Look in these places, in order. A team can be present in any combination — merge the data when it is:

1. **Live teams** — `~/.claude/teams/<name>/config.json` (current roster + agentIds — the team is actively spawned)
2. **Live tasks** — `~/.claude/tasks/<name>/*.json` (current task ownership + status)
3. **Generated spec** — `<project>/.claude/.team-builder-scratch/TEAM_SPEC.json` (full design intent — the canonical source for built teams)
4. **Generated agent files** — `<project>/.claude/agents/*.md` (the on-disk system prompts)
5. **User-level meta-agents** — `~/.claude/agents/*.md` (only the SubTeams meta-agents — show them only if user asks for `meta`)

## Workflow

### Phase 1 — Discover

If `$ARGUMENTS` is empty, walk all sources and produce a one-line summary per team:

```
LIVE (running right now):
  · saas-feature-team       6 members  · 3 active tasks  · last activity 12s ago
  · meta-team-data-pipeline 4 members  · 0 active tasks  · last activity 4m ago

BUILT (specs on disk, not currently running):
  · ~/projects/my-saas/.claude/.team-builder-scratch/TEAM_SPEC.json
       → saas-feature-team  · pattern: orchestrator-worker  · 6 agents  · generated 2026-04-21

To see one in detail: /team-info <name>
To see them all:      /team-info all
```

Then ask the user which to detail. (One question only — if they don't reply, fall back to listing all.)

### Phase 2 — Detail (single team)

For each agent in the chosen team, show:

```
TEAM: <name>
Description: <from config or spec>
Pattern: <from spec, or "—" if no spec>
Communication topology: <subagent | agent-team>
Generated: <ISO timestamp from spec, if known>
Status: <LIVE — N members spawned | NOT RUNNING — N agents on disk | BOTH>
Lead: <orchestrator name>

═════════════════════════════════════════════════════
AGENT: <name>                              [<role>]
Model: <model>      Max turns: <n>      [<LIVE | not running>]
Trigger: <description from frontmatter>

Responsibilities:
  <responsibilities from spec, or first paragraph of agent file body>

Tools (<count>):
  <comma-separated tool list>

Owns files:
  <glob patterns from spec.owns_files, or "(none — read-only)">

Depends on: <list>
Communicates with: <list>
Stop when: <stop_criteria>
═════════════════════════════════════════════════════

(repeat per agent)

QUALITY GATES (<count>):
  · <type> @ <trigger>  · max iterations: <n>
    config: <pretty-printed config>

LIVE TASKS (if any):
  ID    OWNER          STATUS       AGE       TITLE
  001   researcher     in-progress  2m ago    Research domain best practices
  ...
```

### Phase 3 — Tail

End with two lines:

```
Watch live: /team-dashboard
Audit:      /review-team
```

## Hard rules

- **Do not modify any team or agent file.** Read-only command.
- **Be honest about gaps.** If a spec is missing or an agent file doesn't match the spec, say so explicitly — don't paper over.
- **Don't guess from cached knowledge.** Always read the actual files.
- **Truncate long responsibilities** to ~5 lines per agent. Offer "use /team-info <name> verbose for full text" if needed.
- **Treat agentIds as identifiers, not addresses** — show first 8 chars, never email/URL them anywhere.
- **If `--watch` is requested** for a path outside `~/.claude` and the project, refuse — security boundary.

## When this command beats the dashboard

| Question | Use |
|---|---|
| "What can my team actually do?" | `/team-info` |
| "Why did the architect pick this shape?" | `/team-info` (reads architecture-rationale.md if present) |
| "Who is doing what right now?" | `/team-dashboard` |
| "I want to read a specific agent's full system prompt" | `Read <project>/.claude/agents/<name>.md` directly |
| "Did the lead give the security-reviewer Write?" | `/team-info` (lists tools per agent) |
