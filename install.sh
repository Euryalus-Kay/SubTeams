#!/usr/bin/env bash
# install.sh — install SubTeams into a target project.
#
# Usage:
#   ./install.sh <path-to-target-project>
#
# After running, the target project will have:
#   .claude/agents/{practice-researcher,project-analyzer,team-architect,team-qa-reviewer}.md
#   .claude/commands/{build-team,review-team}.md
#   .claude/skills/team-builder/SKILL.md
#   .subteams/templates/   (the agent templates the generator uses)
#   .subteams/docs/        (QA rubric and reference docs)
#
# It does NOT touch:
#   .claude/agents/<existing-team-stuff>.md
#   CLAUDE.md
#   anything else outside the .claude/ paths it owns

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-target-project>" >&2
  exit 1
fi

TARGET="$1"
SOURCE="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -d "$TARGET" ]]; then
  echo "Error: target directory does not exist: $TARGET" >&2
  exit 1
fi

echo "Installing SubTeams into: $TARGET"
echo "  Source: $SOURCE"

# Create destination directories
mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/skills/team-builder"
mkdir -p "$TARGET/.subteams/templates"
mkdir -p "$TARGET/.subteams/docs"

# Copy meta-agents
for f in practice-researcher project-analyzer team-architect team-qa-reviewer; do
  if [[ -f "$TARGET/.claude/agents/$f.md" ]]; then
    echo "  SKIP existing: .claude/agents/$f.md (use --force to overwrite)"
  else
    cp "$SOURCE/.claude/agents/$f.md" "$TARGET/.claude/agents/$f.md"
    echo "  + .claude/agents/$f.md"
  fi
done

# Copy commands. run-team is generic — it reads TEAM_SPEC.json at runtime.
for f in build-team run-team review-team; do
  if [[ -f "$TARGET/.claude/commands/$f.md" ]]; then
    echo "  SKIP existing: .claude/commands/$f.md"
  else
    cp "$SOURCE/.claude/commands/$f.md" "$TARGET/.claude/commands/$f.md"
    echo "  + .claude/commands/$f.md"
  fi
done

# Copy skill
cp "$SOURCE/.claude/skills/team-builder/SKILL.md" "$TARGET/.claude/skills/team-builder/SKILL.md"
echo "  + .claude/skills/team-builder/SKILL.md"

# Copy templates and docs (always overwrite — these are reference assets)
cp -R "$SOURCE/templates/"* "$TARGET/.subteams/templates/"
echo "  + .subteams/templates/ ($(ls "$SOURCE/templates" | wc -l | tr -d ' ') files)"

cp "$SOURCE/docs/QA-RUBRIC.md" "$TARGET/.subteams/docs/QA-RUBRIC.md"
cp "$SOURCE/docs/PATTERNS.md" "$TARGET/.subteams/docs/PATTERNS.md"
cp "$SOURCE/docs/DESIGN-PRINCIPLES.md" "$TARGET/.subteams/docs/DESIGN-PRINCIPLES.md"
cp "$SOURCE/docs/ARCHITECTURE.md" "$TARGET/.subteams/docs/ARCHITECTURE.md"
echo "  + .subteams/docs/ (4 reference docs)"

# Settings: enable Agent Teams flag if .claude/settings.json doesn't already
if [[ -f "$TARGET/.claude/settings.json" ]]; then
  if grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$TARGET/.claude/settings.json"; then
    echo "  = .claude/settings.json (Agent Teams flag already present)"
  else
    echo "  ! .claude/settings.json exists but does not enable Agent Teams."
    echo "    Add this to its env block:"
    echo '      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"'
  fi
else
  cat > "$TARGET/.claude/settings.json" <<'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF
  echo "  + .claude/settings.json"
fi

echo ""
echo "SubTeams installed."
echo ""
echo "Next steps in $TARGET:"
echo "  1. Open Claude Code in this project."
echo "  2. Run: /build-team"
echo "  3. After it finishes, run: /run-team <your task>"
echo ""
echo "Reference docs are at: .subteams/docs/"
echo "Templates the generator uses: .subteams/templates/"
