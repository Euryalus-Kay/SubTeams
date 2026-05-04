# SubTeams

> A meta-tool for Claude Code that **designs and generates** an optimal multi-agent team for any project — then runs it.

You give SubTeams a project (or no input at all — it'll read your current directory). It spawns a team of Opus 4.7 specialists who:

1. **Research** the current best practices for multi-agent systems in your project's domain (cites Anthropic's published guidance)
2. **Analyze** your project's actual requirements (codebase shape, work partitions, existing quality gates)
3. **Architect** an optimal team — exact agent count, roles, models, tool grants, file ownership, communication topology
4. **Generate** the working agent files into your project
5. **Quality-review** the result against a rubric, looping until it passes

You end up with a ready-to-use team and six slash commands: `/build-team`, `/run-team`, `/review-team`, `/team-status`, `/team-dashboard`, `/team-info`.

Quality is the only optimization target. Every meta-agent runs Opus 4.7. The user has explicitly opted out of cost and speed concerns.

---

## Why this exists

Static "templates of agents" go stale fast. Anthropic publishes new guidance every quarter; Claude Code's Agent Teams feature is itself experimental and evolving. A meta-tool that **researches current guidance per-build and adapts to the actual project shape** produces better teams than any one-size-fits-all template ever can.

The architecture: one **meta-team** (4 Opus 4.7 specialists, lives in this repo) that builds **generated teams** (3–7 agents, tailored, lives in your project).

