---
description: Audit an existing generated team — verify the agents still match the project, the spec is internally consistent, and the QA rubric still passes. Suggests revisions.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, TodoWrite
---

# /review-team

You are auditing a previously generated team. Either the project has drifted, the user wants a sanity check, or `/build-team` finished with unresolved warnings.

## Input

`$ARGUMENTS` — optional focus area (e.g. "check if the security reviewer still has the right scope"). If empty, do a full audit.

## Steps

1. Read `.claude/.team-builder-scratch/TEAM_SPEC.json` and every file under `.claude/agents/`.
2. Re-read the project signals: README, package manifest, top-level layout. Has the project changed since the spec was generated? Look at the spec's `generated_at` timestamp vs. `git log --since=<timestamp>` (if a git repo).
3. Spawn the `team-qa-reviewer` agent (subagent_type: `team-qa-reviewer`) and pass it the spec + agents directory + your project-drift summary.
4. The reviewer returns one of:
   - `PASS` — agents are still well-matched. Tell the user, list any minor suggestions, exit.
   - `REVISE` — list of specific defects + recommended fixes.
5. Present the reviewer's findings to the user. Do **not** auto-apply revisions — show the diff and ask. The user may choose to:
   - Apply selected fixes
   - Re-run `/build-team` from scratch (if drift is large)
   - Ignore and keep the current team

## Report format

```
## Team audit: <team-name>

Spec age: <generated_at> (<N> commits since)
Project drift: <none | minor | major>

QA verdict: <PASS | REVISE>

Findings:
1. <finding> — severity: <critical/warning/suggestion>
   Recommended fix: <fix>
   Files affected: <list>

(repeat)

Recommendation: <apply selected | rebuild | ignore>
```

## Hard rules

- **Don't modify any agent file without user approval** — even tiny changes. Show the diff first.
- **Don't run the team during audit.** This is a static review.
- **If TEAM_SPEC.json is missing**, run a structural review of the agent files alone and surface that the spec is gone.
