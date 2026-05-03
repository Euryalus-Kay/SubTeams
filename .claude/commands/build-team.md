---
description: Design and generate an optimal multi-agent team for the current project. Spawns a meta-team that researches, analyzes, designs, generates, and quality-reviews the new team's agent definitions.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList, WebSearch, WebFetch, TodoWrite
---

# /build-team

You are the **meta-orchestrator** for SubTeams. Your job is to design and generate a working multi-agent team tailored to the current project, then leave a ready-to-run team behind.

The user's experimental Teams feature is enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Quality is the only optimization target — cost and speed do not matter. Default to Opus 4.7 for every meta-agent.

## Input

`$ARGUMENTS` — the project description, a path, a goal, or empty.

If `$ARGUMENTS` is empty, the project is the **current working directory**. Auto-detect by reading `README.md`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, top-level files, and the directory tree (3 levels deep).

If `$ARGUMENTS` looks like a path, treat it as the project root.

If `$ARGUMENTS` is free text, treat it as a project description and ask the user one clarifying question if needed (no more).

## Pipeline (5 phases)

### Phase 0 — Discover

Gather just enough about the project to brief the meta-team. Do not over-read.

```
- Glob: README.md, *.md (top-level), package.json, pyproject.toml, requirements.txt, Cargo.toml, go.mod, .github/workflows/*.yml
- Read each one fully
- Bash: tree -L 3 -I 'node_modules|.git|__pycache__|venv|.venv' (or fall back to: find . -maxdepth 3 -type d)
- Detect: language(s), framework(s), domain (web app / data pipeline / library / CLI / research / etc.), test infra, build infra
- Note any CLAUDE.md, AGENTS.md, .claude/ that already exist
```

