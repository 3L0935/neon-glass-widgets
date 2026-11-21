"""MPRIS2 for the music-cli daemon on Linux (Neon Glass widgets, MIT).

music-cli only ships a macOS Now Playing controller. This class has the same
interface (start / drain / update / close) and is handed to the daemon by
neonglass_music_cli's import hook, so media keys, KDE's media controls and
the Neon Glass Player widget see music-cli as org.mpris.MediaPlayer2.musiccli.
D-Bus runs on its own GLib main loop thread; commands are only queued here and
run by the daemon on its serve loop, like the macOS controller does.
"""
from __future__ import annotations

import logging
import re
import threading

logger = logging.getLogger(__name__)

BUS_NAME = "org.mpris.MediaPlayer2.musiccli"
PATH = "/org/mpris/MediaPlayer2"
XML = """
<node>
 <interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/>
  <property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/>
  <property name="Identity" type="s" access="read"/>
  <property name="DesktopEntry" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/>
  <property name="SupportedMimeTypes" type="as" access="read"/>
 </interface>
 <interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/>
  <method name="PlayPause"/><method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
  <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
  <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
  <signal name="Seeked"><arg name="Position" type="x"/></signal>
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="LoopStatus" type="s" access="readwrite"/>
  <property name="Rate" type="d" access="readwrite"/>
  <property name="Shuffle" type="b" access="readwrite"/>
  <property name="Metadata" type="a{sv}" access="read"/>
  <property name="Volume" type="d" access="readwrite"/>
  <property name="Position" type="x" access="read"/>
  <property name="MinimumRate" type="d" access="read"/>
  <property name="MaximumRate" type="d" access="read"/>
  <property name="CanGoNext" type="b" access="read"/>
  <property name="CanGoPrevious" type="b" access="read"/>
  <property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/>
  <property name="CanSeek" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
 </interface>
</node>
"""
ROOT_IF = "org.mpris.MediaPlayer2"
PLAYER_IF = "org.mpris.MediaPlayer2.Player"


