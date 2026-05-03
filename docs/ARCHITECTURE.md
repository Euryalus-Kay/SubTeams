# SubTeams Architecture

## What this is

SubTeams is a **meta-tool**. It does not do your project's work directly. It builds a **team of agents** that does your project's work.

Two-level architecture:

```
LEVEL 1 — Meta-team (this repo)
─────────────────────────────────
Lives in:     this repo's .claude/agents/, .claude/commands/
Purpose:      Design and generate Level 2 teams
Triggered:    User runs /build-team in their project
Composition:  4 Opus 4.7 specialists + the meta-orchestrator (the slash command itself)

LEVEL 2 — Generated team (your project)
─────────────────────────────────────
Lives in:     <your-project>/.claude/agents/, <your-project>/.claude/commands/
Purpose:      Do the actual project work
Triggered:    User runs /run-team <task> in their project
Composition:  3–7 agents tailored to the project (size, roles, models, tools)
```

## The flow

```
              ┌────────────────────────────────────────────┐
              │ USER in their project, runs /build-team    │
              └─────────────────────┬──────────────────────┘
                                    ▼
              ┌────────────────────────────────────────────┐
              │ Meta-orchestrator                          │
              │ (.claude/commands/build-team.md)           │
              │ - Phase 0: Discover the project            │
              └─────────────────────┬──────────────────────┘
                                    ▼
                  ┌─────────────────┴─────────────────┐
                  ▼                                    ▼
   ┌──────────────────────────────┐  ┌────────────────────────────┐
   │ practice-researcher (Opus)   │  │ project-analyzer (Opus)    │
   │ - WebSearch + WebFetch       │  │ - Reads codebase            │
   │ - Cites Anthropic guidance   │  │ - Maps work partitions      │
   │ → research-report.md         │  │ → requirements.md           │
   └──────────────┬───────────────┘  └─────────────┬──────────────┘
                  └─────────────────┬───────────────┘
                                    ▼
              ┌────────────────────────────────────────────┐
              │ team-architect (Opus)                      │
              │ - Synthesizes a TEAM_SPEC.json             │
              │ - Validates against schema                 │
              │ - Writes architecture-rationale.md         │
              └─────────────────────┬──────────────────────┘
                                    ▼
              ┌────────────────────────────────────────────┐
              │ Meta-orchestrator (generator step)         │
              │ - Materializes the spec into agent .md     │
              │   files using templates/                   │
              │ - Writes /run-team in user's project       │
              │ - Updates user's CLAUDE.md                 │
              └─────────────────────┬──────────────────────┘
                                    ▼
              ┌────────────────────────────────────────────┐
              │ team-qa-reviewer (Opus)                    │
              │ - Walks docs/QA-RUBRIC.md                  │
              │ - Returns PASS or REVISE                   │
              └─────────────────────┬──────────────────────┘
                                    ▼
                              ┌─────┴─────┐
                              │           │
                          PASS│           │REVISE (max 3 loops)
                              │           ▼
                              │     ┌─────────────────────┐
                              │     │ Fix defects, re-QA  │
                              │     └──────────┬──────────┘
                              │                │
                              ▼                │
              ┌─────────────────────────────────────────────┐
              │ Hand off: shut down meta-team, summarize   │
              │ the new team to the user.                  │
              │ User now has /run-team in their project.   │
              └─────────────────────────────────────────────┘
```

## Why two levels?

Because the *design* of an effective team depends on the project. A web app's team looks nothing like a research synthesis team. A meta-tool that prescribes the same team for every project is just a static template.

The meta-team:
- **Researches** what's known about agent design for this kind of project (cites Anthropic engineering posts and the current Claude Code docs — these change quarterly, so static guidance goes stale).
- **Analyzes** the actual project to find natural work partitions, existing quality gates, and constraints.
- **Architects** a spec that reflects both.
- **Generates** a real working team from the spec.
- **QAs** the result.

## Why Opus 4.7 everywhere in the meta-team?

User explicitly said quality > cost > speed. The meta-team runs once per project (or once per significant scope change), so the cost of using the strongest model for design is amortized over every subsequent `/run-team` invocation. A weaker meta-team can produce a structurally fine spec that subtly mismatches the project — and that mismatch costs the user every single run.

The *generated* team's models are chosen by the architect based on the role (Opus for orchestrator/reviewer, Sonnet for typical implementers, Haiku for high-volume mechanical specialists).

## Why Agent Teams, not just subagents?

Subagents are hub-and-spoke: workers return one string to the lead, then exit. Fine for parallel research, bad when:
- Workers need to dispute each other (e.g. reviewer challenges implementer)
- Work is long-running and benefits from incremental coordination
- The same workers handle many sub-tasks over time

Agent Teams give peer messaging and a shared task list. The meta-team uses Teams (the four meta-agents coordinate to produce one spec). The *generated* team may use either — `team-architect` decides based on the project's shape.

## File map

```
SubTeams/                                    ← this repo
├── README.md                                ← installation + usage
├── LICENSE
├── .gitignore
├── .claude/
│   ├── settings.json                        ← enables CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
│   ├── commands/
│   │   ├── build-team.md                    ← /build-team (meta-orchestrator)
│   │   ├── run-team.md                      ← /run-team (runtime supervisor)
│   │   └── review-team.md                   ← /review-team (audit existing team)
│   ├── agents/                              ← META-AGENTS (used to BUILD teams)
│   │   ├── practice-researcher.md
│   │   ├── project-analyzer.md
│   │   ├── team-architect.md
│   │   └── team-qa-reviewer.md
│   └── skills/
│       └── team-builder/
│           └── SKILL.md                     ← reference doc loaded into orchestrator's context
├── templates/                               ← used by the generator step
│   ├── team-spec.schema.json
│   ├── orchestrator.md.template
│   ├── researcher.md.template
│   ├── implementer.md.template
│   ├── reviewer.md.template
│   ├── verifier.md.template
│   └── specialist.md.template
├── docs/
│   ├── ARCHITECTURE.md                      ← this file
│   ├── PATTERNS.md                          ← the 6 canonical patterns + when to pick each
│   ├── DESIGN-PRINCIPLES.md                 ← rules of thumb the architect follows
│   ├── QA-RUBRIC.md                         ← canonical checklist for team-qa-reviewer
│   └── INSTALLATION.md                      ← step-by-step setup
└── examples/
    ├── example-spec-saas-app.json           ← what a generated spec looks like
    ├── example-spec-research-synth.json
    └── example-spec-data-pipeline.json
```

## Where generated artifacts go (in the user's project)

```
<user-project>/
├── CLAUDE.md                                ← ≤30 lines appended by the generator
├── .claude/
│   ├── settings.json                        ← updated to enable Agent Teams if needed
│   ├── agents/                              ← the GENERATED team (3–7 .md files)
│   ├── commands/
│   │   └── run-team.md                      ← project-specific runtime command
│   └── .team-builder-scratch/               ← spec, research, requirements, QA reports
│       ├── TEAM_SPEC.json
│       ├── research-report.md
│       ├── requirements.md
│       ├── architecture-rationale.md
│       └── qa-report-<timestamp>.md
```

The `.team-builder-scratch/` directory is intentionally *not* gitignored by default — the spec is useful to commit so teammates and `/review-team` can see provenance. Users who don't want it tracked can add it to their own `.gitignore`.
