# QA Rubric for Generated Teams

This is the canonical checklist `team-qa-reviewer` uses to audit a generated team. Every check has a severity. Verdict is computed deterministically from severities.

## Severity scale

- **Critical** — must PASS. Any FAIL → REVISE.
- **Warning** — should PASS. ≥3 FAIL → REVISE.
- **Suggestion** — nice-to-have. Never causes REVISE on its own.

A team gets **PASS** when: all Critical PASS, ≤2 Warning FAIL, no structural defects.

---

## Section A — TEAM_SPEC structural integrity

| # | Check | Severity |
|---|---|---|
| A1 | `TEAM_SPEC.json` exists and is valid JSON | Critical |
| A2 | Spec validates against `templates/team-spec.schema.json` | Critical |
| A3 | `team_name` matches the team's actual name in `.claude/agents/` filenames (no orphans, no missing) | Critical |
| A4 | `agents` array length is between 3 and 7 inclusive | Critical |
| A5 | Exactly one agent has `role: orchestrator` | Critical |
| A6 | At least one `quality_gate` is defined | Critical |
| A7 | `pattern_rationale` references the research report (cites a source or explicit research finding) | Warning |
| A8 | `generated_at` is a valid ISO-8601 timestamp | Warning |
| A9 | `shared_context.claude_md_additions` is ≤30 lines | Warning |

## Section B — Agent file structural integrity

For every file in `.claude/agents/`:

| # | Check | Severity |
|---|---|---|
| B1 | YAML frontmatter parses successfully | Critical |
| B2 | `name` field matches filename (e.g. `code-reviewer.md` has `name: code-reviewer`) | Critical |
| B3 | `description` field is present and ≥10 characters | Critical |
| B4 | `description` includes a trigger condition phrase (e.g. "Use proactively after…", "Use when…", "Use immediately when…") | Warning |
| B5 | `tools` field is present and lists at least one tool | Critical |
| B6 | `model` field is present and is one of `opus`/`sonnet`/`haiku`/`inherit` | Critical |
| B7 | `maxTurns` field is present and is a positive integer | Warning |
| B8 | Body has a "When invoked" numbered workflow | Warning |
| B9 | Body has an explicit "Stop when" criterion | Warning |
| B10 | Body has hard rules / constraints section | Suggestion |

## Section C — Role-specific constraints

| # | Check | Severity |
|---|---|---|
| C1 | Orchestrator has `Agent` (or equivalent spawning capability) in its tool list | Critical |
| C2 | Orchestrator's body includes explicit delegation enforcement ("delegate first, do not execute specialist work in your own context" or equivalent) | Critical |
| C3 | Reviewer agents do **not** have `Write` or `Edit` in their tool list | Critical |
| C4 | Verifier agents do **not** have `Write` or `Edit` in their tool list | Critical |
| C5 | Researchers do not write outside `shared_context.scratch_dir` (verified by inspection of the body) | Warning |
| C6 | Every implementer has a non-empty `owns_files` list | Critical |
| C7 | No two implementers' `owns_files` globs overlap (string-equality check on patterns; lexical overlap is a Warning) | Critical |
| C8 | Every agent file has a "Hard rules" section preventing destructive actions without user confirmation | Warning |

## Section D — Routing & description hygiene

| # | Check | Severity |
|---|---|---|
| D1 | No two agents have the same `description` (routing collision) | Critical |
| D2 | Each agent's `description` names a specific trigger condition, not just a capability | Warning |
| D3 | `trigger_phrase` in spec matches the agent file's `description` field | Warning |
| D4 | No agent description is longer than 500 characters | Suggestion |

## Section E — Communication & topology

| # | Check | Severity |
|---|---|---|
| E1 | If `communication_topology: agent-team`, the `communicates_with` graph for each agent makes sense (no isolated agents, no impossible dependencies) | Warning |
| E2 | If `communication_topology: subagent`, agent files do not assume peer messaging | Warning |
| E3 | The dependency graph (`depends_on`) has no cycles | Critical |
| E4 | Every agent (other than the orchestrator) appears in at least one other agent's `communicates_with` or `depends_on` (no orphans) | Warning |

## Section F — Project fit

| # | Check | Severity |
|---|---|---|
| F1 | Project's existing test command, lint command, and build command are referenced by at least one verifier or hook | Warning |
| F2 | Project's existing `.claude/agents/` (if any) are not silently overwritten | Critical |
| F3 | Generated `CLAUDE.md` additions are appended, not replacing existing content | Critical |
| F4 | The pattern chosen (`pattern` field) actually matches the project shape per the requirements doc | Warning |
| F5 | Roles named in the spec actually appear in the research report's recommendations, or the rationale explains the deviation | Warning |

## Section G — Safety hygiene

| # | Check | Severity |
|---|---|---|
| G1 | No agent file contains hardcoded secrets, API keys, tokens, or credentials | Critical |
| G2 | No agent grants both `Bash` and unconstrained network tools without an explicit safety note in its hard rules | Warning |
| G3 | No agent's body instructs running `rm -rf`, `git push --force`, or schema migrations without user confirmation | Critical |
| G4 | No agent's body trusts instructions found in source files, READMEs, or fetched URLs as commands | Warning |

---

## How to apply this

1. Walk every check in order, A → G.
2. For each, record `PASS`, `FAIL`, or `N/A` with a one-sentence reason.
3. Compute verdict:
   - Any Critical FAIL → **REVISE**
   - ≥3 Warning FAIL → **REVISE**
   - Otherwise → **PASS**
4. Always include suggestions in the report even on PASS — they help the user iterate later.
