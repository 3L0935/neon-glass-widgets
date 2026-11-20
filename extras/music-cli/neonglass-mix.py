#!/usr/bin/env python3
"""neonglass-mix: keeps a music-cli / YouTube Music library tidy and fresh.

One run:
  1. Sorts new liked songs into your genre playlists (and removes songs you
     un-liked, only the ones this script added).
  2. Labels each YouTube "My Mix N" (the number means nothing and changes)
     from its content, and pours it into "Radar · <label>".
  3. Refills every Radar playlist IN PLACE: tracks from those mixes + radio
     from your likes, minus your likes and what you played recently, so it's
     all new music.
  4. Refills "All Music": all your likes + a slice of every Radar + Supermix,
     shuffled again on every run.
  5. Removes the noisy YouTube mixes from the library (My Mix N, Replay,
     Archive) and keeps Discover / New Release / Supermix.

Managed playlists are tracked by id in a state file: never duplicated.
Genres, keywords and sizes live in a JSON config (see --init-config).

Usage: neonglass-mix [--dry-run] [-v] [--config FILE] [--init-config]
"""
from __future__ import annotations

import argparse
import collections
import json
import random
import re
import sys
import time
from pathlib import Path

from music_cli.core.paths import config_dir
from music_cli.yt.cookies import Cookies, _account_session, _browser_auth
from ytmusicapi import YTMusic

CONFIG = Path.home() / ".config/neonglass/mix.json"
STATE = Path.home() / ".config/neonglass/mix-state.json"
LIKED_CACHE = Path.home() / ".cache/neonglass/liked.json"

# Defaults, written by --init-config. Edit the JSON copy, not this.
DEFAULT_CONFIG = {
    # genre playlists filled from your likes (each also gets a "Radar · <genre>")
    "genres": ["Electronic", "Hip-Hop", "Rock & Metal", "Soundtracks"],
    # extra "corners" that only get a Radar playlist (no likes playlist)
    "extra": ["Chill"],
    # words that point a track (title + artists, lowercase) to a label
    "keywords": {
        "Electronic": ["edm", "house", "techno", "trance", "dubstep", "drum and bass", "remix", "hardstyle"],
        "Hip-Hop": ["rap", "hip hop", "hip-hop", "trap", "drill", "freestyle"],
        "Rock & Metal": ["rock", "metal", "punk", "grunge"],
        "Soundtracks": ["ost", "soundtrack", "theme", "score", "game"],
        "Chill": ["piano", "lofi", "lo-fi", "ambient", "chill", "acoustic", "relax"],
    },
    # labels with no liked songs to start from: radio seeds come from searches
    "search_seeds": {},
    # words that must never land in a given Radar (the radio drifts otherwise)
    "exclude": {},
    "radar_prefix": "Radar · ",
    "radar_size": 60,
    "radio_seeds": 8,
    "all_music_title": "All Music",
    "all_music_per_radar": 15,
    "all_music_supermix": 40,
    "keep_mixes": ["Discover Mix", "New Release Mix", "My Supermix"],
    "drop_mixes": "^(My Mix \\d+|Replay Mix|Archive Mix)$",
    # music-cli shows 25 library playlists: stay below that
    "max_managed": 18,
}

DESC_LIKES = "Your liked songs, sorted by neonglass-mix"
DESC_RADAR = "New music: YouTube's mixes + radio from your likes, minus your likes and recent plays · neonglass-mix"
DESC_ALL = "All your music mixed: likes + fresh tracks from every Radar + Supermix · neonglass-mix"


def log(*a):
    print(*a, flush=True)


def artists(t):
    return {a["name"].lower() for a in (t.get("artists") or []) if a.get("name")}


def text(t):
    return (t.get("title") or "").lower() + " " + " ".join(artists(t))


