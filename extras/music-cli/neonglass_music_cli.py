"""Neon Glass add-ons for music-cli (MIT), loaded by neonglass.pth.

music-cli is not modified on disk: a meta-path import hook patches it as it loads.
  - music_cli.player: on Linux, the daemon gets an MPRIS2 controller
    (neonglass_mpris), so media keys, KDE and the Neon Glass Player see it.
  - music_cli.session: queue_add(video_id=SHUFFLE_TOKEN) reshuffles the up-next
    queue in place (used by `neonglass-player reshuffle`).
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


def _patch(mod):
    if mod.__name__ == "music_cli.session":
        return _patch_session(mod)
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
