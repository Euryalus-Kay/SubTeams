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
#
# Scope: only the 4 meta-agents (practice-researcher, project-analyzer,
# team-architect, team-qa-reviewer) and 6 user-facing commands ship to other
# projects. The SubTeams maintenance team — subteams-maintenance-lead,
# prompt-engineer, schema-keeper, docs-writer, production-verifier — exists
# only to maintain THIS repo and is intentionally excluded from install.sh.
# If you add a new meta-agent or command, update the for-loops below.

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
  existed=0
  [[ -f "$AGENTS_DIR/$f.md" ]] && existed=1
  if [[ $existed -eq 1 && $FORCE -eq 0 ]]; then
    echo "  SKIP existing: $AGENTS_DIR/$f.md (use --force to overwrite)"
  else
    cp "$SOURCE/.claude/agents/$f.md" "$AGENTS_DIR/$f.md"
    if [[ $existed -eq 1 ]]; then
      echo "  ! overwrote: $AGENTS_DIR/$f.md"
    else
      echo "  + $AGENTS_DIR/$f.md"
    fi
  fi
done

# Copy commands. run-team is generic — it reads TEAM_SPEC.json at runtime.
for f in build-team run-team review-team team-status team-dashboard team-info; do
  existed=0
  [[ -f "$COMMANDS_DIR/$f.md" ]] && existed=1
  if [[ $existed -eq 1 && $FORCE -eq 0 ]]; then
    echo "  SKIP existing: $COMMANDS_DIR/$f.md (use --force to overwrite)"
  else
    cp "$SOURCE/.claude/commands/$f.md" "$COMMANDS_DIR/$f.md"
    if [[ $existed -eq 1 ]]; then
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

# Settings: MERGE the Agent Teams flag AND the permissions block into the
# existing file (or create it if absent). Both are required — the env flag
# alone leaves spawned teammates blocking on every Bash/Edit call. See:
#   https://github.com/anthropics/claude-code/issues/26479
#
# We use python3 (preinstalled on macOS and most Linux) for a structural JSON
# merge. The previous version used `grep -q` to bail if the env flag was
# present, which silently left files without a permissions block — the most
# common cause of the "subagent prompts the parent that never sees them" bug.
REQUIRED_ALLOW='["Bash(*)","Read(*)","Write(*)","Edit(*)","Glob(*)","Grep(*)","WebSearch","WebFetch(*)","Agent(*)","TeamCreate(*)","TeamDelete(*)","SendMessage(*)","TaskCreate(*)","TaskUpdate(*)","TaskList(*)","TodoWrite"]'

python3 - "$SETTINGS_PATH" "$REQUIRED_ALLOW" <<'PY'
import json, os, sys
path, required_allow_json = sys.argv[1], sys.argv[2]
required_allow = json.loads(required_allow_json)

if os.path.exists(path):
    with open(path) as f:
        try:
            cfg = json.load(f)
            if not isinstance(cfg, dict):
                raise ValueError("top-level not an object")
        except Exception as e:
            print(f"  ! {path} is not valid JSON ({e}); leaving untouched. Fix it and re-run install.")
            sys.exit(0)
    created = False
else:
    cfg = {}
    created = True

changed = False

# 1. env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
env = cfg.setdefault("env", {})
if env.get("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS") != "1":
    env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    changed = True

# 2. permissions.defaultMode = "bypassPermissions" (only set if missing — we
#    don't downgrade a stricter user choice without telling them).
perms = cfg.setdefault("permissions", {})
if "defaultMode" not in perms:
    perms["defaultMode"] = "bypassPermissions"
    changed = True
elif perms["defaultMode"] not in ("bypassPermissions", "acceptEdits"):
    print(f"  ! {path} has permissions.defaultMode = {perms['defaultMode']!r}.")
    print(f"    SubTeams needs 'bypassPermissions' so spawned teammates do not block on every Bash/Edit.")
    print(f"    Leaving your setting alone. Either change it manually or rename this file and re-run install.")

# 3. permissions.allow — union with required entries, preserve existing.
existing_allow = perms.get("allow")
if not isinstance(existing_allow, list):
    existing_allow = []
existing_set = set(existing_allow)
added = [x for x in required_allow if x not in existing_set]
if added:
    perms["allow"] = existing_allow + added
    changed = True

if changed or created:
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    if created:
        print(f"  + {path} (Agent Teams flag + bypassPermissions + allowlist)")
    else:
        print(f"  ~ {path} (merged Agent Teams flag / permissions; preserved your other keys)")
else:
    print(f"  = {path} (already configured)")
PY

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