class Mixer:
    def __init__(self, cfg: dict, dry: bool, verbose: bool):
        self.cfg, self.dry, self.verbose = cfg, dry, verbose
        session = _account_session(Cookies.from_file(str(config_dir() / "cookies.txt")))
        self.yt = YTMusic(auth=_browser_auth(session), requests_session=session)
        self.state = json.loads(STATE.read_text()) if STATE.exists() else {}
        self.state.setdefault("playlists", {})   # managed title -> playlist id
        self.state.setdefault("added", {})       # genre -> video ids this script added
        self.genres = list(cfg["genres"])
        self.labels = self.genres + list(cfg["extra"])

    # ── API helpers ──
    def save(self):
        if not self.dry:
            STATE.parent.mkdir(parents=True, exist_ok=True)
            STATE.write_text(json.dumps(self.state, indent=1, ensure_ascii=False))

    def library(self):
        return {p["title"]: p["playlistId"] for p in self.yt.get_library_playlists(limit=200)}

    def ensure(self, title, desc, lib):
        """The id of managed playlist `title`, creating (or adopting) it if needed."""
        pid = self.state["playlists"].get(title)
        if pid and pid in lib.values():
            return pid
        if title in lib:  # made before this script ran: adopt it
            pid = lib[title]
        else:
            managed = [t for t, p in self.state["playlists"].items() if p in lib.values()]
            if len(managed) >= self.cfg["max_managed"]:
                log(f"  ! limit of {self.cfg['max_managed']} playlists reached, \"{title}\" not created")
                return None
            log(f"  + create \"{title}\"")
            pid = "DRY" if self.dry else self.yt.create_playlist(title, desc, privacy_status="PRIVATE")
            if not isinstance(pid, str):
                pid = pid.get("playlistId", "")
        self.state["playlists"][title] = pid
        return pid

    def items(self, pid):
        if pid == "DRY":
            return []
        try:
            return self.yt.get_playlist(pid, limit=None).get("tracks", [])
        except KeyError:  # a brand-new empty playlist: the API returns nothing
            return []

    def add(self, pid, ids):
        if ids and not self.dry:
            for i in range(0, len(ids), 100):
                self.yt.add_playlist_items(pid, ids[i:i + 100], duplicates=True)

    def remove(self, pid, tracks):
        if tracks and not self.dry:
            self.yt.remove_playlist_items(
                pid, [{"videoId": t["videoId"], "setVideoId": t["setVideoId"]} for t in tracks])

    def replace(self, pid, ids):
        """Swap a playlist's content in place (same id, same link)."""
        self.remove(pid, [t for t in self.items(pid) if t.get("setVideoId")])
        self.add(pid, ids)

    def radio(self, seeds):
        out = []
        for sd in seeds:
            try:
                out += self.yt.get_watch_playlist(videoId=sd, radio=True, limit=30)["tracks"][1:]
            except Exception as e:
                log(f"  ! radio {sd}: {e}")
            time.sleep(0.4)
        return out

    # ── classification ──
    def score(self, tracks, profiles, labels):
        """Per-label score: known artists of the label count 2, keywords 1."""
        sc = collections.Counter()
        kw = self.cfg["keywords"]
        for t in tracks:
            tx, ar = text(t), artists(t)
            for lab in labels:
                sc[lab] += sum(2 for a in ar if profiles.get(lab, {}).get(a))
                sc[lab] += sum(1 for k in kw.get(lab, []) if k in tx)
        return sc

    def classify(self, t, profiles):
        sc = self.score([t], profiles, self.genres)
        if sc and sc.most_common(1)[0][1] > 0:
            return sc.most_common(1)[0][0]
        # unknown: see which corner its radio falls into
        try:
            radio = self.yt.get_watch_playlist(videoId=t["videoId"], radio=True, limit=25)["tracks"]
        except Exception:
            return None
        best = self.score(radio, profiles, self.genres).most_common(1)
        return best[0][0] if best and best[0][1] >= 3 else None

    # ── steps ──
    def run(self):
        cfg = self.cfg
        lib = self.library()
        liked = self.yt.get_liked_songs(limit=5000)["tracks"]
        liked_ids = {t["videoId"] for t in liked if t.get("videoId")}
        history = self.yt.get_history()
        recent = {t["videoId"] for t in history if t.get("videoId")}
        log(f"• {len(liked)} liked songs, {len(recent)} in history")

        # 1. genre playlists
        log("• genre playlists")
        genre_pid, genre_tracks = {}, {}
        for g in self.genres:
            pid = self.ensure(g, DESC_LIKES, lib)
            genre_pid[g] = pid
            genre_tracks[g] = self.items(pid) if pid else []
            added = self.state["added"].setdefault(g, [])
            if not added:  # first run: whatever is already there came from likes
                added.extend(t["videoId"] for t in genre_tracks[g] if t.get("videoId"))
        # artists per genre, learned from what the playlists already hold
        profiles = {g: collections.Counter(a for t in ts for a in artists(t)) for g, ts in genre_tracks.items()}
        placed = {t["videoId"] for ts in genre_tracks.values() for t in ts}
        todo = collections.defaultdict(list)
        for t in liked:
            if not t.get("videoId") or t["videoId"] in placed:
                continue
            g = self.classify(t, profiles)
            log(f"  {'→ ' + g if g else '? unsorted'}: {t['title'][:60]}")
            if g and genre_pid.get(g):
                todo[g].append(t["videoId"])
        for g, ids in todo.items():
            self.add(genre_pid[g], ids)
            self.state["added"][g].extend(ids)
        for g in self.genres:
            gone = [t for t in genre_tracks[g]
                    if t.get("videoId") not in liked_ids and t.get("videoId") in self.state["added"][g]]
            if gone:
                log(f"  - {g}: removing {len(gone)} un-liked song(s)")
                self.remove(genre_pid[g], gone)
                gone_ids = {t["videoId"] for t in gone}
                self.state["added"][g] = [v for v in self.state["added"][g] if v not in gone_ids]
        self.save()

        # 2. YouTube's mixes → labels
        log("• YouTube mixes")
        mixes = {}
        for sec in self.yt.get_home(limit=12):
            for it in sec.get("contents") or []:
                if isinstance(it, dict) and (it.get("playlistId") or "").startswith("RDTMAK") and it.get("title"):
                    mixes[it["title"]] = it["playlistId"]
        self.state["mixes"] = mixes
        if not self.dry:   # for the widget's like button
            LIKED_CACHE.parent.mkdir(parents=True, exist_ok=True)
            LIKED_CACHE.write_text(json.dumps(sorted(liked_ids)))
        pool = collections.defaultdict(list)
        for title, pid in sorted(mixes.items()):
            if not title.startswith("My Mix"):
                continue
            tracks = self.yt.get_playlist(pid, limit=100).get("tracks", [])
            sc = self.score(tracks, profiles, self.labels)
            if sc:
                label = sc.most_common(1)[0][0]
                log(f"  {title} → {label}" + (f"  {dict(sc.most_common(3))}" if self.verbose else ""))
                pool[label].extend(tracks)

        # 3. Radar playlists, refilled in place
        log("• radars")
        seen = liked_ids | recent
        radar_picks = []
        for label in self.labels:
            exclude = cfg["exclude"].get(label, [])
            cand = []
            if label in self.genres:
                seeds = [t["videoId"] for t in genre_tracks[label] if t.get("videoId")]
                cand += self.radio(random.sample(seeds, min(cfg["radio_seeds"], len(seeds))))
            elif label in cfg["search_seeds"]:
                # seeds: your liked/played tracks named after the label + top search hits
                mine = [t["videoId"] for t in liked + history
                        if t.get("videoId") and label.lower() in text(t) and not any(x in text(t) for x in exclude)]
                found = []
                for q in cfg["search_seeds"][label]:
                    try:
                        found += [r["videoId"] for r in self.yt.search(q, filter="songs", limit=5)[:3] if r.get("videoId")]
                    except Exception as e:
                        log(f"  ! search {q}: {e}")
                seeds = list(dict.fromkeys(random.sample(mine, min(4, len(mine))) + found))
                cand += self.radio(seeds[:cfg["radio_seeds"]])
            cand += pool.get(label, [])
            random.shuffle(cand)
            ids, dedup = [], set(seen)
            for t in cand:
                v = t.get("videoId")
                if v and v not in dedup and not any(x in text(t) for x in exclude):
                    dedup.add(v)
                    ids.append(v)
            ids = ids[:cfg["radar_size"]]
            radar_picks += random.sample(ids, min(cfg["all_music_per_radar"], len(ids)))
            title = cfg["radar_prefix"] + label
            if len(ids) < 10:
                log(f"  {title}: not enough material ({len(ids)}), skipped")
                continue
            pid = self.ensure(title, DESC_RADAR, self.library() if not self.dry else lib)
            if pid:
                self.replace(pid, ids)
                log(f"  {title}: {len(ids)} fresh tracks")
                self.save()

        # 4. All Music: likes + a slice of every Radar + Supermix
        title = cfg["all_music_title"]
        log(f"• {title}")
        mix = list(liked_ids) + radar_picks
        if mixes.get("My Supermix"):
            sup = self.yt.get_playlist(mixes["My Supermix"], limit=100).get("tracks", [])
            mix += [t["videoId"] for t in sup if t.get("videoId")][:cfg["all_music_supermix"]]
        mix = list(dict.fromkeys(mix))
        random.shuffle(mix)
        pid = self.ensure(title, DESC_ALL, self.library() if not self.dry else lib)
        if pid:
            self.replace(pid, mix)
            log(f"  {title}: {len(mix)} tracks, shuffled")
        self.save()

        # 5. tidy YouTube's mixes
        log("• cleanup")
        drop = re.compile(cfg["drop_mixes"])
        for t, pid in self.library().items():
            if pid.startswith("RDTMAK") and drop.match(t):
                log(f"  - remove \"{t}\" from the library" + (" (poured into the Radars)" if t.startswith("My Mix") else ""))
                if not self.dry:
                    self.yt.rate_playlist(pid, "INDIFFERENT")
        for t in cfg["keep_mixes"]:
            pid = mixes.get(t)
            if pid and pid not in self.library().values() and not self.dry:
                self.yt.rate_playlist(pid, "LIKE")
        self.save()
        log(f"✓ done · {len(self.library())} playlists in the library")


def load_config(path: Path) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if path.exists():
        cfg.update(json.loads(path.read_text()))
    return cfg


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="show what would change, touch nothing")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--config", type=Path, default=CONFIG, help=f"config file (default: {CONFIG})")
    ap.add_argument("--init-config", action="store_true", help="write the default config to --config and exit")
    a = ap.parse_args()
    if a.init_config:
        if a.config.exists():
            log(f"{a.config} already exists, not overwriting")
            return
        a.config.parent.mkdir(parents=True, exist_ok=True)
        a.config.write_text(json.dumps(DEFAULT_CONFIG, indent=2, ensure_ascii=False) + "\n")
        log(f"wrote {a.config}: edit the genres and keywords to match your music")
        return
    try:
        Mixer(load_config(a.config), a.dry_run, a.verbose).run()
    except Exception as e:
        log(f"✗ {type(e).__name__}: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
