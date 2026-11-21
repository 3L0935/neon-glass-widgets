"""Neon Glass add-ons for music-cli (MIT), loaded by neonglass.pth.

music-cli is not modified on disk: a meta-path import hook patches it as it loads.
  - music_cli.player: on Linux, the daemon gets an MPRIS2 controller
    (neonglass_mpris), so media keys, KDE and the Neon Glass Player see it.
  - music_cli.session: queue_add(video_id=SHUFFLE_TOKEN) reshuffles the up-next
    queue in place (used by `neonglass-player reshuffle`).
  - music_cli.session: a real "previous track" (MPRIS Previous /
    media key): restart after 3 s, else back one track.
  - music_cli.tui.app: adds a "neon-glass" Textual theme (Ctrl+P → Theme).
A music-cli upgrade wipes these files: run extras/music-cli/install.sh again.
"""
import importlib.abc
import importlib.util
import sys

TARGETS = ("music_cli.tui.app", "music_cli.player", "music_cli.session")


def _theme():
    from textual.theme import Theme

    return Theme(
        name="neon-glass",
        primary="#46b5e7",
        secondary="#a55ae9",
        accent="#46b5e7",
        foreground="#e8e6ff",
        background="#15122e",
        surface="#1a1638",
        panel="#1d1940",
        success="#8af0c0",
        warning="#ffe08a",
        error="#ff6ba8",
        dark=True,
        variables={
            "border": "#2c2758",
            "border-blurred": "#221e47",
            "text-muted": "#9a94c8",
            "accent-lighten-1": "#6cc8f2",
            "surface-lighten-1": "#241f4d",
            "scrollbar": "#2c2758",
            "scrollbar-hover": "#4a4480",
            "scrollbar-active": "#46b5e7",
            "scrollbar-background": "#15122e",
            "scrollbar-background-hover": "#1d1940",
            "scrollbar-background-active": "#1d1940",
            "scrollbar-corner-color": "#15122e",
            "input-selection-background": "#46b5e7 40%",
            "footer-key-foreground": "#46b5e7",
        },
    )


def _patch_player(mod):
    """Linux: hand the daemon our MPRIS controller instead of None."""
    original = mod.create_media_control

    def create_media_control():
        ctl = original()
        if ctl is not None or sys.platform == "darwin":
            return ctl
        try:
            from neonglass_mpris import MprisControl

            return MprisControl()
        except Exception:
            return None

    mod.create_media_control = create_media_control


SHUFFLE_TOKEN = "__neonglass_shuffle__"


def _patch_session(mod):
    """queue_add(video_id=SHUFFLE_TOKEN) reshuffles the up-next queue in place.

    The daemon only accepts its own commands, so neonglass-player rides on
    queue_add; the current track keeps playing and nothing is re-downloaded.
    """
    cls = mod.PlaybackSession
    original = cls.queue_add

    def queue_add(self, *, video_id="", title="", query=""):
        if video_id == SHUFFLE_TOKEN:
            import random

            queue = list(self.client.queue)
            random.shuffle(queue)
            self.client.queue = queue
            return {"video_id": SHUFFLE_TOKEN, "title": f"{len(queue)} tracks reshuffled",
                    "artists": [], "duration": ""}
        return original(self, video_id=video_id, title=title, query=query)

    cls.queue_add = queue_add


PREV_RESTART_AFTER = 3.0   # seconds: past this, "previous" restarts the track
# The daemon runs as __main__ (python -m), so its media-key dispatch can't be
# patched: the MPRIS Previous is sent as a seek to this position instead.
PREV_SEEK = -1.0


def _patch_session_back(mod):
    """A real "previous track": music-cli itself only restarts the current one.

    Every play is pushed on a back stack (the play history fills it after a
    daemon restart). previous_track() restarts the track once it has played
    a few seconds, else plays the one before and puts the current track back
    at the head of the up-next queue, so Next returns to it. A double click
    on ⏮ therefore always lands on the previous track.
    """
    cls = mod.PlaybackSession
    record = cls.record

    def record_with_back(self, stream):
        back = self.__dict__.setdefault("_ng_back", [])
        cur = self.__dict__.get("_ng_cur")
        if cur is not None and cur[0] != stream.video_id and not self.__dict__.get("_ng_rewinding"):
            back.append(cur)
            del back[:-100]
        self._ng_cur = (stream.video_id, stream.title, list(stream.artists))
        return record(self, stream)

    def previous_track(self):
        current = self.client.current
        if current is None:
            return None
        # a double click: the player may still report the old position
        import time

        just_restarted = time.monotonic() - self.__dict__.get("_ng_restart_at", 0) < 2.0
        if float(self.client.player.position or 0) > PREV_RESTART_AFTER and not just_restarted:
            self._ng_restart_at = time.monotonic()
            return seek(self, position=0.0)
        back = self.__dict__.setdefault("_ng_back", [])
        while back and back[-1][0] == current.video_id:
            back.pop()
        if back:
            prev = back.pop()
        else:   # fresh daemon: fall back to the play history
            older = [t for t in self._history.recent(20) if t.video_id != current.video_id]
            if not older:
                return seek(self, position=0.0)
            prev = (older[0].video_id, older[0].title, list(older[0].artists))
        from music_cli.yt.extract import PlaylistTrack

        here = PlaylistTrack(video_id=current.video_id, title=current.title, artists=list(current.artists))
        self._ng_rewinding = True
        try:
            if self._downloads_context:
                self.play_download(prev[0], prev[1])
            else:
                self.client.play_video(prev[0], prev[1])
                self.record(self.client.current)
                (self._next_queue if self._next_queue else self.client.queue).insert(0, here)
        except Exception:
            back.append(prev)
            raise
        finally:
            self._ng_rewinding = False

    seek = cls.seek

    def seek_or_previous(self, *args, **kwargs):
        if kwargs.get("position") == PREV_SEEK:
            return previous_track(self)
        return seek(self, *args, **kwargs)

    cls.record = record_with_back
    cls.previous_track = previous_track
    cls.seek = seek_or_previous


def _patch(mod):
    if mod.__name__ == "music_cli.session":
        _patch_session(mod)
        return _patch_session_back(mod)
    if mod.__name__ == "music_cli.player":
        return _patch_player(mod)
    cls = getattr(mod, "MusicTUI", None)
    if cls is None or getattr(cls, "_neonglass", False):
        return
    original = cls.register_theme

    def register_theme(self, theme):
        if "neon-glass" not in self.available_themes:
            original(self, _theme())
        return original(self, theme)

    cls.register_theme = register_theme
    cls._neonglass = True


class _Loader(importlib.abc.Loader):
    def __init__(self, inner):
        self.inner = inner

    def __getattr__(self, name):  # runpy & co. need get_code etc.
        return getattr(self.inner, name)

    def create_module(self, spec):
        return self.inner.create_module(spec)

    def exec_module(self, module):
        self.inner.exec_module(module)
        try:
            _patch(module)
        except Exception:
            pass


class _Finder(importlib.abc.MetaPathFinder):
    def find_spec(self, name, path, target=None):
        if name not in TARGETS:
            return None
        sys.meta_path.remove(self)
        try:
            spec = importlib.util.find_spec(name)
        finally:
            sys.meta_path.insert(0, self)
        if spec and spec.loader:
            spec.loader = _Loader(spec.loader)
        return spec


if not any(isinstance(f, _Finder) for f in sys.meta_path):
    sys.meta_path.insert(0, _Finder())
