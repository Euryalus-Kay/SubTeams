# SubTeams

> A meta-tool for Claude Code that **designs and generates** an optimal multi-agent team for any project — then runs it.

You give SubTeams a project (or no input at all — it'll read your current directory). It spawns a team of Opus 4.7 specialists who:

1. **Research** the current best practices for multi-agent systems in your project's domain (cites Anthropic's published guidance)
2. **Analyze** your project's actual requirements (codebase shape, work partitions, existing quality gates)
3. **Architect** an optimal team — exact agent count, roles, models, tool grants, file ownership, communication topology
4. **Generate** the working agent files into your project
5. **Quality-review** the result against a rubric, looping until it passes

You end up with a ready-to-use team and three slash commands: `/build-team`, `/run-team`, `/review-team`.

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

## Prerequisites

- **Claude Code** v2.1.32 or later (the version that introduced experimental Agent Teams)
- **Opus 4.7** access on your Claude account
- Experimental Agent Teams enabled in `~/.claude/settings.json`:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```

The repo's `.claude/settings.json` already has this flag — but it only applies when Claude Code is run *inside this repo*. To use SubTeams on other projects, set the flag globally too.

---

## Quick start

### 1 — Clone

```sh
git clone https://github.com/Euryalus-Kay/SubTeams.git ~/SubTeams
```

### 2 — Install into a target project

```sh
~/SubTeams/install.sh /path/to/your/project
```

This copies the four meta-agents, the `/build-team` and `/review-team` commands, the templates the generator uses, and the QA rubric into your project (under `.claude/` and `.subteams/`). It does not touch any existing files.

### 3 — Open the target project in Claude Code, then run

```
/build-team
```

The meta-team takes over. After a few minutes you'll have:
- `your-project/.claude/agents/<your-team>/*.md` — the generated team
- `your-project/.claude/commands/run-team.md` — the runtime entry point
- `your-project/.claude/.team-builder-scratch/TEAM_SPEC.json` — the spec for traceability

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
  · frontend-implementer      (implementer,  sonnet)  — owns app/, components/, styles/
  · api-implementer           (implementer,  sonnet)  — owns app/api/, middleware.ts
  · db-implementer            (implementer,  sonnet)  — owns db/, drizzle.config.ts
  · security-reviewer         (reviewer,     opus)    — read-only, OWASP lens, gates every diff
  · test-runner               (verifier,     sonnet)  — runs vitest + eslint + tsc + next build

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
├── install.sh                          ← installer script
├── .claude/
│   ├── settings.json                   ← enables CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
│   ├── commands/
│   │   ├── build-team.md               ← /build-team — meta-orchestrator
│   │   ├── run-team.md                 ← /run-team — runtime supervisor
│   │   └── review-team.md              ← /review-team — audit existing team
│   ├── agents/                         ← META-AGENTS (used to BUILD teams)
│   │   ├── practice-researcher.md      ← Opus, WebSearch + WebFetch
│   │   ├── project-analyzer.md         ← Opus, reads codebase
│   │   ├── team-architect.md           ← Opus, synthesizes TEAM_SPEC
│   │   └── team-qa-reviewer.md         ← Opus, applies QA rubric
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
├── docs/
│   ├── ARCHITECTURE.md                 ← how the two-level system works
│   ├── PATTERNS.md                     ← the 6 patterns + when to pick each
│   ├── DESIGN-PRINCIPLES.md            ← 12 rules every generated team follows
│   ├── QA-RUBRIC.md                    ← canonical checklist
│   └── INSTALLATION.md                 ← step-by-step setup
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
```

To pull updates to SubTeams later:

```sh
cd ~/SubTeams && git pull
~/SubTeams/install.sh /path/to/your/project   # re-runs to refresh meta-agents (existing files are skipped)
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

**The generated team has the wrong number of agents**
Re-run `/build-team` and explicitly pass guidance: `/build-team this is a small library, use 3 agents only`. Or hand-edit `TEAM_SPEC.json` and re-generate by editing the agent files manually (the spec is the source of truth — the QA rubric checks they match).

**The QA reviewer keeps returning REVISE in a loop**
After 3 attempts, the orchestrator escalates to you. Read `.claude/.team-builder-scratch/qa-report-*.md`, fix the listed defects manually, then run `/review-team` to confirm.

**An implementer is editing files outside its `owns_files`**
The runtime orchestrator (`/run-team`) is supposed to prevent this — file an issue with the spec and the offending diff. Workaround: terminate the team (let the agents finish current turn, then `TeamDelete`) and rebuild.

---

## License

[MIT](LICENSE).
