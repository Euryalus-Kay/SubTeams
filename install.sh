#!/usr/bin/env bash
# install.sh — install SubTeams.
#
# Usage:
#   ./install.sh <path-to-target-project>            # project install
#   ./install.sh --global                            # user-level install
#   ./install.sh --global --force                    # overwrite existing files
#   ./install.sh <path> --force                      # same, in project mode
#
# Without --force, existing meta-agent and command files are SKIPPED
# (preserves any local edits). With --force, they are OVERWRITTEN with
# the SubTeams source — use after `git pull` to refresh.
#
# Templates, docs, and dashboard are always overwritten (they are reference
# assets, not edited in place).
#
# It does NOT touch:
#   .claude/agents/<your-team>.md (only skipped if matching name; still safe)
#   CLAUDE.md
#   anything else outside the .claude/ paths it owns

set -euo pipefail

# Parse flags (order-independent)
FORCE=0
MODE=""
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE=1
      ;;
    --global)
      MODE="global"
      ;;
    --*)
      echo "Error: unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$arg"
      else
        echo "Error: multiple paths given: '$TARGET' and '$arg'" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$MODE" && -z "$TARGET" ]]; then
  echo "Usage: $0 <path-to-target-project> [--force]" >&2
  echo "       $0 --global [--force]" >&2
  exit 1
fi

SOURCE="$(cd "$(dirname "$0")" && pwd)"

if [[ "$MODE" == "global" ]]; then
  TARGET="$HOME/.claude"
  SUBTEAMS_DIR="$HOME/.claude/.subteams"
  echo "Installing SubTeams GLOBALLY (user-level): $TARGET${FORCE:+ (force=on)}"
  if [[ $FORCE -eq 1 ]]; then echo "  --force: existing meta-agent and command files will be OVERWRITTEN"; fi
else
  MODE="project"
  SUBTEAMS_DIR="$TARGET/.subteams"
  if [[ ! -d "$TARGET" ]]; then
    echo "Error: target directory does not exist: $TARGET" >&2
    exit 1
  fi
  echo "Installing SubTeams into project: $TARGET${FORCE:+ (force=on)}"
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
  if [[ -f "$AGENTS_DIR/$f.md" && $FORCE -eq 0 ]]; then
    echo "  SKIP existing: $AGENTS_DIR/$f.md (use --force to overwrite)"
  else
    cp "$SOURCE/.claude/agents/$f.md" "$AGENTS_DIR/$f.md"
    if [[ $FORCE -eq 1 && -f "$AGENTS_DIR/$f.md" ]]; then
      echo "  ! overwrote: $AGENTS_DIR/$f.md"
    else
      echo "  + $AGENTS_DIR/$f.md"
    fi
  fi
done

# Copy commands. run-team is generic — it reads TEAM_SPEC.json at runtime.
for f in build-team run-team review-team team-status team-dashboard team-info; do
  if [[ -f "$COMMANDS_DIR/$f.md" && $FORCE -eq 0 ]]; then
    echo "  SKIP existing: $COMMANDS_DIR/$f.md (use --force to overwrite)"
  else
    cp "$SOURCE/.claude/commands/$f.md" "$COMMANDS_DIR/$f.md"
    if [[ $FORCE -eq 1 ]]; then
      echo "  ! overwrote: $COMMANDS_DIR/$f.md"
    else
      echo "  + $COMMANDS_DIR/$f.md"
    fi
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
  echo "  /team-status   /team-dashboard   /team-info"
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