Produce a one-page **project briefing** (Markdown, in your scratch — don't write to disk yet) that contains:
- Project name & one-sentence description
- Stack & domain
- Apparent goals (from README or user input)
- Constraints (tests, deploy targets, languages)
- Any existing agent / skill / hook configuration to respect

### Phase 1 — Spawn the meta-team

Use `TeamCreate` to create a team named `meta-team-{project-slug}`. Then spawn the four meta-agents using the `Agent` tool with the `team_name` parameter — each is defined in `.claude/agents/`:

| Name | subagent_type | Model | Purpose |
|---|---|---|---|
| `practice-researcher` | `practice-researcher` | opus | Research domain-specific multi-agent patterns. WebSearch + WebFetch. |
| `project-analyzer` | `project-analyzer` | opus | Audit the project's actual requirements and produce a requirements doc. |
| `team-architect` | `team-architect` | opus | Synthesize a TEAM_SPEC from research + requirements. |
| `team-qa-reviewer` | `team-qa-reviewer` | opus | Audit the generated team against the rubric in `docs/QA-RUBRIC.md`. |

(The `agent-generator` step happens in your own context after the architect returns the spec — see Phase 3.)

Send each spawned teammate the project briefing as their first message. Researcher and analyzer can work in parallel.

### Phase 2 — Research & analyze (parallel)

Create two top-level tasks via `TaskCreate`:

1. **Research best practices for this project's domain.** Owner: `practice-researcher`. Output: `meta-team-{slug}/research-report.md` written to the project root under `.claude/.team-builder-scratch/`.
2. **Analyze project requirements.** Owner: `project-analyzer`. Output: `.claude/.team-builder-scratch/requirements.md`.

Wait for both to complete (they will message you when done — message-passing is automatic, you do not poll).

### Phase 3 — Architect & generate

Send the research report and requirements to `team-architect`. Ask it to produce a `TEAM_SPEC.json` conforming to `templates/team-spec.schema.json`. The spec must include:
- Pattern selection (orchestrator-worker / parallel / sequential / evaluator-optimizer / router) with rationale
- Agent list (3–7 agents) with name, role, model, tools, responsibilities, stop criteria, file ownership
- Quality gates (review loops, hooks, max turns)
- Communication topology (subagent vs. team)

When the spec arrives, **you (the meta-orchestrator) generate the actual agent files yourself.** Do not delegate this — generation is mechanical and benefits from being in one context.

For each agent in the spec:
1. Pick the matching template under `templates/` (orchestrator / researcher / implementer / reviewer / verifier / specialist)
2. Fill in the template using the agent's spec entry
3. Write to `<project_root>/.claude/agents/<name>.md`

Also write:
- `<project_root>/.claude/settings.json` — merge-update to enable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` if not already set
- `<project_root>/CLAUDE.md` — append (don't overwrite) a section listing the team and how to invoke it
- `<project_root>/.claude/.team-builder-scratch/TEAM_SPEC.json` — keep the spec for traceability and `/review-team` later

Do **not** regenerate `run-team.md` — `install.sh` already copied a generic version that reads `TEAM_SPEC.json` at runtime, which works for any team. If `run-team.md` is missing in the project, copy it from `.subteams/` (or warn the user to re-run `install.sh`).

### Phase 4 — Quality review (loop)

Send `team-qa-reviewer` the path to `<project_root>/.claude/agents/` and `TEAM_SPEC.json`. It applies the rubric in `docs/QA-RUBRIC.md` and returns one of:
- `PASS` — done.
- `REVISE` — with a list of specific defects.

If `REVISE`, fix the listed defects and re-submit. Cap at **3 review loops**. If still not passing after 3, surface the remaining issues to the user and let them decide.

### Phase 5 — Hand off

1. Shut down the meta-team: send each teammate `{type: "shutdown_request"}`, then `TeamDelete` once they're all gone.
2. Print a summary to the user:
   - Team name
   - Pattern chosen + 1-sentence rationale
   - Roster: each agent's name, role, model
   - How to run it: `/run-team` (or the project-specific command if you renamed it)
   - Where everything lives: `<project_root>/.claude/agents/`, `.claude/commands/run-team.md`, `.claude/.team-builder-scratch/TEAM_SPEC.json`
3. Keep your own scratch (`.team-builder-scratch/`) — it lets `/review-team` work later. Add it to `.gitignore` only if the user requests.

## Hard rules

- **Never generate more than 7 worker agents.** If the architect returns more, push back once and ask it to consolidate. Routing degrades fast above 7.
- **Never generate fewer than 3.** Below 3, recommend a single agent + skills instead.
- **Every generated agent must have:** `name`, `description` with a trigger condition, `tools` (minimal viable set), `model`, `maxTurns`, a numbered "When invoked" workflow, an explicit "Stop when:" criterion.
- **Reviewer / verifier agents are read-only** — never grant `Write` or `Edit`.
- **Implementers are partitioned by file ownership.** No two implementers may write to overlapping globs. The architect must enforce this; you must verify.
- **The generated team must include at least one quality gate** (reviewer agent or a hook).
- **The generated lead's system prompt must include explicit delegation enforcement** — leads that do worker work themselves are a documented failure mode.
- **Never embed secrets or credentials in any generated file.**

## On clarifying questions

You may ask the user **at most one** clarifying question, and only if the project's primary goal is genuinely ambiguous after Phase 0. Prefer to make a reasonable assumption, build the team, and let the user iterate via `/review-team`.

## On failures

If a meta-teammate hangs, stalls, or returns garbage:
1. Send a follow-up message clarifying what you need.
2. If still stalled, terminate that teammate and re-spawn it once.
3. If it fails twice, fall through to single-agent mode: do the analysis / architecture yourself in your own context. Do not block the user.

## Output to the user (final message)

```
Team built: <team-name>
Pattern: <pattern> — <one-sentence why>
Agents: <count>
  · <name-1> (<role>, <model>) — <one-line responsibility>
  · ...
Quality gates: <list>
Run it with: /run-team <task-description>
Spec: .claude/.team-builder-scratch/TEAM_SPEC.json
Audit it later: /review-team
```

That's it. Build the team. Quality first.
