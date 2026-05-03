# Installation

SubTeams is a Claude Code project, not a binary. You install it by cloning the repo into a known location and either copying its `.claude/` assets into your project or using it as a standalone workspace that builds teams elsewhere.

## Prerequisites

- **Claude Code v2.1.32 or later** (the version that introduced experimental Agent Teams).
- **Opus 4.7 access** on your Claude account (required for meta-team quality).
- `git` and (optionally) `gh` for pushing the SubTeams repo to GitHub.

Verify Claude Code version:

```sh
claude --version
```

## Step 1 — Enable Agent Teams in your global Claude Code settings

Edit `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

This enables the `TeamCreate`, `TeamDelete`, `SendMessage`, and shared task-list tools that SubTeams relies on.

## Step 2 — Clone SubTeams

```sh
git clone https://github.com/Euryalus-Kay/SubTeams.git ~/SubTeams
```

Or use it directly from your Desktop folder if that's where you developed it.

## Step 3 — Two ways to use SubTeams on a project

### Option A — Install SubTeams *into* the target project (recommended)

This makes `/build-team`, `/run-team`, and `/review-team` directly available inside the project.

```sh
cd <your-target-project>

# Copy commands and meta-agents
cp -R ~/SubTeams/.claude/agents/* .claude/agents/
cp -R ~/SubTeams/.claude/commands/build-team.md .claude/commands/
cp -R ~/SubTeams/.claude/commands/review-team.md .claude/commands/
# (run-team is generated per-project by /build-team — don't copy it)

# Copy templates and the QA rubric (the meta-agents reference these)
mkdir -p .subteams
cp -R ~/SubTeams/templates .subteams/
cp -R ~/SubTeams/docs .subteams/
```

The meta-agents reference `templates/` and `docs/QA-RUBRIC.md`. By copying them under `.subteams/` in the target project, the meta-team can find them without you setting environment variables.

You'll then update the path references in `practice-researcher.md`, `team-architect.md`, and `team-qa-reviewer.md` to use `.subteams/templates/` and `.subteams/docs/`. (Or run the bundled `install.sh` — see Option C below.)

### Option B — Use SubTeams as a standalone workspace

Open the SubTeams repo itself in Claude Code. Run `/build-team <path-to-target-project>` and pass the target path as `$ARGUMENTS`. The meta-team will build the spec and write the generated team into `<path-to-target-project>/.claude/`.

You don't get `/build-team` inside the target project this way, but you don't have to copy any files either.

### Option C — Add a one-shot installer script (future work)

Run the installer (planned, not yet implemented):

```sh
~/SubTeams/install.sh <path-to-target-project>
```

For now, do Option A or B manually.

## Step 4 — Verify the install

In your target project, in Claude Code:

```
/build-team
```

You should see Claude:
1. Read your README, package manifest, top-level layout.
2. Create a meta-team via `TeamCreate`.
3. Spawn `practice-researcher`, `project-analyzer`, `team-architect`, and `team-qa-reviewer`.
4. After a few minutes, hand back a generated team in `<your-project>/.claude/agents/`.

If step 2 fails with a tool-not-found error, your `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` flag isn't being read. Restart Claude Code after editing `settings.json`.

## Step 5 — Use the generated team

```
/run-team add a 2FA flow to login
```

The lead receives your task, decomposes it, delegates to teammates, runs quality gates, and reports back.

## Updating SubTeams

```sh
cd ~/SubTeams && git pull
```

Then re-copy assets into your target project (if you used Option A). The meta-agents may have been improved; existing generated teams in your target projects are not affected.

## Uninstalling

In a target project that used Option A:

```sh
rm -rf .claude/agents/practice-researcher.md \
       .claude/agents/project-analyzer.md \
       .claude/agents/team-architect.md \
       .claude/agents/team-qa-reviewer.md \
       .claude/commands/build-team.md \
       .claude/commands/review-team.md \
       .subteams
```

The generated team in `.claude/agents/<your-team>/` and `.claude/commands/run-team.md` is yours — keep or remove independently.
