#!/usr/bin/env python3
"""SubTeams Dashboard — a local-only HTTP server that visualizes active teams.

Reads from:
  ~/.claude/teams/<team-name>/config.json     (team rosters)
  ~/.claude/tasks/<team-name>/*.json          (task ownership + status)
  Any --watch dir                             (intermediate scratch artifacts)

Serves:
  /                  index.html (auto-refreshing dashboard)
  /api/state         JSON snapshot of all teams + tasks + activity
  /api/file?path=... text contents of a single allowed file (capped at 200KB)

No external dependencies — Python stdlib only.

Usage:
  python3 server.py                                # default port 7423, opens browser
  python3 server.py --port 8080                    # custom port
  python3 server.py --no-open                      # don't auto-open browser
  python3 server.py --watch /path/to/scratch       # additional scratch dir to surface
"""
import argparse
import http.server
import json
import os
import socketserver
import sys
import time
import webbrowser
from pathlib import Path
from urllib.parse import parse_qs, urlparse

HOME = Path.home()
TEAMS_DIR = HOME / ".claude" / "teams"
TASKS_DIR = HOME / ".claude" / "tasks"
DASHBOARD_DIR = Path(__file__).resolve().parent

WATCH_DIRS: list[Path] = []


def _read_json(path: Path):
    try:
        return json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return None


def get_state() -> dict:
    """Snapshot the current state of all known teams."""
    teams = []
    if TEAMS_DIR.exists():
        for team_dir in sorted(TEAMS_DIR.iterdir()):
            if not team_dir.is_dir():
                continue
            cfg_path = team_dir / "config.json"
            cfg = _read_json(cfg_path) if cfg_path.exists() else None
            if cfg is None:
                continue

            tasks = []
            task_dir = TASKS_DIR / team_dir.name
            if task_dir.exists():
                for tf in sorted(task_dir.iterdir()):
                    if tf.suffix != ".json":
                        continue
                    t = _read_json(tf)
                    if t is None:
                        continue
                    t["_mtime"] = tf.stat().st_mtime
                    t["_filename"] = tf.name
                    tasks.append(t)

            teams.append({
                "name": team_dir.name,
                "config": cfg,
                "tasks": tasks,
                "task_count": len(tasks),
                "completed": sum(1 for t in tasks if str(t.get("status", "")).lower() == "completed"),
                "in_progress": sum(1 for t in tasks if str(t.get("status", "")).lower() in ("in_progress", "in-progress", "active")),
                "blocked": sum(1 for t in tasks if str(t.get("status", "")).lower() == "blocked"),
                "config_mtime": cfg_path.stat().st_mtime,
            })

    activity = []
    for d in WATCH_DIRS:
        if not d.exists():
            continue
        for f in d.glob("**/*"):
            if not f.is_file():
                continue
            if f.suffix not in (".md", ".json", ".txt", ".log"):
                continue
            try:
                st = f.stat()
            except OSError:
                continue
            activity.append({
                "path": str(f),
                "name": f.name,
                "rel": str(f.relative_to(d)) if str(f).startswith(str(d)) else f.name,
                "watch_root": str(d),
                "size": st.st_size,
                "mtime": st.st_mtime,
            })
    activity.sort(key=lambda x: -x["mtime"])
    activity = activity[:60]

    return {
        "teams": teams,
        "activity": activity,
        "watch_dirs": [str(d) for d in WATCH_DIRS],
        "now": time.time(),
    }


def _path_is_allowed(p: Path) -> bool:
    """Only allow reading files under ~/.claude or any --watch dir."""
    try:
        resolved = p.resolve()
    except Exception:
        return False
    allowed_roots = [HOME / ".claude"] + list(WATCH_DIRS)
    for root in allowed_roots:
        try:
            resolved.relative_to(root.resolve())
            return True
        except ValueError:
            continue
    return False


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        u = urlparse(self.path)

        if u.path in ("/", "/index.html"):
            self._send_file("index.html", "text/html; charset=utf-8")
            return

        if u.path == "/api/state":
            self._send_json(get_state())
            return

        if u.path == "/api/file":
            qs = parse_qs(u.query)
            p_str = qs.get("path", [None])[0]
            if not p_str:
                self._send_status(400, "missing path")
                return
            p = Path(p_str).expanduser()
            if not _path_is_allowed(p):
                self._send_status(403, "path not allowed")
                return
            if not p.exists() or not p.is_file():
                self._send_status(404, "not found")
                return
            try:
                content = p.read_text(errors="replace")[:200_000]
            except Exception as e:
                self._send_status(500, str(e))
                return
            self._send_text(content)
            return

        self._send_status(404, "not found")

    def log_message(self, fmt, *args):
        return  # silence per-request logs

    def _send_file(self, fn: str, ct: str):
        try:
            content = (DASHBOARD_DIR / fn).read_bytes()
        except FileNotFoundError:
            self._send_status(404, f"missing {fn}")
            return
        self.send_response(200)
        self.send_header("Content-Type", ct)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def _send_json(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_text(self, s: str):
        body = s.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_status(self, code: int, msg: str = ""):
        body = msg.encode() if msg else b""
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main():
    ap = argparse.ArgumentParser(description="SubTeams local dashboard server")
    ap.add_argument("--port", type=int, default=7423)
    ap.add_argument("--no-open", action="store_true",
                    help="Do not auto-open a browser tab")
    ap.add_argument("--watch", action="append", default=[],
                    help="Project scratch dir to surface in the activity feed (repeatable)")
    args = ap.parse_args()

    global WATCH_DIRS
    WATCH_DIRS = [Path(d).expanduser() for d in args.watch]

    addr = ("127.0.0.1", args.port)
    try:
        httpd = ReusableTCPServer(addr, Handler)
    except OSError as e:
        print(f"error: cannot bind {addr[0]}:{addr[1]}: {e}", file=sys.stderr)
        sys.exit(2)

    url = f"http://localhost:{args.port}"
    print(f"SubTeams dashboard listening on {url}")
    print(f"  teams dir : {TEAMS_DIR}")
    print(f"  tasks dir : {TASKS_DIR}")
    if WATCH_DIRS:
        print(f"  activity  : {', '.join(str(d) for d in WATCH_DIRS)}")
    print("Press Ctrl-C to stop.")

    if not args.no_open:
        try:
            webbrowser.open(url)
        except Exception:
            pass

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        httpd.shutdown()
        httpd.server_close()


if __name__ == "__main__":
    main()
