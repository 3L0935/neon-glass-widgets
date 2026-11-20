#!/usr/bin/env python3
"""neonglass-player: music-cli helper used by the Neon Glass Player widget.

  neonglass-player play all|radar|discover|supermix|newrelease|liked
  neonglass-player play-id PLAYLIST_ID       play any library playlist
  neonglass-player playlists                 every library playlist, grouped (JSON)
  neonglass-player like                      like / unlike the current track
  neonglass-player is-liked VIDEO_ID         1 or 0 (local cache, instant)
  neonglass-player queue [N]                 the next N up-next tracks (JSON)
  neonglass-player reshuffle                 shuffle the up-next queue in place
  neonglass-player refresh                   run neonglass-mix

Every command prints one short line (or JSON) that the widget shows.
"""
from __future__ import annotations

import json
import random
import shutil
import subprocess
import sys
from pathlib import Path

CONFIG = Path.home() / ".config/neonglass/mix.json"
STATE = Path.home() / ".config/neonglass/mix-state.json"
LIKED = Path.home() / ".cache/neonglass/liked.json"
MIXES = {"discover": "Discover Mix", "supermix": "My Supermix", "newrelease": "New Release Mix"}
SHUFFLE_TOKEN = "__neonglass_shuffle__"   # understood by the music-cli hook (see neonglass_music_cli.py)


def api():
    from music_cli.core.paths import config_dir
    from music_cli.yt.cookies import Cookies, _account_session, _browser_auth
    from ytmusicapi import YTMusic

    session = _account_session(Cookies.from_file(str(config_dir() / "cookies.txt")))
    return YTMusic(auth=_browser_auth(session), requests_session=session)


def daemon(request, timeout=5.0):
    from music_cli.ipc import send_request

    return send_request(request, timeout=timeout)


def state():
    try:
        return json.loads(STATE.read_text())
    except Exception:
        return {}


def liked_cache():
    try:
        return set(json.loads(LIKED.read_text()))
    except Exception:
        return set()


def save_liked(ids):
    LIKED.parent.mkdir(parents=True, exist_ok=True)
    LIKED.write_text(json.dumps(sorted(ids)))


def start(playlist_id, title):
    # music-cli blocks until the first track is downloaded: run it detached
    subprocess.Popen(["music-cli", "play", "--playlist", playlist_id], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    print(f"▶ {title or playlist_id}")
    return 0


def resolve(key):
    st = state()
    managed = st.get("playlists", {})
    if key == "liked":
        return "LM", "Liked Music"
    if key == "all":
        try:
            title = json.loads(CONFIG.read_text()).get("all_music_title", "All Music")
        except Exception:
            title = "All Music"
        return managed.get(title), title
    if key == "radar":
        radars = [t for t in managed if t.startswith("Radar")]
        if radars:
            t = random.choice(radars)
            return managed[t], t
        return None, "a Radar playlist"
    if key in MIXES:
        title = MIXES[key]
        pid = st.get("mixes", {}).get(title)
        if not pid:
            pid = {p["title"]: p["playlistId"] for p in api().get_library_playlists(limit=100)}.get(title)
        return pid, title
    return None, key


def play(key):
    pid, title = resolve(key)
    if not pid:
        print(f"not found: {title} (run neonglass-mix)")
        return 1
    return start(pid, title)


def playlists():
    managed = set(state().get("playlists", {}).values())
    out = []
    for p in api().get_library_playlists(limit=200):
        pid, title = p.get("playlistId") or "", p.get("title") or ""
        if not pid:
            continue
        if pid == "LM":
            group = "liked"
        elif title.startswith("Radar · "):
            group = "radar"
        elif pid.startswith("RDTMAK"):
            group = "youtube"
        elif pid in managed:
            group = "mine"
        else:
            group = "library"
        out.append({"id": pid, "title": title, "group": group})
    order = {"liked": 0, "mine": 1, "radar": 2, "youtube": 3, "library": 4}
    out.sort(key=lambda x: (order[x["group"]], x["title"].lower()))
    print(json.dumps(out, ensure_ascii=False))
    return 0


def current_track():
    t = ((daemon({"cmd": "status"}, 3.0).get("data") or {}).get("track")) or {}
    return t.get("video_id"), t.get("title") or ""


def like():
    try:
        vid, title = current_track()
    except Exception:
        vid = None
    if not vid:
        print("music-cli is not playing")
        return 1
    ids = liked_cache()
    if vid in ids:
        api().rate_song(vid, "INDIFFERENT")
        ids.discard(vid)
        print(f"♡ unliked: {title[:40]}")
    else:
        api().rate_song(vid, "LIKE")
        ids.add(vid)
        print(f"♥ liked: {title[:40]}")
    save_liked(ids)
    return 0


def queue(n):
    try:
        d = daemon({"cmd": "status"}, 3.0).get("data") or {}
    except Exception:
        print(json.dumps({"count": 0, "items": []}))
        return 0
    q = d.get("queue") or []
    items = [{"title": t.get("title") or "", "artist": ", ".join(t.get("artists") or [])} for t in q[:n]]
    print(json.dumps({"count": len(q), "items": items}, ensure_ascii=False))
    return 0


def reshuffle():
    # music-cli has no shuffle command: the hook turns this special queue_add into one
    try:
        r = daemon({"cmd": "queue_add", "video_id": SHUFFLE_TOKEN})
    except Exception:
        print("music-cli is not playing")
        return 1
    title = (r.get("data") or {}).get("title") or ""
    if not r.get("ok") or "reshuffled" not in title:
        print("reshuffle needs the music-cli hook (see the README), then quit music-cli once")
        return 1
    print("⤮ " + title)
    return 0


def refresh():
    mixer = shutil.which("neonglass-mix") or str(Path.home() / ".local/bin/neonglass-mix")
    r = subprocess.run([mixer], capture_output=True, text=True)
    if r.returncode == 0:
        radars = sum(1 for line in r.stdout.splitlines() if "fresh tracks" in line)
        print(f"✓ refreshed ({radars} radars)")
        return 0
    print("✗ refresh failed: " + ((r.stdout or r.stderr).strip().splitlines() or ["?"])[-1][:60])
    return 1


def main(argv):
    cmd, args = (argv[0], argv[1:]) if argv else ("", [])
    if cmd == "play" and args:
        return play(args[0])
    if cmd == "play-id" and args:
        return start(args[0], " ".join(args[1:]))
    if cmd == "playlists":
        return playlists()
    if cmd == "like":
        return like()
    if cmd == "is-liked" and len(args) == 1:
        print("1" if args[0] in liked_cache() else "0")
        return 0
    if cmd == "queue":
        return queue(int(args[0]) if args else 4)
    if cmd == "reshuffle":
        return reshuffle()
    if cmd == "refresh":
        return refresh()
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as e:
        print(f"✗ {type(e).__name__}: {e}"[:120])
        sys.exit(1)
