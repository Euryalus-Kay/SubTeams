---
description: Design and generate an optimal multi-agent team for the current project. Spawns a meta-team that researches, analyzes, designs, generates, and quality-reviews the new team's agent definitions.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, TaskList, WebSearch, WebFetch, TodoWrite
---

# /build-team

You are the **meta-orchestrator** for SubTeams. Your job is to design and generate a working multi-agent team tailored to the current project, then leave a ready-to-run team behind.

The user's experimental Teams feature is enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Quality is the only optimization target — cost and speed do not matter. Default to Opus 4.7 for every meta-agent.

## Input

`$ARGUMENTS` — flexible. Accepts (in any combination):

**Constraint flags** (parsed first; tell the architect what is non-negotiable):

| Flag | Effect |
|---|---|
| `--with <comma-list>` | These roles or named agents MUST be included. e.g. `--with security-reviewer,docs-writer` |
| `--without <comma-list>` | These roles MUST NOT be included. e.g. `--without verifier` (when you have CI handling that) |
| `--agents <N>` | Force the team size to exactly N (still 3 ≤ N ≤ 7) |
| `--pattern <name>` | Force the pattern: `orchestrator-worker`, `parallel-sectioning`, `sequential-pipeline`, `evaluator-optimizer`, `router`, `hybrid` |
| `--model <agent=model,...>` | Override default model per agent (default for every agent is `opus`). e.g. `--model test-runner=sonnet` to deliberately downgrade one role |
| `--topology <subagent\|agent-team>` | Force communication topology |
| `--scratch <dir>` | Override the scratch directory path (default `.claude/.team-builder-scratch`) |
| `--path <dir>` | Treat this directory as the project root (instead of cwd) |

**Free-form requirements** (everything not parsed as a flag):
- Treated as natural-language instructions / hints / description
- Examples: `"focus the security reviewer on CSRF and SSRF specifically"`, `"this is a CLI tool, no frontend specialists needed"`, `"use my project's existing dbt test command in the verifier"`

**Examples:**
```
/build-team
/build-team /path/to/project
/build-team --with security-reviewer,docs-writer
/build-team --agents 5 --without verifier
/build-team --pattern parallel-sectioning add me a research synthesis team
/build-team --with accessibility-reviewer this app must meet WCAG 2.1 AA
/build-team --model security-reviewer=opus build a security-paranoid SaaS team
```

If `$ARGUMENTS` is empty, the project is the **current working directory**. Auto-detect by reading `README.md`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, top-level files, and the directory tree (3 levels deep).

## Parsing $ARGUMENTS

Walk the input token by token:
1. If a token starts with `--`, parse it and the next token as a flag pair (or the value after `=`). Validate against the table above.
2. Anything not consumed by flag parsing is concatenated as the **free-form requirements / description**.
3. Build a `user_requirements` object:

```json
{
  "with": ["security-reviewer", "docs-writer"],
  "without": [],
  "force_agents": null,
  "force_pattern": null,
  "force_models": {},
  "force_topology": null,
  "scratch_override": null,
  "free_form": "focus the security reviewer on CSRF and SSRF specifically"
}
```

4. **Pass this object verbatim to `team-architect`** in Phase 3. The architect treats `with`, `without`, `force_*` fields as **hard constraints** and the `free_form` field as **strong hints**.

5. **If a flag conflicts with a hard rule** (e.g. `--agents 12` exceeds the cap of 7, or `--without orchestrator` removes the lead), reject the flag explicitly with a one-line explanation and stop. Do not silently ignore.

If `$ARGUMENTS` (after stripping flags) looks like a path, treat it as the project root.

If `$ARGUMENTS` (after stripping flags) is free text, treat it as project description / hints. Ask one clarifying question only if the project's primary goal is genuinely ambiguous after Phase 0 — not because the user gave you constraints.

## Pipeline (5 phases)

### Phase 0 — Discover

**Resolve template & docs location first.** The meta-agents need `templates/` and `docs/QA-RUBRIC.md`. Look in this order:
1. `<project_root>/.subteams/` (project-local install)
2. `~/.claude/.subteams/` (global install via `install.sh --global`)
3. The SubTeams repo itself, if running from there directly

If none exist, tell the user to run `install.sh` first and stop.

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

Send the research report, requirements, **and the parsed `user_requirements` object** to `team-architect`. The architect must:
- Treat `with` / `without` / `force_*` fields as hard constraints
- Treat `free_form` as strong hints (override its defaults but not the hard rules in `docs/QA-RUBRIC.md`)
- Justify in `architecture-rationale.md` how each user requirement was honored
- If a constraint cannot be satisfied without violating a hard rule (e.g. user said `--without reviewer` but the QA rubric requires at least one reviewer or hook), refuse with a one-line explanation routed back through you to the user

Ask it to produce a `TEAM_SPEC.json` conforming to `templates/team-spec.schema.json`. The spec must include:
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
- `<project_root>/.claude/settings.json` — **merge-update, do not overwrite.** Use the Python recipe below. **This is required** — without `defaultMode: bypassPermissions` AND a wide `allow` list in project `settings.json` (NOT `settings.local.json` — teammates do not read that file; see [claude-code#26479](https://github.com/anthropics/claude-code/issues/26479)), spawned teammates block on permission requests for every Bash/Edit call, even when spawned with `mode: "bypassPermissions"`. The mode parameter alone does not cascade through the experimental Agent Teams runtime.

  Run this exact merge (preserves any existing keys the user has set):
  ```bash
  python3 - "$PROJECT_ROOT/.claude/settings.json" <<'PY'
  import json, os, sys
  path = sys.argv[1]
  required_allow = ["Bash(*)","Read(*)","Write(*)","Edit(*)","Glob(*)","Grep(*)",
                    "WebSearch","WebFetch(*)","Agent(*)","TeamCreate(*)","TeamDelete(*)",
                    "SendMessage(*)","TaskCreate(*)","TaskUpdate(*)","TaskList(*)","TodoWrite"]
  cfg = json.load(open(path)) if os.path.exists(path) else {}
  cfg.setdefault("env", {})["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
  perms = cfg.setdefault("permissions", {})
  perms.setdefault("defaultMode", "bypassPermissions")
  existing = perms.get("allow") if isinstance(perms.get("allow"), list) else []
  perms["allow"] = existing + [x for x in required_allow if x not in set(existing)]
  os.makedirs(os.path.dirname(path), exist_ok=True)
  json.dump(cfg, open(path, "w"), indent=2)
  PY
  ```
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