class MprisControl:
    def __init__(self):
        from music_cli.player.base import MediaCommand

        self._Cmd = MediaCommand
        self._lock = threading.Lock()
        self._pending = []
        self._status = {"state": "stopped", "track": None, "position": 0.0,
                        "volume": 100, "muted": False, "loop": False}
        self._sig = None
        self._last_pos = 0.0
        self._conn = None
        self._loop = None
        self._thread = None
        self._started = False

    # ── daemon interface ──
    def start(self):
        if self._started:
            return
        self._started = True
        ready = threading.Event()
        self._thread = threading.Thread(target=self._run, args=(ready,), name="mpris", daemon=True)
        self._thread.start()
        ready.wait(5)

    def drain(self):
        with self._lock:
            out, self._pending = self._pending, []
        return out

    def update(self, status):
        if not self._started:
            return
        track = status.get("track") or None
        pos = float(status.get("position") or 0.0)
        sig = (status.get("state"), track and track.get("video_id"), status.get("volume"),
               status.get("muted"), status.get("loop"), status.get("duration"))
        with self._lock:
            prev_sig, prev_pos = self._sig, self._last_pos
            self._status = dict(status)
            self._sig = sig
            self._last_pos = pos
        if self._conn is None:
            return
        if sig != prev_sig:
            self._emit_changed(prev_sig, sig)
        elif status.get("state") == "playing" and abs(pos - prev_pos) > 1.5:
            self._emit_seeked(pos)
        elif status.get("state") != "playing" and abs(pos - prev_pos) > 0.01:
            self._emit_seeked(pos)

    def close(self):
        if not self._started:
            return
        self._started = False
        if self._loop is not None:
            self._loop.quit()

    # ── D-Bus side ──
    def _run(self, ready):
        try:
            from gi.repository import Gio, GLib

            self.GLib = GLib
            ctx = GLib.MainContext()
            ctx.push_thread_default()
            conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            info = Gio.DBusNodeInfo.new_for_xml(XML)
            for iface in info.interfaces:
                conn.register_object(PATH, iface, self._on_call, self._on_get, self._on_set)
            Gio.bus_own_name_on_connection(conn, BUS_NAME, Gio.BusNameOwnerFlags.NONE, None, None)
            self._conn = conn
            self._loop = GLib.MainLoop(ctx)
        except Exception:
            logger.exception("MPRIS unavailable")
            ready.set()
            return
        ready.set()
        self._loop.run()
        try:
            self._conn.flush_sync(None)
        except Exception:
            pass

    def _queue(self, name, position=None):
        with self._lock:
            self._pending.append(self._Cmd(name, position))

    def _snap(self):
        with self._lock:
            return dict(self._status)

    @staticmethod
    def _trackid(vid):
        return "/org/musiccli/track/" + (re.sub(r"[^A-Za-z0-9_]", "_", vid or "") or "none")

    def _metadata(self, st):
        GLib = self.GLib
        t = st.get("track")
        if not t:
            return GLib.Variant("a{sv}", {"mpris:trackid": GLib.Variant("o", "/org/mpris/MediaPlayer2/TrackList/NoTrack")})
        vid = t.get("video_id") or ""
        dur = st.get("duration") or t.get("duration") or 0
        md = {
            "mpris:trackid": GLib.Variant("o", self._trackid(vid)),
            "xesam:title": GLib.Variant("s", t.get("title") or ""),
            "xesam:artist": GLib.Variant("as", list(t.get("artists") or [])),
            "xesam:album": GLib.Variant("s", "YouTube Music"),
            "xesam:url": GLib.Variant("s", f"https://music.youtube.com/watch?v={vid}"),
            "mpris:artUrl": GLib.Variant("s", f"https://i.ytimg.com/vi/{vid}/mqdefault.jpg"),
        }
        if dur:
            md["mpris:length"] = GLib.Variant("x", int(float(dur) * 1e6))
        return GLib.Variant("a{sv}", md)

    def _prop(self, iface, name):
        GLib, st = self.GLib, self._snap()
        b = lambda v: GLib.Variant("b", v)
        if iface == ROOT_IF:
            return {
                "CanQuit": b(False), "CanRaise": b(False), "HasTrackList": b(False),
                "Identity": GLib.Variant("s", "music-cli"),
                "DesktopEntry": GLib.Variant("s", "music-cli"),
                "SupportedUriSchemes": GLib.Variant("as", []),
                "SupportedMimeTypes": GLib.Variant("as", []),
            }.get(name)
        has = st.get("track") is not None
        state = st.get("state") or "stopped"
        vals = {
            "PlaybackStatus": GLib.Variant("s", {"playing": "Playing", "paused": "Paused"}.get(state, "Stopped")),
            "LoopStatus": GLib.Variant("s", "Track" if st.get("loop") else "None"),
            "Rate": GLib.Variant("d", 1.0), "MinimumRate": GLib.Variant("d", 1.0),
            "MaximumRate": GLib.Variant("d", 1.0), "Shuffle": b(False),
            "Metadata": self._metadata(st),
            "Volume": GLib.Variant("d", 0.0 if st.get("muted") else (st.get("volume") or 0) / 100.0),
            "Position": GLib.Variant("x", int(float(st.get("position") or 0) * 1e6)),
            "CanGoNext": b(has), "CanGoPrevious": b(has), "CanPlay": b(has),
            "CanPause": b(has), "CanSeek": b(has), "CanControl": b(True),
        }
        return vals.get(name)

    def _on_get(self, conn, sender, path, iface, name):
        return self._prop(iface, name)

    def _ipc(self, request):
        """Volume/loop aren't MediaCommands: ask the daemon over its socket."""
        def send():
            try:
                from music_cli.ipc import send_request

                send_request(request, timeout=5.0)
            except Exception:
                logger.debug("ipc %s failed", request, exc_info=True)
        threading.Thread(target=send, daemon=True).start()

    def _on_set(self, conn, sender, path, iface, name, value):
        if name == "Volume":
            self._ipc({"cmd": "volume", "level": int(round(max(0.0, min(1.0, value.unpack())) * 100))})
        elif name == "LoopStatus":
            self._ipc({"cmd": "loop", "state": "off" if value.unpack() == "None" else "on"})
        return True

    def _on_call(self, conn, sender, path, iface, method, params, inv):
        st = self._snap()
        if method in ("Raise", "Quit", "OpenUri"):
            pass
        elif method == "PlayPause":
            self._queue("toggle")
        elif method == "Previous":
            # PREV_SEEK of the import hook: restart, or back one track (see there)
            self._queue("seek", -1.0)
        elif method in ("Play", "Pause", "Next", "Stop"):
            self._queue(method.lower())
        elif method == "Seek":
            off = params.unpack()[0] / 1e6
            self._queue("seek", max(0.0, float(st.get("position") or 0) + off))
        elif method == "SetPosition":
            tid, pos = params.unpack()
            t = st.get("track")
            if t and tid == self._trackid(t.get("video_id")):
                self._queue("seek", max(0.0, pos / 1e6))
        inv.return_value(None)

    def _emit(self, iface, changed):
        GLib = self.GLib
        try:
            self._conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                   GLib.Variant("(sa{sv}as)", (iface, changed, [])))
        except Exception:
            logger.debug("PropertiesChanged failed", exc_info=True)

    def _emit_changed(self, prev, sig):
        names = ["PlaybackStatus", "Metadata", "Volume", "LoopStatus", "CanGoNext",
                 "CanGoPrevious", "CanPlay", "CanPause", "CanSeek"]
        self._emit(PLAYER_IF, {n: self._prop(PLAYER_IF, n) for n in names})

    def _emit_seeked(self, pos):
        try:
            self._conn.emit_signal(None, PATH, PLAYER_IF, "Seeked", self.GLib.Variant("(x)", (int(pos * 1e6),)))
        except Exception:
            pass