```
You run /build-team
         ↓
Meta-team (this repo)
  · practice-researcher — WebSearch + WebFetch, cites Anthropic guidance
  · project-analyzer    — reads your codebase, finds work partitions
  · team-architect      — synthesizes a TEAM_SPEC.json
  · team-qa-reviewer    — audits against docs/QA-RUBRIC.md (loops if needed)
         ↓
Generated team (your project)
  · 3–7 agents, tailored to YOUR project
  · /run-team kicks them off on a task
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full picture, [docs/PATTERNS.md](docs/PATTERNS.md) for the six patterns the architect picks from, and [docs/DESIGN-PRINCIPLES.md](docs/DESIGN-PRINCIPLES.md) for the twelve rules that govern every generated team.

---

## The two teams in `.claude/agents/`

Nine agent files live in `.claude/agents/` — they belong to **two different teams** with disjoint jobs. Only one of them ships to other projects.

### Meta-team (4 agents) — builds *generated teams* in any project

These are invoked by `/build-team` and shipped to every project by `install.sh`.

| Agent | Role |
|---|---|
| `practice-researcher` | WebSearch + WebFetch, cites Anthropic guidance |
| `project-analyzer` | reads codebase, finds work partitions |
| `team-architect` | synthesizes `TEAM_SPEC.json` |
| `team-qa-reviewer` | audits against `docs/QA-RUBRIC.md` |

### Maintenance team (5 agents) — maintains *this repo only*

These exist to keep SubTeams itself healthy as Anthropic publishes new guidance and the schema/templates evolve. They are intentionally **excluded from `install.sh`** — they do not ship to other projects.

| Agent | Owns |
|---|---|
| `subteams-maintenance-lead` | orchestrator — receives a maintenance task, decomposes, delegates, runs gates |
| `prompt-engineer` | `.claude/agents/`, `.claude/commands/`, `templates/*.md.template`, `.claude/skills/team-builder/SKILL.md` |
| `schema-keeper` | `templates/team-spec.schema.json`, `examples/*.json`, `docs/QA-RUBRIC.md`, `install.sh` |
| `docs-writer` | `README.md`, `docs/{ARCHITECTURE,PATTERNS,DESIGN-PRINCIPLES,INSTALLATION}.md`, `dashboard/server.py`, `dashboard/index.html` |
| `production-verifier` | runs the smoke battery before any maintenance task is declared done |

If you fork SubTeams to evolve it, the maintenance team is the team you'll run. If you only consume SubTeams, you'll never see them — `install.sh` ships only the meta-team and the six commands.

---

## Prerequisites

- **Claude Code** v2.1.32 or later (the version that introduced experimental Agent Teams)
- **Opus 4.7** access on your Claude account
- Experimental Agent Teams enabled AND a permissions block in `~/.claude/settings.json`:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    },
    "permissions": {
      "defaultMode": "bypassPermissions",
      "allow": [
        "Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)",
        "WebSearch", "WebFetch(*)", "Agent(*)", "TeamCreate(*)", "TeamDelete(*)",
        "SendMessage(*)", "TaskCreate(*)", "TaskUpdate(*)", "TaskList(*)", "TodoWrite"
      ]
    }
  }
  ```

  **Both pieces are required.** The env flag turns Agent Teams on; the permissions block keeps spawned teammates from blocking on permission prompts that the parent session never sees. Teammates do NOT inherit `settings.local.json`, only `settings.json` — see [claude-code#26479](https://github.com/anthropics/claude-code/issues/26479). Running `./install.sh --global` writes both blocks for you and merges into existing files instead of overwriting them.

The repo's `.claude/settings.json` already has this — but it only applies when Claude Code is run *inside this repo*. To use SubTeams on other projects, run `./install.sh --global` so your `~/.claude/settings.json` has the same blocks.

---

## Quick start

### 1 — Clone

```sh
git clone https://github.com/Euryalus-Kay/SubTeams.git ~/SubTeams
```

### 2 — Install

**Option A — Globally (every Claude Code chat on your machine):**

```sh
~/SubTeams/install.sh --global
```

This installs into `~/.claude/agents/`, `~/.claude/commands/`, and `~/.claude/.subteams/`. After this, all six commands — `/build-team`, `/run-team`, `/review-team`, `/team-status`, `/team-dashboard`, `/team-info` — are available in any project, no per-project setup needed.

**Option B — Per project (just this one):**

```sh
~/SubTeams/install.sh /path/to/your/project
```

Writes to `<project>/.claude/` and `<project>/.subteams/`. Useful when you want SubTeams visible only in specific repos (e.g. so it doesn't show up in unrelated personal projects).

Either way, the script does not overwrite existing agents/commands — it skips files already present and prints a SKIP line.

### 3 — Open the target project in Claude Code, then run

```
/build-team
```

The meta-team takes over. After a few minutes you'll have:
- `your-project/.claude/agents/<your-team>/*.md` — the generated team
- `your-project/.claude/commands/run-team.md` — the runtime entry point
- `your-project/.claude/.team-builder-scratch/TEAM_SPEC.json` — the spec for traceability

#### Constraining the build

Pass flags to `/build-team` to lock in non-negotiables before the architect picks defaults:

```
/build-team --with security-reviewer,docs-writer
/build-team --agents 5 --without verifier
/build-team --pattern parallel-sectioning  research synthesis project
/build-team --model security-reviewer=opus  this app handles PII
/build-team --without verifier  no need, my CI handles tests
```

| Flag | Effect |
|---|---|
| `--with <list>` | Roles or named agents that MUST appear |
| `--without <list>` | Roles that MUST NOT appear |
| `--agents <N>` | Force exact agent count (3–7) |
| `--pattern <name>` | Force one of the 6 patterns |
| `--model <a=m,b=m>` | Override default model per agent |
| `--topology <subagent\|agent-team>` | Force communication topology |
| `--scratch <dir>` | Override scratch dir |
| `--path <dir>` | Use this dir as project root |

Anything after the flags is treated as **free-form requirements** the architect uses as strong hints. If a flag conflicts with a hard rule (e.g. `--agents 12`, `--without orchestrator`), the architect refuses with a one-line explanation rather than silently ignoring.

### 4 — Run the team on a task

```
/run-team add OAuth login via GitHub
```

The lead receives the task, decomposes it, delegates to its teammates, runs every quality gate, and reports back when done.

### 5 — Audit the team later (optional)

```
/review-team
```

Re-runs the QA reviewer against the current generated team and your current project state. Catches drift if the project has changed substantially since the team was generated.

---

## What you get out of `/build-team`

A real example, generated for a Next.js + Stripe + Postgres SaaS app:

```
Team built: saas-feature-team
Pattern: orchestrator-worker — code-heavy with predictable layer split, EO wrap on security
Agents: 6
  · feature-lead              (orchestrator, opus)    — coordinates, never edits
  · frontend-implementer      (implementer,  opus)    — owns app/, components/, styles/
  · api-implementer           (implementer,  opus)    — owns app/api/, middleware.ts
  · db-implementer            (implementer,  opus)    — owns db/, drizzle.config.ts
  · security-reviewer         (reviewer,     opus)    — read-only, OWASP lens, gates every diff
  · test-runner               (verifier,     opus)    — runs vitest + eslint + tsc + next build

Quality gates:
  · review-loop after every implementer (max 3 iterations)
  · test-command before final ship (max 3 iterations)

Run it with: /run-team add 2FA to login
Spec: .claude/.team-builder-scratch/TEAM_SPEC.json
```

See [examples/](examples/) for three complete TEAM_SPEC examples (SaaS, research synthesis, data pipeline).

---

## File map

```
SubTeams/
├── README.md                           ← this file
├── CLAUDE.md                           ← repo-level Claude Code instructions
├── EVALUATION_PROPOSAL.md              ← proposed evaluation methodology for SubTeams
├── LICENSE                             ← MIT
├── install.sh                          ← installer script (--global or per-project)
├── .claude/
│   ├── settings.json                   ← enables CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
│   ├── commands/
│   │   ├── build-team.md               ← /build-team — meta-orchestrator
│   │   ├── run-team.md                 ← /run-team — runtime supervisor
│   │   ├── review-team.md              ← /review-team — audit existing team
│   │   ├── team-status.md              ← /team-status — text summary of running teams
│   │   ├── team-dashboard.md           ← /team-dashboard — open the live browser dashboard
│   │   └── team-info.md                ← /team-info — detailed inspector for one team
│   ├── agents/                         ← TWO TEAMS LIVE HERE (see "The two teams" below)
│   │   ├── practice-researcher.md      ← meta-team, Opus, WebSearch + WebFetch
│   │   ├── project-analyzer.md         ← meta-team, Opus, reads codebase
│   │   ├── team-architect.md           ← meta-team, Opus, synthesizes TEAM_SPEC
│   │   ├── team-qa-reviewer.md         ← meta-team, Opus, applies QA rubric
│   │   ├── subteams-maintenance-lead.md ← maintenance-team lead, Opus, orchestrates repo upkeep
│   │   ├── prompt-engineer.md          ← maintenance-team, owns .claude/agents + commands + templates + SKILL.md
│   │   ├── schema-keeper.md            ← maintenance-team, owns schema + examples + QA-RUBRIC.md + install.sh
│   │   ├── docs-writer.md              ← maintenance-team, owns README + docs/ + dashboard/
│   │   └── production-verifier.md      ← maintenance-team, runs smoke battery before declaring tasks done
│   └── skills/
│       └── team-builder/
│           └── SKILL.md                ← compact reference, loaded by build-team
├── templates/                          ← used by the generator step
│   ├── team-spec.schema.json
│   ├── orchestrator.md.template
│   ├── researcher.md.template
│   ├── implementer.md.template
│   ├── reviewer.md.template
│   ├── verifier.md.template
│   └── specialist.md.template
├── dashboard/                          ← local-only HTTP dashboard (stdlib + vanilla JS)
│   ├── server.py                       ← Python stdlib HTTP server, /api/state + /api/file
│   └── index.html                      ← single-file UI, polls /api/state every 2s
├── docs/
│   ├── ARCHITECTURE.md                 ← how the two-level system works
│   ├── PATTERNS.md                     ← the 6 patterns + when to pick each
│   ├── DESIGN-PRINCIPLES.md            ← 12 rules every generated team follows
│   ├── QA-RUBRIC.md                    ← canonical checklist
│   ├── INSTALLATION.md                 ← step-by-step setup
│   └── HOW-IT-WORKS.pdf                ← visual walkthrough of the two-level architecture
└── examples/
    ├── example-spec-saas-app.json
    ├── example-spec-research-synth.json
    └── example-spec-data-pipeline.json
```

---

## How to create a GitHub repo for this project (first push)

You already have the URL: <https://github.com/Euryalus-Kay/SubTeams.git>. Two paths.

### A — If you've created the empty repo on GitHub already

```sh
cd "/Users/zainzaidi/Desktop/Sub Teams"
git init
git add .
git commit -m "Initial commit: SubTeams meta-tool for designing multi-agent teams"
git branch -M main
git remote add origin https://github.com/Euryalus-Kay/SubTeams.git
git push -u origin main
```

You'll be prompted for GitHub credentials. Use a **Personal Access Token** (not your password) — generate one at <https://github.com/settings/tokens>.

### B — If you want to create the repo via `gh` from the command line

First authenticate `gh` (one-time):

```sh
gh auth login
```

Then:

```sh
cd "/Users/zainzaidi/Desktop/Sub Teams"
git init
git add .
git commit -m "Initial commit: SubTeams meta-tool for designing multi-agent teams"
git branch -M main
gh repo create Euryalus-Kay/SubTeams \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Meta-tool that designs and generates optimal multi-agent teams in Claude Code"
```

This creates the GitHub repo and pushes in one command.

---

## How to use SubTeams on your other projects

Once the GitHub repo exists:

```sh
# One-time clone (anywhere)
git clone https://github.com/Euryalus-Kay/SubTeams.git ~/SubTeams

# For each project you want a team in:
~/SubTeams/install.sh /path/to/your/project

# Open that project in Claude Code, then:
/build-team           ← designs and generates the team
/run-team <task>      ← runs the team on a task
/review-team          ← audits the team later
/team-status          ← text summary of running teams
/team-dashboard       ← open the live browser dashboard
/team-info <team>     ← detailed inspector for one team
```

To pull updates to SubTeams later:

```sh
cd ~/SubTeams && git pull
~/SubTeams/install.sh /path/to/your/project           # skips existing files (preserves edits)
~/SubTeams/install.sh /path/to/your/project --force   # overwrites with the latest source
```

---

## Customizing what gets generated

The architect's defaults are documented in [docs/DESIGN-PRINCIPLES.md](docs/DESIGN-PRINCIPLES.md). To bias the architect:

- **Prefer fewer / more agents** — edit `team-architect.md` rule 1 in `.claude/agents/`.
- **Prefer Sonnet over Opus for implementers** — edit `team-architect.md` rule 10.
- **Add a project-specific rubric check** — append to `docs/QA-RUBRIC.md`.
- **Add a new role template** — drop a new `templates/<role>.md.template`, then add the role to the `team-spec.schema.json` enum and update `team-architect.md` to know when to pick it.

After editing, re-run `/build-team` to regenerate, or `/review-team` to audit the existing team against the new rules.

---

## Troubleshooting

**`/build-team` says `TeamCreate` is not available**
You haven't enabled `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` globally, or your Claude Code version is too old. Check `~/.claude/settings.json` and run `claude --version`.

**Sub-agents seem stuck — they keep "asking for permissions" but I never see a prompt**
This is the symptom of the [claude-code#26479](https://github.com/anthropics/claude-code/issues/26479) bug: Agent Teams teammates do NOT inherit `settings.local.json`, and the `mode: "bypassPermissions"` parameter on the spawn call alone isn't enough. The fix is to ensure your project's `.claude/settings.json` (and your global `~/.claude/settings.json`) has both `permissions.defaultMode: "bypassPermissions"` AND a wide `permissions.allow` list. Re-run `./install.sh --global` from the SubTeams repo — the installer now merges those blocks into existing settings files (older versions silently skipped if the env flag was already present, which is what left most users without the permissions block).

**The generated team has the wrong number of agents**
Re-run `/build-team` and explicitly pass guidance: `/build-team this is a small library, use 3 agents only`. Or hand-edit `TEAM_SPEC.json` and re-generate by editing the agent files manually (the spec is the source of truth — the QA rubric checks they match).

**The QA reviewer keeps returning REVISE in a loop**
After 3 attempts, the orchestrator escalates to you. Read `.claude/.team-builder-scratch/qa-report-*.md`, fix the listed defects manually, then run `/review-team` to confirm.

**An implementer is editing files outside its `owns_files`**
The runtime orchestrator (`/run-team`) is supposed to prevent this — file an issue with the spec and the offending diff. Workaround: terminate the team (let the agents finish current turn, then `TeamDelete`) and rebuild.

---

## License

[MIT](LICENSE).
