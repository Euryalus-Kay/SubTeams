---
description: Start the SubTeams local dashboard — a browser view of every active team, roster, task list, and scratch activity. Auto-refreshes every 2 seconds.
allowed-tools: Bash, Read, Glob, Grep
---

# /team-dashboard

Start a local HTTP server that serves a live dashboard of every running Agent Team on this machine and open it in the user's browser.

## Input

`$ARGUMENTS` — optional. Forms accepted:
- empty — start with defaults
- `stop` — stop a previously started dashboard
- `status` — check whether a dashboard is already running
- `--port 8080` — bind to a specific port (default 7423)
- `--watch <dir>` — additional scratch dir to surface in the activity panel (repeatable)
- a bare path — treated as `--watch <path>`

## Steps

### 1. Locate the server

Look for `dashboard/server.py` in this order:
1. `<cwd>/.subteams/dashboard/server.py` (project install)
2. `~/.claude/.subteams/dashboard/server.py` (global install)
3. The SubTeams source repo if running from there

If none found, tell the user to re-run `install.sh` (project or `--global`) and stop.

### 2. Handle `stop` and `status` first

- `stop`: read the PID from `~/.claude/.subteams/dashboard.pid` (if it exists) and `kill` it. Remove the pidfile. Tell the user.
- `status`: read the pidfile. Check if the process is alive (`kill -0 <pid>`). Report up/down.

### 3. Start the dashboard (default path)

If a dashboard is already running on the requested port (check the pidfile), tell the user the URL and stop. Don't start a second one.

Otherwise, in a single Bash invocation, start the server in the **background**:

```sh
mkdir -p ~/.claude/.subteams
nohup python3 "$SERVER_PY" --port 7423 $WATCH_FLAGS > ~/.claude/.subteams/dashboard.log 2>&1 &
echo $! > ~/.claude/.subteams/dashboard.pid
disown
```

(Adjust port and `--watch` flags from `$ARGUMENTS`.)

### 4. Verify it bound

Wait briefly, then `curl -sf http://localhost:<port>/api/state >/dev/null` to confirm. If it fails, surface the last 30 lines of `~/.claude/.subteams/dashboard.log` to the user.

### 5. Open the browser

```sh
open http://localhost:<port>
```

(macOS `open`. On Linux use `xdg-open`. On Windows, `start`.)

### 6. Tell the user

Print:
```
Dashboard running on http://localhost:<port>
PID: <pid>  (saved to ~/.claude/.subteams/dashboard.pid)
Stop with: /team-dashboard stop
```

## Hard rules

- **Bind only to 127.0.0.1** — never `0.0.0.0`. Local-only by design.
- **Never run as root.** If the user is root, refuse.
- **One dashboard at a time** — refuse to start a second on the same port.
- **Always background-start** so the chat session is not blocked.
- **Never start the server inside an unsanctioned directory** — the server reads files but only serves files under `~/.claude` and any `--watch` paths the user supplied.
