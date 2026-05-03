#!/usr/bin/env bash
# install.sh — install SubTeams.
#
# Usage:
#   ./install.sh <path-to-target-project>     # project install
#   ./install.sh --global                     # user-level install (every Claude Code chat)
#
# Project install writes to <target>/.claude/ and <target>/.subteams/.
# Global install writes to ~/.claude/ and ~/.claude/.subteams/.
#
# Either mode adds:
#   .claude/agents/{practice-researcher,project-analyzer,team-architect,team-qa-reviewer}.md
#   .claude/commands/{build-team,run-team,review-team}.md
#   .claude/skills/team-builder/SKILL.md
#   .subteams/templates/   (the agent templates the generator uses)
#   .subteams/docs/        (QA rubric and reference docs)
#
# It does NOT touch:
#   .claude/agents/<existing-team-stuff>.md (skipped if already present)
#   CLAUDE.md
#   anything else outside the .claude/ paths it owns

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-target-project>" >&2
  echo "       $0 --global" >&2
  exit 1
fi

SOURCE="$(cd "$(dirname "$0")" && pwd)"

if [[ "$1" == "--global" ]]; then
  MODE="global"
  TARGET="$HOME/.claude"
  SUBTEAMS_DIR="$HOME/.claude/.subteams"
  echo "Installing SubTeams GLOBALLY (user-level): $TARGET"
else
  MODE="project"
  TARGET="$1"
  SUBTEAMS_DIR="$TARGET/.subteams"
  if [[ ! -d "$TARGET" ]]; then
    echo "Error: target directory does not exist: $TARGET" >&2
    exit 1
  fi
  echo "Installing SubTeams into project: $TARGET"
fi

echo "  Source: $SOURCE"

# Create destination directories
if [[ "$MODE" == "global" ]]; then
  mkdir -p "$TARGET/agents"
  mkdir -p "$TARGET/commands"
  mkdir -p "$TARGET/skills/team-builder"
  AGENTS_DIR="$TARGET/agents"
  COMMANDS_DIR="$TARGET/commands"
  SKILLS_DIR="$TARGET/skills/team-builder"
  SETTINGS_PATH="$TARGET/settings.json"
else
  mkdir -p "$TARGET/.claude/agents"
  mkdir -p "$TARGET/.claude/commands"
  mkdir -p "$TARGET/.claude/skills/team-builder"
  AGENTS_DIR="$TARGET/.claude/agents"
  COMMANDS_DIR="$TARGET/.claude/commands"
  SKILLS_DIR="$TARGET/.claude/skills/team-builder"
  SETTINGS_PATH="$TARGET/.claude/settings.json"
fi

mkdir -p "$SUBTEAMS_DIR/templates"
mkdir -p "$SUBTEAMS_DIR/docs"

# Copy meta-agents
for f in practice-researcher project-analyzer team-architect team-qa-reviewer; do
  if [[ -f "$AGENTS_DIR/$f.md" ]]; then
    echo "  SKIP existing: $AGENTS_DIR/$f.md"
  else
    cp "$SOURCE/.claude/agents/$f.md" "$AGENTS_DIR/$f.md"
    echo "  + $AGENTS_DIR/$f.md"
  fi
done

# Copy commands. run-team is generic — it reads TEAM_SPEC.json at runtime.
for f in build-team run-team review-team team-status team-dashboard; do
  if [[ -f "$COMMANDS_DIR/$f.md" ]]; then
    echo "  SKIP existing: $COMMANDS_DIR/$f.md"
  else
    cp "$SOURCE/.claude/commands/$f.md" "$COMMANDS_DIR/$f.md"
    echo "  + $COMMANDS_DIR/$f.md"
  fi
done

# Copy skill
cp "$SOURCE/.claude/skills/team-builder/SKILL.md" "$SKILLS_DIR/SKILL.md"
echo "  + $SKILLS_DIR/SKILL.md"

# Copy templates and docs (always overwrite — these are reference assets)
cp -R "$SOURCE/templates/"* "$SUBTEAMS_DIR/templates/"
echo "  + $SUBTEAMS_DIR/templates/ ($(ls "$SOURCE/templates" | wc -l | tr -d ' ') files)"

cp "$SOURCE/docs/QA-RUBRIC.md" "$SUBTEAMS_DIR/docs/QA-RUBRIC.md"
cp "$SOURCE/docs/PATTERNS.md" "$SUBTEAMS_DIR/docs/PATTERNS.md"
cp "$SOURCE/docs/DESIGN-PRINCIPLES.md" "$SUBTEAMS_DIR/docs/DESIGN-PRINCIPLES.md"
cp "$SOURCE/docs/ARCHITECTURE.md" "$SUBTEAMS_DIR/docs/ARCHITECTURE.md"
echo "  + $SUBTEAMS_DIR/docs/ (4 reference docs)"

# Copy dashboard (server.py + index.html)
mkdir -p "$SUBTEAMS_DIR/dashboard"
cp "$SOURCE/dashboard/server.py"  "$SUBTEAMS_DIR/dashboard/server.py"
cp "$SOURCE/dashboard/index.html" "$SUBTEAMS_DIR/dashboard/index.html"
chmod +x "$SUBTEAMS_DIR/dashboard/server.py"
echo "  + $SUBTEAMS_DIR/dashboard/ (server.py, index.html)"

# Settings: enable Agent Teams flag if not already present
if [[ -f "$SETTINGS_PATH" ]]; then
  if grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SETTINGS_PATH"; then
    echo "  = $SETTINGS_PATH (Agent Teams flag already present)"
  else
    echo "  ! $SETTINGS_PATH exists but does not enable Agent Teams."
    echo "    Add this to its env block:"
    echo '      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"'
  fi
else
  cat > "$SETTINGS_PATH" <<'EOF'
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
EOF
  echo "  + $SETTINGS_PATH"
fi

echo ""
echo "SubTeams installed ($MODE)."
echo ""

if [[ "$MODE" == "global" ]]; then
  echo "Available in EVERY Claude Code chat on this machine:"
  echo "  /build-team    /run-team    /review-team"
  echo "  /team-status   /team-dashboard"
  echo ""
  echo "Templates and docs the meta-agents reference live at:"
  echo "  $SUBTEAMS_DIR/"
  echo ""
  echo "Note: meta-agents resolve template paths in this order:"
  echo "  1. <project>/.subteams/        (project-local override, if present)"
  echo "  2. ~/.claude/.subteams/        (your global install)"
else
  echo "Next steps in $TARGET:"
  echo "  1. Open Claude Code in this project."
  echo "  2. Run: /build-team"
  echo "  3. After it finishes, run: /run-team <your task>"
  echo ""
  echo "Reference docs are at: $SUBTEAMS_DIR/"
fi
